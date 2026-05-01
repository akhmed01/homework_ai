import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/message.dart';

class AIService {
  static const String _url = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _textModel = 'llama-3.1-8b-instant';
  static const String _visionModel =
      'meta-llama/llama-4-scout-17b-16e-instruct';
  static const int _maxRetries = 2;

  static String get _apiKey {
    try {
      return AppConfig.groqApiKey;
    } catch (e) {
      debugPrint('Error accessing API key: $e');
      return '';
    }
  }

  static String _clean(String text) =>
      text.replaceAll('\u00F7', '/').replaceAll('\u00D7', '*').trim();

  static String _languageName(String code) {
    switch (code) {
      case 'mn':
        return 'Mongolian';
      case 'es':
        return 'Spanish';
      default:
        return 'English';
    }
  }

  static String _systemPrompt(String mode, String responseLanguageCode) {
    final language = _languageName(responseLanguageCode);
    final base =
        'You are Homework AI, a patient tutor who helps students learn instead of just copy. '
        'Always answer in $language unless the student explicitly asks for a different language. '
        'Keep equations accurate, point out the key idea, and be honest when information is missing. '
        'If the student sends an image, read the homework from the image before solving it.';

    switch (mode) {
      case 'simple':
      case 'eli5':
        return '$base '
            'Use simple words, short sentences, and one idea at a time. '
            'Format with these sections exactly:\n'
            'Big Idea\n'
            '[one short explanation]\n\n'
            'Steps\n'
            '1. ...\n'
            '2. ...\n\n'
            'Final Answer\n'
            '[answer]';
      case 'coach':
        return '$base '
            'Teach like a coach. Emphasize the method, the likely mistake, and how to check the result. '
            'Format with these sections exactly:\n'
            'Goal\n'
            '[what we need to find]\n\n'
            'How To Think About It\n'
            '[strategy]\n\n'
            'Steps\n'
            '1. ...\n'
            '2. ...\n\n'
            'Check Yourself\n'
            '[quick self-check]\n\n'
            'Final Answer\n'
            '[answer]';
      case 'detailed':
        return '$base '
            'Give a thorough, step-by-step explanation with reasoning. '
            'Format with these sections exactly:\n'
            'Concept\n'
            '[core theory]\n\n'
            'Worked Solution\n'
            'Step 1: ...\n'
            'Step 2: ...\n\n'
            'Common Mistake\n'
            '[pitfall]\n\n'
            'Final Answer\n'
            '[answer]';
      default:
        return '$base '
            'Keep the answer clear, structured, and useful for studying. '
            'Format with these sections exactly:\n'
            'Concept\n'
            '[short explanation]\n\n'
            'Solution\n'
            'Step 1: ...\n'
            'Step 2: ...\n\n'
            'Final Answer\n'
            '[answer]';
    }
  }

  static Future<String> chat(
    List<Message> history, {
    String mode = 'standard',
    String responseLanguageCode = 'en',
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Missing GROQ_API_KEY. Add it to .env or pass --dart-define=GROQ_API_KEY=your_key',
      );
    }

    final hasImage = history.any((message) => message.image != null);
    final model = hasImage ? _visionModel : _textModel;
    final apiMessages = await _buildApiMessages(
      history,
      mode,
      responseLanguageCode,
    );

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
        }
        if (response.statusCode == 429) {
          throw Exception('Rate limit reached. Please wait a moment.');
        }
        if (response.statusCode != 200) {
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
    String responseLanguageCode,
  ) async {
    final result = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt(mode, responseLanguageCode)},
    ];

    for (final message in history) {
      if (message.isUser) {
        if (message.image != null) {
          final base64Image = await _toBase64(message.image!);
          result.add({
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
              if (message.text.isNotEmpty)
                {'type': 'text', 'text': _clean(message.text)},
            ],
          });
        } else {
          result.add({'role': 'user', 'content': _clean(message.text)});
        }
      } else {
        result.add({'role': 'assistant', 'content': message.text});
      }
    }

    return result;
  }

  static Future<String> _toBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }
}
