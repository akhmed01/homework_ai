import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../services/ai_service.dart';
import '../services/pdf_service.dart';
import '../services/study_planner_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = false;
  String _mode = 'standard';
  File? _pendingImage;

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if ((text.isEmpty && _pendingImage == null) || _loading) {
      return;
    }

    final planner = context.read<StudyPlannerService>();
    final userMessage = Message(text: text, isUser: true, image: _pendingImage);

    setState(() {
      _messages.add(userMessage);
      _pendingImage = null;
      _loading = true;
    });

    _input.clear();
    _scrollToBottom();

    try {
      final reply = await AIService.chat(
        _messages,
        mode: _mode,
        responseLanguageCode: planner.responseLanguageCode,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(Message(text: reply, isUser: false));
        _loading = false;
      });

      await planner.recordAiSession(summary: _studySummary(text, reply));
      _scrollToBottom();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _retryLast,
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _retryLast() {
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      setState(() => _messages.removeLast());
    }
    _sendToAI();
  }

  Future<void> _sendToAI() async {
    if (_loading || _messages.isEmpty) {
      return;
    }

    final planner = context.read<StudyPlannerService>();

    setState(() => _loading = true);

    try {
      final reply = await AIService.chat(
        _messages,
        mode: _mode,
        responseLanguageCode: planner.responseLanguageCode,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(Message(text: reply, isUser: false));
        _loading = false;
      });

      await planner.recordAiSession(summary: _studySummary('', reply));
      _scrollToBottom();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.camera_alt_outlined),
                ),
                title: const Text('Take a photo'),
                subtitle: const Text('Use the camera to capture homework'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.photo_library_outlined),
                ),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Pick an existing image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.picture_as_pdf_outlined),
                ),
                title: const Text('Import PDF'),
                subtitle: const Text('Paste text from a text-based PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _importPdf();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) {
      return;
    }
    setState(() => _pendingImage = File(picked.path));
  }

  Future<void> _importPdf() async {
    try {
      final result = await PdfService.pickPdfAndExtractText();
      if (result == null || !mounted) {
        return;
      }

      setState(() {
        _input.text = result.extractedText;
        _input.selection = TextSelection.fromPosition(
          TextPosition(offset: _input.text.length),
        );
      });
      _focusNode.requestFocus();

      if (result.warning != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.warning!)));
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _exportChat() async {
    final transcript = _messages
        .map(
          (message) => '${message.isUser ? 'You' : 'Tutor'}: ${message.text}',
        )
        .join('\n\n');

    try {
      final file = await PdfService.exportTextAsPdf(
        title: 'chat-export',
        text: transcript,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved PDF to ${file.path}')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export chat: $e')));
    }
  }

  TextSpan _format(String text, ThemeData theme) {
    final lines = text.split('\n');

    return TextSpan(
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 15,
        height: 1.6,
      ),
      children: lines.map((line) {
        final trimmed = line.trim();
        final lower = trimmed.toLowerCase();

        final isHeader =
            lower == 'concept' ||
            lower == 'solution' ||
            lower == 'steps' ||
            lower == 'worked solution' ||
            lower == 'big idea' ||
            lower == 'goal' ||
            lower == 'how to think about it' ||
            lower == 'check yourself' ||
            lower == 'common mistake' ||
            lower == 'final answer' ||
            trimmed.endsWith(':');

        if (isHeader) {
          return TextSpan(
            text: '$line\n',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: lower == 'final answer' ? 17 : 15,
              color: lower == 'final answer'
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          );
        }

        return TextSpan(text: '$line\n');
      }).toList(),
    );
  }

  String _studySummary(String prompt, String reply) {
    final source = prompt.trim().isNotEmpty ? prompt : reply;
    final flattened = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flattened.length <= 100) {
      return flattened;
    }
    return '${flattened.substring(0, 100)}...';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planner = context.watch<StudyPlannerService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Response style',
            initialValue: _mode,
            onSelected: (value) => setState(() => _mode = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'standard', child: Text('Standard')),
              PopupMenuItem(value: 'simple', child: Text('Simple')),
              PopupMenuItem(value: 'coach', child: Text('Coach')),
              PopupMenuItem(value: 'detailed', child: Text('Detailed')),
            ],
          ),
          if (_messages.any((message) => !message.isUser))
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export chat as PDF',
              onPressed: _exportChat,
            ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear chat',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear chat?'),
                    content: const Text(
                      'This will delete the whole conversation.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _messages.clear());
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            color: theme.colorScheme.surfaceContainerLowest,
            child: Text(
              'Tutor language: ${planner.responseLanguageName}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(
                    onSuggestionTap: (text) {
                      _input.text = text;
                      _focusNode.requestFocus();
                    },
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (_, index) => _Bubble(
                      message: _messages[index],
                      theme: theme,
                      format: _format,
                    ),
                  ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Thinking...'),
                    ],
                  ),
                ),
              ),
            ),
          if (_pendingImage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _pendingImage!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Image attached',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove image',
                    onPressed: () => setState(() => _pendingImage = null),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: 'Attach',
                    onPressed: _loading ? null : _showAttachSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focusNode,
                      enabled: !_loading,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask anything...',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _loading
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: theme.colorScheme.onPrimary,
                            ),
                      onPressed: _loading ? null : _send,
                      tooltip: 'Send',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;

  const _EmptyState({required this.onSuggestionTap});

  static const _suggestions = [
    'Solve: 2x + 5 = 13',
    'Explain photosynthesis',
    'Summarize the causes of World War II',
    'What is the Pythagorean theorem?',
    'How does gravity work?',
    'Difference between mean and median',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Ask me anything',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a question, upload an image, or import a PDF to get study help.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _suggestions
                  .map(
                    (suggestion) => ActionChip(
                      label: Text(suggestion),
                      onPressed: () => onSuggestionTap(suggestion),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final ThemeData theme;
  final TextSpan Function(String, ThemeData) format;

  const _Bubble({
    required this.message,
    required this.theme,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.image != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: Image.file(
                  message.image!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(13),
                child: isUser
                    ? Text(
                        message.text,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 15,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(text: format(message.text, theme)),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 16),
                              tooltip: 'Copy',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: message.text),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
