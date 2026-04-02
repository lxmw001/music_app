import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class GeminiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  final http.Client _client;
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  /// Returns the artist name extracted from a YouTube video title.
  /// Returns null if extraction fails or API key not set.
  Future<String?> extractArtist(String videoTitle) async {
    if (ApiConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') return null;

    try {
      final response = await _client.post(
        Uri.parse('$_endpoint?key=${ApiConfig.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'Extract only the artist/singer name from this YouTube music video title. '
                      'Return just the artist name, nothing else. '
                      'If you cannot determine the artist, return "unknown".\n\nTitle: "$videoTitle"'
                }
              ]
            }
          ],
          'generationConfig': {'maxOutputTokens': 50, 'temperature': 0.1},
        }),
      );

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null || text.trim().toLowerCase() == 'unknown') return null;
      return text.trim();
    } catch (e) {
      return null;
    }
  }
}
