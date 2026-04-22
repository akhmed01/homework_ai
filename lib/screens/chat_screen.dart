import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/message.dart';
import '../services/ai_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  bool _loading = false;
  String _mode = 'standard';

  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  File? _pendingImage;

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Scroll ───────────────────────────────────────────────────────────────

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

  // ── Send ─────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _input.text.trim();
    if ((text.isEmpty && _pendingImage == null) || _loading) return;

    final userMsg = Message(
      text: text,
      isUser: true,
      image: _pendingImage,
    );

    setState(() {
      _messages.add(userMsg);
      _pendingImage = null;
      _loading = true;
    });

    _input.clear();
    _scrollToBottom();

    try {
      final reply = await AIService.chat(_messages, mode: _mode);
      if (!mounted) return;
      setState(() {
        _messages.add(Message(text: reply, isUser: false));
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
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
    // Remove last failed assistant turn if any, then re-send
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      setState(() => _messages.removeLast());
    }
    _sendToAI();
  }

  Future<void> _sendToAI() async {
    if (_loading || _messages.isEmpty) return;
    setState(() => _loading = true);

    try {
      final reply = await AIService.chat(_messages, mode: _mode);
      if (!mounted) return;
      setState(() {
        _messages.add(Message(text: reply, isUser: false));
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
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

  // ── Image picker ─────────────────────────────────────────────────────────

  void _showAttachSheet() {
    showModalBottomSheet(
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
                subtitle: const Text('Use camera to capture homework'),
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    setState(() => _pendingImage = File(picked.path));
  }

  // ── Formatting ───────────────────────────────────────────────────────────

  TextSpan _format(String text, ThemeData theme) {
    final lines = text.split('\n');
    return TextSpan(
      style: TextStyle(
          color: theme.colorScheme.onSurface, fontSize: 15, height: 1.6),
      children: lines.map((line) {
        final lower = line.toLowerCase();
        if (lower.contains('final answer') || lower.startsWith('✅')) {
          return TextSpan(
            text: '$line\n',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: theme.colorScheme.primary,
            ),
          );
        }
        if (RegExp(r'^[📚🔢💡📝🎯✏️🧠]').hasMatch(line) ||
            (line.endsWith(':') && line.length < 40)) {
          return TextSpan(
            text: '$line\n',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          );
        }
        return TextSpan(text: '$line\n');
      }).toList(),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        actions: [
          // Mode selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Response style',
            initialValue: _mode,
            onSelected: (val) => setState(() => _mode = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'standard', child: Text('⚡ Standard')),
              PopupMenuItem(value: 'eli5', child: Text('💡 Explain simply')),
              PopupMenuItem(value: 'detailed', child: Text('📚 Detailed')),
            ],
          ),
          // Clear conversation
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear chat',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear chat?'),
                    content: const Text('This will delete the whole conversation.'),
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
          // ── Messages or empty state ────────────────────────────────────
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
                        horizontal: 14, vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        _Bubble(msg: _messages[i], theme: theme, format: _format),
                  ),
          ),

          // ── Typing indicator ──────────────────────────────────────────
          if (_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
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
                      const Text('Thinking…'),
                    ],
                  ),
                ),
              ),
            ),

          // ── Pending image strip ───────────────────────────────────────
          if (_pendingImage != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_pendingImage!,
                        width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Image attached',
                        style: theme.textTheme.bodySmall),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _pendingImage = null),
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ),

          // ── Input bar ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_photo_alternate_outlined,
                        color: theme.colorScheme.primary),
                    tooltip: 'Attach image',
                    onPressed: _loading ? null : _showAttachSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focusNode,
                      enabled: !_loading,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask anything…',
                        filled: true,
                        fillColor:
                            theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
                          : Icon(Icons.send_rounded,
                              color: theme.colorScheme.onPrimary),
                      onPressed: _loading ? null : _send,
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

// ─────────────────────────────────────────────────────────────────────────────
// Empty state with suggestion chips
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;

  const _EmptyState({required this.onSuggestionTap});

  static const _suggestions = [
    '📐 Solve: 2x + 5 = 13',
    '🧪 Explain photosynthesis',
    '📜 Summarise WW2 causes',
    '🔢 What is the Pythagorean theorem?',
    '💡 How does gravity work?',
    '📊 Difference between mean and median',
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
            Icon(Icons.auto_awesome,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Ask me anything',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a question or attach a photo of your homework',
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
              children: _suggestions.map((s) {
                return ActionChip(
                  label: Text(s),
                  onPressed: () => onSuggestionTap(
                    // strip the emoji prefix before putting in input
                    s.substring(s.indexOf(' ') + 1),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat bubble
// ─────────────────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final Message msg;
  final ThemeData theme;
  final TextSpan Function(String, ThemeData) format;

  const _Bubble({
    required this.msg,
    required this.theme,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
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
            // Image thumbnail
            if (msg.image != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: Image.file(
                  msg.image!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),

            // Text
            if (msg.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(13),
                child: isUser
                    ? Text(
                        msg.text,
                        style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 15),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(text: format(msg.text, theme)),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 16),
                              tooltip: 'Copy',
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: msg.text));
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
