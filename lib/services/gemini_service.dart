import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class SongMetadata {
  final String artist;
  final String genre;
  final bool isMix;
  final List<String> suggestedQueries;

  SongMetadata({
    required this.artist,
    required this.genre,
    required this.isMix,
    required this.suggestedQueries,
  });

  factory SongMetadata.fromJson(Map<String, dynamic> json) => SongMetadata(
        artist: json['artist'] ?? '',
        genre: json['genre'] ?? '',
        isMix: json['isMix'] ?? false,
        suggestedQueries: List<String>.from(json['suggestedQueries'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'artist': artist,
        'genre': genre,
        'isMix': isMix,
        'suggestedQueries': suggestedQueries,
      };

  String? randomQuery() {
    if (suggestedQueries.isEmpty) return null;
    return suggestedQueries[Random().nextInt(suggestedQueries.length)];
  }
}

class GeminiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  static const _cacheKey = 'gemini_song_metadata';

  final http.Client _client;
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  bool get _hasApiKey => ApiConfig.geminiApiKey.isNotEmpty;

  Future<Map<String, dynamic>> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> _saveToCache(String key, SongMetadata metadata) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = await _loadCache();
    cache[key] = metadata.toJson();
    await prefs.setString(_cacheKey, jsonEncode(cache));
  }

  /// Returns metadata for a song title, using local cache when available.
  Future<SongMetadata?> getSongMetadata(String videoTitle) async {
    final key = videoTitle.toLowerCase();

    // 1. Check cache
    final cache = await _loadCache();
    if (cache.containsKey(key)) {
      return SongMetadata.fromJson(cache[key]);
    }

    // 2. No API key — use regex as last resort
    if (!_hasApiKey) {
      print('[Gemini] no API key, using regex for: "$videoTitle"');
      return _regexFallback(videoTitle);
    }

    // 3. Call Gemini
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
                  'text': '''Analyze this YouTube music title. Return ONLY this JSON (no markdown):
{"artist":"<name>","genre":"<genre>","isMix":<bool>,"suggestedQueries":["<q1>","<q2>","<q3>","<q4>","<q5>"]}

isMix=true if compilation/mix/greatest hits (any language).
suggestedQueries: if individual song use artist popular songs + similar artists; if mix use similar genre mixes.
Keep each query under 5 words.

Title: "$videoTitle"'''
                }
              ]
            }
          ],
          'generationConfig': {'maxOutputTokens': 1024, 'temperature': 0.2},
        }),
      );

      if (response.statusCode != 200) {
        print('[Gemini] API error ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) return null;

      final cleaned = text.replaceAll(RegExp(r'```json|```'), '').trim();
      try {
        final metadata = SongMetadata.fromJson(jsonDecode(cleaned));
        print('[Gemini] artist=${metadata.artist}, genre=${metadata.genre}, isMix=${metadata.isMix}');
        print('[Gemini] queries=${metadata.suggestedQueries}');
        await _saveToCache(key, metadata);
        return metadata;
      } catch (e) {
        print('[Gemini] JSON parse error: $e\nRaw: $cleaned');
        return null;
      }
    } catch (e) {
      print('[Gemini] exception: $e');
      return null;
    }
  }

  /// Only used when no API key is available
  SongMetadata? _regexFallback(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'official|video|audio|lyrics|hd|4k|letra', caseSensitive: false), '')
        .trim();
    String? artist;
    if (cleaned.contains(' - ')) {
      final parts = cleaned.split(' - ');
      artist = parts.first.trim().split(' ').length <= parts.last.trim().split(' ').length
          ? parts.first.trim()
          : parts.last.trim();
    } else if (cleaned.contains(', ')) {
      artist = cleaned.split(', ').last.trim().replaceAll(RegExp(r'\s*-\s*$'), '').trim();
    }
    if (artist == null || artist.isEmpty) return null;
    return SongMetadata(
      artist: artist,
      genre: '',
      isMix: false,
      suggestedQueries: ['$artist most popular songs', '$artist best hits'],
    );
  }
}
