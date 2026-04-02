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

  /// Returns a YouTube search query for finding similar songs.
  /// - Individual song → "<artist> music"
  /// - Mix/compilation (any language) → similar mix query
  Future<String?> getSuggestionQuery(String videoTitle) async {
    // 1. Check known artists cache
    final knownArtists = await _loadKnownArtists();
    final titleLower = videoTitle.toLowerCase();
    for (final artist in knownArtists) {
      if (titleLower.contains(artist)) return '$artist music';
    }

    // 2. Regex for obvious "Artist - Song" pattern
    final regexArtist = _extractFromTitle(videoTitle);
    if (regexArtist != null) {
      await _addKnownArtist(regexArtist);
      return '$regexArtist music';
    }

    // 3. Gemini API
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
                  'text': 'Analyze this YouTube music video title and return a YouTube search query to find similar music.\n\n'
                      'Rules:\n'
                      '- If it is a mix, compilation, or greatest hits style (in any language): return a query for similar mixes of the same genre/style\n'
                      '- If it is an individual song: return "<artist name> music"\n'
                      '- Return ONLY the search query, nothing else.\n\n'
                      'Title: "$videoTitle"'
                }
              ]
            }
          ],
          'generationConfig': {'maxOutputTokens': 30, 'temperature': 0.1},
        }),
      );
      if (response.statusCode != 200) {
        print('[Gemini] API error ${response.statusCode}: ${response.body}');
        return null;
      }
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) return null;
      final query = text.trim();
      print('[Gemini] suggestion query: "$query"');
      if (query.endsWith(' music')) {
        await _addKnownArtist(query.replaceAll(' music', '').trim());
      }
      return query;
    } catch (e) {
      print('[Gemini] exception: $e');
      return null;
    }
  }

  String? _extractFromTitle(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'official|video|audio|lyrics|hd|4k|letra', caseSensitive: false), '')
        .trim();

    if (cleaned.contains(' - ')) {
      final parts = cleaned.split(' - ');
      final artist = parts.first.trim().split(' ').length <= parts.last.trim().split(' ').length
          ? parts.first.trim()
          : parts.last.trim();
      if (artist.isNotEmpty && artist.split(' ').length <= 5) return artist;
    }

    if (cleaned.contains(', ')) {
      final artist = cleaned.split(', ').last.trim()
          .replaceAll(RegExp(r'\s*-\s*$'), '').trim();
      if (artist.isNotEmpty && artist.split(' ').length <= 5) return artist;
    }

    return null;
  }
}
