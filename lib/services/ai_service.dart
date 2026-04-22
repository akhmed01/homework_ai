import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/message.dart';

class AIService {
  static String get _apiKey => AppConfig.groqApiKey;

  static const String _url = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _textModel = 'llama-3.1-8b-instant';
  static const String _visionModel =
      'meta-llama/llama-4-scout-17b-16e-instruct';
  static const int _maxRetries = 2;

  static String _clean(String text) =>
      text.replaceAll('\u00F7', '/').replaceAll('\u00D7', '*').trim();

  static String _systemPrompt(String mode) => switch (mode) {
    'eli5' =>
      'You are a friendly tutor explaining to a 12-year-old. '
          'Use simple words and fun analogies. '
          'Format:\nSimple Explanation\n[explanation]\n\nFinal Answer\n[answer]',
    'detailed' =>
      'You are an expert tutor. Solve with full working. '
          'Format:\nConcept\n[theory]\n\nStep-by-step\nStep 1: ...\n\nFinal Answer\n[answer]',
    _ =>
      'You are an expert homework tutor. '
          'Solve problems clearly and answer follow-up questions in the same conversation. '
          'When an image is provided, read and solve what is shown. '
          'Format solutions as:\nSolution\nStep 1: ...\n\nFinal Answer\n[answer]',
  };

  static Future<String> chat(
    List<Message> history, {
    String mode = 'standard',
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Missing GROQ_API_KEY. Add it to .env or pass --dart-define=GROQ_API_KEY=your_key',
      );
    }

    final hasImage = history.any((m) => m.image != null);
    final model = hasImage ? _visionModel : _textModel;

    final apiMessages = await _buildApiMessages(history, mode);
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
                'model': model,
                'messages': apiMessages,
                'temperature': 0.2,
              }),
            )
            .timeout(const Duration(seconds: 40));

        if (response.statusCode == 401) {
          throw Exception('Invalid API key. Check your GROQ_API_KEY value.');
        } else if (response.statusCode == 429) {
          throw Exception('Rate limit reached. Please wait a moment.');
        } else if (response.statusCode != 200) {
          throw Exception('Server error (${response.statusCode}).');
        }

        final data = jsonDecode(response.body);
        if (data['choices'] == null || (data['choices'] as List).isEmpty) {
          throw Exception('Unexpected AI response format.');
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

  static Future<List<Map<String, dynamic>>> _buildApiMessages(
    List<Message> history,
    String mode,
  ) async {
    final result = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt(mode)},
    ];

    for (final msg in history) {
      if (msg.isUser) {
        if (msg.image != null) {
          final b64 = await _toBase64(msg.image!);
          result.add({
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$b64'},
              },
              if (msg.text.isNotEmpty)
                {'type': 'text', 'text': _clean(msg.text)},
            ],
          });
        } else {
          result.add({'role': 'user', 'content': _clean(msg.text)});
        }
      } else {
        result.add({'role': 'assistant', 'content': msg.text});
      }
    }

    return result;
  }

  static Future<String> _toBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  @Deprecated('Use chat() with a history list instead')
  static Future<String> solve(String input, {String mode = 'standard'}) =>
      chat([Message(text: input, isUser: true)], mode: mode);
}
