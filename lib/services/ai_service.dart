import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _url = 'https://api.groq.com/openai/v1/chat/completions';

  // 🔹 Normalize math symbols only — preserve full problem text for AI
  static String cleanProblem(String text) {
    return text.replaceAll('÷', '/').replaceAll('×', '*').trim();
  }

  // 🔹 Solve with AI
  static Future<String> solve(String input) async {
    if (_apiKey.isEmpty) {
      throw Exception('❌ Missing GROQ_API_KEY in .env');
    }

    final cleaned = cleanProblem(input);

    print("📤 TEXT SENT: $cleaned");
    print("🔑 API KEY LENGTH: ${_apiKey.length}");
    print("🚀 Sending request to AI...");

    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              "model": "llama-3.1-8b-instant",
              "messages": [
                {
                  "role": "system",
                  "content":
                      "You are an expert tutor. Solve the problem step-by-step and keep answers clean and readable. Handle both pure math and word problems.",
                },
                {"role": "user", "content": cleaned},
              ],
              "temperature": 0.2,
            }),
          )
          .timeout(const Duration(seconds: 20));

      print("📡 STATUS CODE: ${response.statusCode}");
      print("📦 RAW RESPONSE: ${response.body}");

      if (response.statusCode == 401) {
        throw Exception('❌ Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('❌ Too many requests (rate limit)');
      } else if (response.statusCode != 200) {
        throw Exception('❌ Server error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (data['choices'] == null || data['choices'].isEmpty) {
        throw Exception('❌ Invalid AI response format');
      }

      final result = data['choices'][0]['message']['content'] ?? 'No response';

      print("✅ AI RESULT: $result");

      return result;
    } catch (e) {
      print("🔥 ERROR: $e");
      throw Exception(e.toString());
    }
  }
}
