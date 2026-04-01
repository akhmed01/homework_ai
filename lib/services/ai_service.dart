import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String apiKey = "PASTE_YOUR_GROQ_API_KEY_HERE";

  static const String _baseUrl =
      "https://api.groq.com/openai/v1/chat/completions";

  /// 🔹 Clean OCR text (VERY IMPORTANT)
  static String cleanProblem(String text) {
    return text
        .replaceAll('÷', '/')
        .replaceAll('×', '*')
        .replaceAll('x', '*')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 🔹 Main function
  static Future<String> solveProblem(String problem) async {
    try {
      final cleaned = cleanProblem(problem);

      final prompt =
          """
Solve this step-by-step like a teacher.

Problem:
$cleaned

Rules:
- Show clear steps
- Use simple explanations
- Final answer at the end
""";

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              "Authorization": "Bearer $apiKey",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "model": "llama3-70b-8192", // 🔥 better model
              "messages": [
                {
                  "role": "system",
                  "content":
                      "You are a professional math tutor who explains clearly.",
                },
                {"role": "user", "content": prompt},
              ],
              "temperature": 0.3,
              "max_tokens": 800,
            }),
          )
          .timeout(const Duration(seconds: 20)); // ⏱️ timeout

      if (response.statusCode != 200) {
        return "❌ API Error (${response.statusCode})\n${response.body}";
      }

      final data = jsonDecode(response.body);

      final content = data["choices"]?[0]?["message"]?["content"];

      if (content == null || content.toString().trim().isEmpty) {
        return "⚠️ Empty response from AI";
      }

      return content;
    } catch (e) {
      return "❌ Error: $e";
    }
  }
}
