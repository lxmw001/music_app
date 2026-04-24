import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';

class MusicServerService {
  static const _base = 'https://music-app-server-lupbg4y2ha-uc.a.run.app';
  final http.Client _client;

  MusicServerService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Song>> searchSongs(String query) async {
    final uri = Uri.parse('$_base/songs/search-youtube')
        .replace(queryParameters: {'query': query});
    print('[MusicServer] GET $uri');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      print('[MusicServer] search status: ${response.statusCode}');
      print('[MusicServer] search body: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final songs = data['songs'] as List? ?? [];
      final result = _mapSongs(songs);
      print('[MusicServer] search "$query": ${result.length} songs — ${result.take(3).map((s) => "${s.title}/${s.artist}").join(", ")}');
      return result;
    } catch (e) {
      print('[MusicServer] search error: $e');
      return [];
    }
  }

  Future<List<Song>> getTrending({int limit = 20, List<String> genres = const []}) async {
    final params = <String, String>{'limit': '$limit'};
    if (genres.isNotEmpty) params['genres'] = genres.join(',');
    final uri = Uri.parse('$_base/songs/trending').replace(queryParameters: params);
    print('[MusicServer] GET $uri');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      print('[MusicServer] trending status: ${response.statusCode}');
      print('[MusicServer] trending body: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) return [];

      final data = jsonDecode(response.body);
      final songs = data is List ? data : (data['songs'] as List? ?? []);
      final result = _mapSongs(songs as List);
      print('[MusicServer] trending: ${result.length} songs — ${result.take(3).map((s) => "${s.title}/${s.artist}").join(", ")}');
      return result;
    } catch (e) {
      print('[MusicServer] trending error: $e');
      return [];
    }
  }

  static const _suggestionsCacheKey = 'server_search_suggestions';

  Future<List<String>> getSearchSuggestions() async {
    try {
      final uri = Uri.parse('$_base/songs/searches');
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return _cachedSuggestions();
      final data = jsonDecode(response.body);
      final list = (data is List ? data : data['searches'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      // Cache for offline use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_suggestionsCacheKey, list.cast<String>());
      return list.cast<String>();
    } catch (_) {
      return _cachedSuggestions();
    }
  }

  Future<List<String>> _cachedSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_suggestionsCacheKey) ?? [];
  }

  Future<List<Song>> generatePlaylist(String id, {int limit = 30, String? search}) async {
    final params = <String, String>{'limit': '$limit'};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$_base/songs/$id/generate-playlist')
        .replace(queryParameters: params);
    print('[MusicServer] GET $uri');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      print('[MusicServer] generate-playlist status: ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) return [];
      final data = jsonDecode(response.body);
      final songs = data is List ? data : (data['songs'] as List? ?? []);
      return _mapSongs(songs as List);
    } catch (e) {
      print('[MusicServer] generate-playlist error: $e');
      return [];
    }
  }

  List<Song> _mapSongs(List songs) => songs.map((s) => Song(
    id: s['youtubeId'] as String,
    serverId: s['id'] as String? ?? '',
    title: s['title'] as String,
    artist: s['artistName'] as String,
    album: s['album'] as String? ?? '',
    imageUrl: s['thumbnailUrl'] as String? ?? '',
    audioUrl: '',
    duration: Duration(seconds: (s['duration'] as num?)?.toInt() ?? 0),
    genres: List<String>.from(s['genres'] ?? s['tags'] ?? []),
  )).toList();
}
