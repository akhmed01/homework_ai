import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/message.dart';

class AIService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _url = 'https://api.groq.com/openai/v1/chat/completions';

  /// Text-only model — fast, for follow-up questions.
  static const String _textModel = 'llama-3.1-8b-instant';

  /// Vision model — used when any message carries an image.
  static const String _visionModel =
      'meta-llama/llama-4-scout-17b-16e-instruct';

  static const int _maxRetries = 2;

  // ── Minimal normalisation (preserves word problems) ──────────────────────
  static String _clean(String text) =>
      text.replaceAll('÷', '/').replaceAll('×', '*').trim();

  // ── System prompt per mode ───────────────────────────────────────────────
  static String _systemPrompt(String mode) => switch (mode) {
    'eli5' =>
      'You are a friendly tutor for a 12-year-old student. '
          'You help with ANY subject: math, science, history, literature, geography, biology, chemistry, physics, languages, and more. '
          'Use simple words, short sentences, and fun real-life analogies. '
          'Format your response as:\n'
          '💡 Simple Explanation\n[plain-language explanation]\n\n'
          '✅ Answer\n[clear final answer]',
    'detailed' =>
      'You are an expert tutor who helps with ALL school and university subjects — '
          'including math, physics, chemistry, biology, history, geography, literature, economics, programming, and languages. '
          'Give thorough, well-structured answers with full reasoning. '
          'Format your response as:\n'
          '📚 Background\n[brief relevant theory or context]\n\n'
          '🔍 Step-by-step\nStep 1: …\nStep 2: …\n\n'
          '✅ Final Answer\n[complete answer with explanation]',
    _ =>
      'You are a helpful homework tutor for students of all levels. '
          'You assist with ANY subject: mathematics, science (physics, chemistry, biology), '
          'humanities (history, geography, literature, philosophy), languages, economics, programming, and more. '
          'When an image is provided, read it carefully and answer based on what you see. '
          'Give clear, accurate, well-organised answers. '
          'For problems with steps, format as:\n'
          '🔍 Solution\nStep 1: …\nStep 2: …\n\n'
          '✅ Answer\n[final answer]\n\n'
          'For essay or theory questions, give a well-structured explanation without forcing the step format.',
  };

  /// Send the full conversation history to the AI and get the next reply.
  ///
  /// [history] — all messages so far (user + assistant turns).
  /// [mode]    — 'standard' | 'eli5' | 'detailed'
  static Future<String> chat(
    List<Message> history, {
    String mode = 'standard',
  }) async {
    if (_apiKey.isEmpty) throw Exception('Missing GROQ_API_KEY in .env');

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
          throw Exception('Invalid API key — check your .env file');
        } else if (response.statusCode == 429) {
          throw Exception('Rate limit reached — please wait a moment');
        } else if (response.statusCode != 200) {
          throw Exception('Server error (${response.statusCode})');
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

  // ── Build the Groq-compatible messages array ─────────────────────────────
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
          // Vision turn: content is a list with image_url + optional text
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

  /// Legacy compat — single-turn solve without history.
  @Deprecated('Use chat() with a history list instead')
  static Future<String> solve(String input, {String mode = 'standard'}) =>
      chat([Message(text: input, isUser: true)], mode: mode);
}
