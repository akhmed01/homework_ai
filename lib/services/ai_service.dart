import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _url = 'https://api.groq.com/openai/v1/chat/completions';
  static const int _maxRetries = 2;

  // 🔹 Minimal clean — preserve word problems, only normalize math symbols
  static String cleanProblem(String text) {
    return text.replaceAll('÷', '/').replaceAll('×', '*').trim();
    // NOTE: We intentionally do NOT strip letters/punctuation here because
    // word problems like "If a train travels at 60 km/h…" must survive intact.
  }

  // 🔹 Solve with AI — retries + structured prompt
  static Future<String> solve(String input, {String mode = 'standard'}) async {
    if (_apiKey.isEmpty) {
      throw Exception('Missing GROQ_API_KEY in .env');
    }

    final cleaned = cleanProblem(input);

    final systemPrompt = switch (mode) {
      'eli5' =>
        'You are a friendly tutor explaining to a 12-year-old. '
            'Use simple words, short sentences, and a fun analogy. '
            'Format your answer as:\n'
            '💡 Simple Explanation\n'
            '[plain-language explanation]\n\n'
            '✅ Answer\n'
            '[final answer]',
      'detailed' =>
        'You are an expert tutor. Solve the problem with full working. '
            'Format your answer as:\n'
            '📚 Concept\n'
            '[brief theory]\n\n'
            '🔢 Step-by-step Solution\n'
            'Step 1: …\nStep 2: …\n\n'
            '✅ Final Answer\n'
            '[answer with units]',
      _ =>
        'You are an expert tutor. Solve the problem clearly. '
            'Format your answer as:\n'
            '🔢 Solution\n'
            'Step 1: …\nStep 2: …\n\n'
            '✅ Final Answer\n'
            '[answer]',
    };

    Exception? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
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
                  {"role": "system", "content": systemPrompt},
                  {"role": "user", "content": cleaned},
                ],
                "temperature": 0.2,
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 401) {
          throw Exception('Invalid API key — check your .env file');
        } else if (response.statusCode == 429) {
          throw Exception(
            'Rate limit reached — please wait a moment and try again',
          );
        } else if (response.statusCode != 200) {
          throw Exception('Server error (${response.statusCode}) — try again');
        }

        final data = jsonDecode(response.body);

        if (data['choices'] == null || (data['choices'] as List).isEmpty) {
          throw Exception('Unexpected AI response format');
        }

        return data['choices'][0]['message']['content'] as String? ??
            'No response received';
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: attempt + 1));
        }
      }
    }

    throw lastError!;
  }
}
