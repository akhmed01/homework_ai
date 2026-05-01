import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../services/pdf_service.dart';
import '../services/study_planner_service.dart';

class ResultScreen extends StatefulWidget {
  final String text;
  final File? sourceImage;

  const ResultScreen({super.key, required this.text, this.sourceImage});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final List<Message> _messages = [];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = false;
  String _mode = 'standard';
  File? _pendingImage;

  @override
  void initState() {
    super.initState();
    _messages.add(
      Message(text: widget.text, isUser: true, image: widget.sourceImage),
    );
    Future.microtask(_autoSolve);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _autoSolve() async {
    await _sendToAI();
    await HistoryService.saveProblem(widget.text);
  }

  Future<void> _sendMessage() async {
    final text = _input.text.trim();
    if ((text.isEmpty && _pendingImage == null) || _loading) {
      return;
    }

    final userMessage = Message(text: text, isUser: true, image: _pendingImage);

    setState(() {
      _messages.add(userMessage);
      _pendingImage = null;
    });

    _input.clear();
    _scrollToBottom();
    await _sendToAI();
  }

  Future<void> _sendToAI() async {
    if (_loading) {
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

      await planner.recordAiSession(
        summary: _studySummary(_messages.first.text, reply),
      );
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
            onPressed: _sendToAI,
          ),
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

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Import PDF'),
              onTap: () {
                Navigator.pop(context);
                _importPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportTranscript() async {
    final transcript = _messages
        .map(
          (message) => '${message.isUser ? 'You' : 'Tutor'}: ${message.text}',
        )
        .join('\n\n');

    try {
      final file = await PdfService.exportTextAsPdf(
        title: 'solution-export',
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
      ).showSnackBar(SnackBar(content: Text('Could not export PDF: $e')));
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
        title: const Text('AI Tutor'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Solution style',
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
              tooltip: 'Export answer as PDF',
              onPressed: _exportTranscript,
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
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (_, index) => _ChatBubble(
                message: _messages[index],
                theme: theme,
                formatMessage: _format,
              ),
            ),
          ),
          if (_loading) _TypingIndicator(theme: theme),
          if (_pendingImage != null)
            _PendingImagePreview(
              file: _pendingImage!,
              onRemove: () => setState(() => _pendingImage = null),
            ),
          _ChatInputBar(
            controller: _input,
            focusNode: _focusNode,
            loading: _loading,
            onAttach: _showAttachSheet,
            onSend: _sendMessage,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Message message;
  final ThemeData theme;
  final TextSpan Function(String, ThemeData) formatMessage;

  const _ChatBubble({
    required this.message,
    required this.theme,
    required this.formatMessage,
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
                          RichText(text: formatMessage(message.text, theme)),
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

class _TypingIndicator extends StatelessWidget {
  final ThemeData theme;

  const _TypingIndicator({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }
}

class _PendingImagePreview extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _PendingImagePreview({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(file, width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Image attached',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
            tooltip: 'Remove image',
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final ThemeData theme;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onAttach,
    required this.onSend,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              onPressed: loading ? null : onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !loading,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ask a follow-up question...',
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
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: loading
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: loading
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
                onPressed: loading ? null : onSend,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
