import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static Future<String> solveProblem(String problem) async {
    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyAoEnWyEijRYTh9IjKTaGD-wDCAwgwk0H0",
    );

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Explain step by step how to solve this homework problem:\n$problem",
              },
            ],
          },
        ],
      }),
    );

    final data = jsonDecode(response.body);

    return data["candidates"][0]["content"]["parts"][0]["text"];
  }
}
