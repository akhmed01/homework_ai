import 'package:flutter/material.dart';
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

    // Add user message first
    messages.add(Message(text: widget.text, isUser: true));
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
    setState(() {
      loading = true;
    });

    final result = await AIService.solveProblem(widget.text);

    await HistoryService.saveProblem(widget.text);

    setState(() {
      messages.add(Message(text: result, isUser: false));
      loading = false;
    });

    scrollToBottom(); // ⭐ auto scroll
  }

  // ⭐ Format AI response (highlight final answer)
  TextSpan formatMessage(String text) {
    if (text.contains("Final Answer")) {
      final parts = text.split("Final Answer");

      return TextSpan(
        children: [
          TextSpan(text: parts[0]),
          const TextSpan(
            text: "\nFinal Answer",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: parts[1]),
        ],
      );
    }

    return TextSpan(text: text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Chat"),
        backgroundColor: const Color(0xFF4F46E5),
      ),

      body: Column(
        children: [
          // 💬 CHAT MESSAGES
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
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? const Color(0xFF4F46E5)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: msg.isUser
                        ? Text(
                            msg.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          )
                        : RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                height: 1.5,
                              ),
                              children: [formatMessage(msg.text)],
                            ),
                          ),
                  ),
                );
              },
            ),
          ),

          // 🤖 AI TYPING INDICATOR
          if (loading)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                "AI is typing...",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),

          // 🔘 BUTTON
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: solveHomework,
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Solve with AI"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
