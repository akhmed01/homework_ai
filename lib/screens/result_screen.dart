import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';

class ResultScreen extends StatefulWidget {
  final String text;

  const ResultScreen({super.key, required this.text});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<Message> messages = [];
  bool loading = false;
  String _mode = 'standard'; // 'standard' | 'eli5' | 'detailed'

  // Editable OCR text so user can fix mistakes before solving
  late final TextEditingController _editController;
  bool _editingText = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.text);
    messages.add(Message(text: widget.text, isUser: true));
    Future.microtask(() => _solve(widget.text));
  }

  @override
  void dispose() {
    _editController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _solve(String text) async {
    if (loading) return; // prevent double-tap spam

    setState(() {
      loading = true;
      _editingText = false;
    });

    try {
      final result = await AIService.solve(text, mode: _mode);
      await HistoryService.saveProblem(text);

      if (!mounted) return;
      setState(() {
        messages.add(Message(text: result, isUser: false));
        loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _solve(text),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // ✅ Rich text formatter — highlights emoji section headers & final answer
  TextSpan _formatMessage(String text, ThemeData theme) {
    final lines = text.split('\n');

    return TextSpan(
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 15,
        height: 1.6,
      ),
      children: lines.map((line) {
        final lower = line.toLowerCase();

        // Bold + larger for final answer lines
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

        // Bold section headers (lines starting with emoji or ending with colon)
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Solution'),
        actions: [
          // Mode selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Solution style',
            initialValue: _mode,
            onSelected: (val) {
              setState(() {
                _mode = val;
                // Re-solve with new mode
                messages.removeWhere((m) => !m.isUser);
              });
              _solve(_editController.text);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'standard', child: Text('⚡ Standard')),
              PopupMenuItem(value: 'eli5', child: Text('💡 Explain simply')),
              PopupMenuItem(value: 'detailed', child: Text('📚 Detailed')),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // ✏️ Editable OCR preview banner
          if (_editingText) _buildEditBanner(theme) else _buildEditHint(theme),

          // 💬 Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return _buildBubble(msg, theme);
              },
            ),
          ),

          // 🤖 Typing indicator
          if (loading) _buildTypingIndicator(theme),
        ],
      ),
    );
  }

  Widget _buildEditHint(ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _editingText = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            const Icon(Icons.edit_outlined, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _editController.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Text(
              'Tap to edit',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          TextField(
            controller: _editController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Edit OCR text if needed…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _editingText = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  final newText = _editController.text.trim();
                  if (newText.isEmpty) return;
                  setState(() {
                    messages
                      ..clear()
                      ..add(Message(text: newText, isUser: true));
                  });
                  _solve(newText);
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Re-solve'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Message msg, ThemeData theme) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: msg.isUser
            ? Text(
                msg.text,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 15,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(text: _formatMessage(msg.text, theme)),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      tooltip: 'Copy answer',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: msg.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Solving…'),
            ],
          ),
        ),
      ),
    );
  }
}
