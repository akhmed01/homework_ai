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

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // ✅ Add user message
    messages.add(Message(text: widget.text, isUser: true));

    // 🔥 Auto solve on open
    Future.microtask(() => solveHomework());
  }

  void scrollToBottom() {
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

  Future solveHomework() async {
    setState(() => loading = true);

    try {
      final result = await AIService.solve(widget.text);
      await HistoryService.saveProblem(widget.text);
      setState(() {
        messages.add(Message(text: result, isUser: false));
      });
    } catch (e) {
      setState(() {
        messages.add(
          Message(
            text:
                "⚠️ Failed to get a solution. Please check your connection and try again.",
            isUser: false,
          ),
        );
      });
    } finally {
      setState(() => loading = false);
      scrollToBottom();
    }
  }

  // ✅ Better formatting
  TextSpan formatMessage(String text, ThemeData theme) {
    final lines = text.split('\n');

    return TextSpan(
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 16,
        height: 1.5,
      ),
      children: lines.map((line) {
        if (line.toLowerCase().contains("final answer")) {
          return TextSpan(
            text: "$line\n",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          );
        }
        return TextSpan(text: "$line\n");
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("AI Solution")),

      body: Column(
        children: [
          // 💬 CHAT
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];

                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? theme.colorScheme.primary
                          : theme
                                .colorScheme
                                .surfaceContainerHighest, // ✅ fixed deprecated surfaceVariant
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: msg.isUser
                        ? Text(
                            msg.text,
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 16,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(text: formatMessage(msg.text, theme)),

                              const SizedBox(height: 6),

                              // 📋 Copy button
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: msg.text),
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Copied!")),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),

          // 🤖 LOADING
          if (loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 12),
                  Text("Solving your homework..."),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
