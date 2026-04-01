import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _url = 'https://api.groq.com/openai/v1/chat/completions';

  static String cleanProblem(String text) {
    return text
        .replaceAll('÷', '/')
        .replaceAll('×', '*')
        .replaceAll('x', '*')
        .replaceAll('X', '*')
        .replaceAll(RegExp(r'[^0-9a-zA-Z+\-*/().= ]'), '');
  }

  static Future<String> solve(String input) async {
    if (_apiKey.isEmpty) {
      throw Exception('Missing GROQ_API_KEY in .env');
    }

    final cleaned = cleanProblem(input);

    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              "model": "llama3-70b-8192",
              "messages": [
                {
                  "role": "system",
                  "content":
                      "You are an expert math tutor. Explain step-by-step. Use simple language. Format answers cleanly.",
                },
                {"role": "user", "content": cleaned},
              ],
              "temperature": 0.2,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);

      if (response.statusCode == 401) {
        throw Exception('Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('Too many requests. Try again later.');
      } else if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (data['choices'] == null || data['choices'].isEmpty) {
        throw Exception('Invalid AI response');
      }

      return data['choices'][0]['message']['content'] ?? 'No response';
    } catch (e) {
      throw Exception('Failed to connect to AI');
    }
  }
}
