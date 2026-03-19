import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // 🔹 Clean OCR text before sending to AI
  static String cleanProblem(String text) {
    return text
        .replaceAll('÷', '/')
        .replaceAll('×', '*')
        .replaceAll('x', '*')
        .replaceAll('X', '*')
        .replaceAll(RegExp(r'[^0-9+\-*/().= ]'), '') // remove weird symbols
        .trim();
  }

  // 🔹 Send to Gemini AI
  static Future<String> solveProblem(String problem) async {
    String cleaned = cleanProblem(problem);

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=YOUR_API_KEY",
    );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                      "Solve this math problem step by step. Show each step clearly and give final answer:\n$cleaned",
                },
              ],
            },
          ],
        }),
      );

      final data = jsonDecode(response.body);

      return data["candidates"][0]["content"]["parts"][0]["text"];
    } catch (e) {
      return "Error: Could not get AI response.";
    }
  }
}
