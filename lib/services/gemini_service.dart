import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class GeminiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  static const _cacheKey = 'gemini_known_artists';

  final http.Client _client;
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  bool get _hasApiKey => ApiConfig.geminiApiKey.isNotEmpty;

  Future<Set<String>> _loadKnownArtists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return {};
    return Set<String>.from(jsonDecode(raw));
  }

  Future<void> _addKnownArtist(String artist) async {
    final prefs = await SharedPreferences.getInstance();
    final artists = await _loadKnownArtists()..add(artist.toLowerCase());
    await prefs.setString(_cacheKey, jsonEncode(artists.toList()));
  }

  /// Returns the artist name from the title.
  /// Checks known artists cache first, then regex, then Gemini API.
  Future<String?> extractArtist(String videoTitle) async {
    // 1. Check if any known artist appears in the title
    final knownArtists = await _loadKnownArtists();
    final titleLower = videoTitle.toLowerCase();
    for (final artist in knownArtists) {
      if (titleLower.contains(artist)) {
        print('[Gemini] cache hit: "$artist" in "$videoTitle"');
        return artist;
      }
    }

    // 2. Try regex for "Artist - Title" pattern
    final regexArtist = _extractFromTitle(videoTitle);
    if (regexArtist != null) {
      print('[Gemini] regex extracted: "$regexArtist" from "$videoTitle"');
      await _addKnownArtist(regexArtist);
      return regexArtist;
    }

    // 3. Call Gemini API if key is available
    if (!_hasApiKey) {
      print('[Gemini] no API key, skipping: "$videoTitle"');
      return null;
    }
    print('[Gemini] calling API for: "$videoTitle"');
    try {
      final response = await _client.post(
        Uri.parse('$_endpoint?key=${ApiConfig.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'Extract only the artist/singer name from this YouTube music video title. '
                      'Return just the artist name, nothing else. '
                      'If you cannot determine the artist, return "unknown".\n\nTitle: "$videoTitle"'
                }
              ]
            }
          ],
          'generationConfig': {'maxOutputTokens': 50, 'temperature': 0.1},
        }),
      );
      if (response.statusCode != 200) {
        print('[Gemini] API error ${response.statusCode}: ${response.body}');
        return null;
      }
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null || text.trim().toLowerCase() == 'unknown') {
        print('[Gemini] could not extract artist from: "$videoTitle"');
        return null;
      }
      final artist = text.trim();
      print('[Gemini] API extracted: "$artist" from "$videoTitle"');
      await _addKnownArtist(artist);
      return artist;
    } catch (e) {
      print('[Gemini] exception: $e');
      return null;
    }
  }

  String? _extractFromTitle(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'official|video|audio|lyrics|hd|4k', caseSensitive: false), '')
        .trim();
    if (cleaned.contains(' - ')) {
      final artist = cleaned.split(' - ').first.trim();
      if (artist.isNotEmpty && artist.split(' ').length <= 4) return artist;
    }
    return null;
  }
}
