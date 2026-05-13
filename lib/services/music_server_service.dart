import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import '../models/user_profile.dart';
import '../models/vibe.dart';
import 'api_service.dart';

class MusicServerService {
  static const _base = 'https://music-app-server-lupbg4y2ha-uc.a.run.app';
  final http.Client _client;
  final ApiService _api = ApiService();

  MusicServerService({http.Client? client}) : _client = client ?? http.Client();

  Future<MusicSearchResult> searchSongs(String query) async {
    try {
      final data = await _api.get('/songs/search-youtube?query=${Uri.encodeComponent(query)}');
      
      return MusicSearchResult(
        songs: _mapSongs(data['songs'] as List? ?? []),
        mixes: _mapSongs(data['mixes'] as List? ?? []),
        videos: _mapSongs(data['videos'] as List? ?? []),
        artists: ((data['artists'] as List?) ?? []).map((a) => a.toString()).toList(),
        hasMoreSongs: data['hasMore'] as bool? ?? false,
      );
    } catch (e) {
      print('[MusicServer] search error: $e');
      return const MusicSearchResult();
    }
  }

  static const _trendingCacheKey = 'server_trending_cache';

  Future<List<Song>> getTrending({int limit = 20, List<String> genres = const []}) async {
    var path = '/songs/trending?limit=$limit';
    if (genres.isNotEmpty) path += '&genres=${genres.join(',')}';
    
    try {
      final data = await _api.get(path);
      final List songsData = data is List ? data : (data['songs'] as List? ?? []);
      final result = _mapSongs(songsData);
      
      // Save to cache for offline use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_trendingCacheKey, jsonEncode(songsData));
      
      return result;
    } catch (e) {
      print('[MusicServer] trending error: $e');
      return getCachedTrending();
    }
  }

  Future<List<Song>> getCachedTrending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trendingCacheKey);
      if (raw != null) {
        final List data = jsonDecode(raw);
        return _mapSongs(data);
      }
    } catch (_) {}
    return [];
  }

  static const _suggestionsCacheKey = 'server_search_suggestions';

  Future<List<String>> getSearchSuggestions() async {
    try {
      final data = await _api.get('/songs/searches');
      final list = (data is List ? data : data['searches'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_suggestionsCacheKey, list.cast<String>());
      return list.cast<String>();
    } catch (_) {
      return getCachedSearchSuggestions();
    }
  }

  Future<List<String>> getCachedSearchSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_suggestionsCacheKey) ?? [];
  }

  Future<String> getStreamUrl(String videoId) async {
    try {
      final data = await _api.get('/songs/$videoId/stream-url');
      return data['streamUrl'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> pushStreamUrl(String id, String streamUrl, {bool isMix = false}) async {
    if (id.isEmpty || streamUrl.isEmpty) return;
    try {
      final expireMatch = RegExp(r'expire=(\d+)').firstMatch(streamUrl);
      final expiresAt = expireMatch != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(expireMatch.group(1)!) * 1000).toUtc().toIso8601String()
          : DateTime.now().add(const Duration(hours: 6)).toUtc().toIso8601String();

      final path = isMix ? '/songs/mixes/$id/stream-url' : '/songs/$id/stream-url';
      await _api.post(path, body: {'streamUrl': streamUrl, 'expiresAt': expiresAt});
    } catch (e) {
      print('[MusicServer] pushStreamUrl error: $e');
    }
  }

  Future<List<Song>> generatePlaylist(String id, {int limit = 30, String? search}) async {
    var path = '/songs/$id/generate-playlist?limit=$limit';
    if (search != null && search.isNotEmpty) path += '&search=${Uri.encodeComponent(search)}';
    
    try {
      final data = await _api.get(path);
      final List songs = data is List ? data : (data['songs'] as List? ?? []);
      return _mapSongs(songs);
    } catch (e) {
      print('[MusicServer] generate-playlist error: $e');
      return [];
    }
  }

  // ── Vibes ──────────────────────────────────────────────────────────────────

  static const _vibesCacheKey = 'server_vibes_cache';

  Future<List<Vibe>> getVibes() async {
    try {
      final List data = await _api.get('/vibes');
      final vibes = data.map((v) => Vibe.fromJson(v as Map<String, dynamic>)).toList();
      
      // Save to cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_vibesCacheKey, jsonEncode(data));
      
      return vibes;
    } catch (e) {
      print('[MusicServer] getVibes error: $e');
      return getCachedVibes();
    }
  }

  Future<List<Vibe>> getCachedVibes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_vibesCacheKey);
      if (raw != null) {
        final List data = jsonDecode(raw);
        return data.map((v) => Vibe.fromJson(v as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return availableVibes; // Hardcoded fallback if nothing in cache
  }

  // ── AI Vibes (Fast Mode) ───────────────────────────────────────────────────

  Future<List<Song>> fetchAIVibe({
    required String vibeId,
    String? subCategoryId,
    required UserProfile profile,
  }) async {
    final now = DateTime.now();
    final payload = {
      'vibeId': vibeId,
      'subCategoryId': subCategoryId,
      'birthYear': profile.birthYear,
      'genres': profile.favoriteGenres,
      'localTime': now.toIso8601String(),
      'dayOfWeek': _getDayName(now.weekday),
    };

    print('[MusicServer] Requesting AI Vibe: $vibeId');
    try {
      // AI generation involves LLM processing and searches, so we use a longer timeout (60s)
      final data = await _api.post('/vibe/generate', body: payload, timeout: const Duration(seconds: 60));
      
      // Handle cases where the response is a direct List or a Map containing a 'songs' key
      final List songsData = data is List ? data : (data['songs'] as List? ?? []);
      return _mapSongs(songsData);
    } catch (e) {
      print('[MusicServer] AI Vibe error: $e');
      return [];
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Monday';
      case DateTime.tuesday: return 'Tuesday';
      case DateTime.wednesday: return 'Wednesday';
      case DateTime.thursday: return 'Thursday';
      case DateTime.friday: return 'Friday';
      case DateTime.saturday: return 'Saturday';
      case DateTime.sunday: return 'Sunday';
      default: return '';
    }
  }

  // ── Songs ──────────────────────────────────────────────────────────────────

  List<Song> _mapSongs(List songs) => songs.map((s) => Song(
    id: (s['youtubeId'] ?? s['videoId'] ?? '') as String,
    serverId: (s['id'] ?? '') as String,
    title: (s['title'] ?? 'Unknown Title') as String,
    artist: (s['artistName'] ?? s['author'] ?? 'Unknown Artist') as String,
    album: (s['album'] ?? '') as String,
    imageUrl: (s['thumbnailUrl'] ?? '') as String,
    audioUrl: '',
    duration: Duration(seconds: (s['duration'] as num?)?.toInt() ?? 0),
    genres: List<String>.from(s['genres'] ?? s['tags'] ?? []),
    streamUrl: s['streamUrl'] as String?,
    streamUrlExpiresAt: s['streamUrlExpiresAt'] != null
        ? DateTime.tryParse(s['streamUrlExpiresAt'] as String)
        : null,
  )).toList();
}
