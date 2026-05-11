import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import '../models/user_profile.dart';

class MusicServerService {
  static const _base = 'https://music-app-server-lupbg4y2ha-uc.a.run.app';

  // TODO: Replace with FirebaseAuth.instance.currentUser?.getIdToken() once Firebase is set up
  static const _placeholderToken = '';

  final http.Client _client;

  MusicServerService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_placeholderToken.isNotEmpty) 'Authorization': 'Bearer $_placeholderToken',
  };

  Future<MusicSearchResult> searchSongs(String query) async {
    final uri = Uri.parse('$_base/songs/search-youtube')
        .replace(queryParameters: {'query': query});
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) return const MusicSearchResult();

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = MusicSearchResult(
        songs: _mapSongs(data['songs'] as List? ?? []),
        mixes: _mapSongs(data['mixes'] as List? ?? []),
        videos: _mapSongs(data['videos'] as List? ?? []),
        artists: ((data['artists'] as List?) ?? []).map((a) => a.toString()).toList(),
        hasMoreSongs: data['hasMore'] as bool? ?? false,
      );

      return result;
    } catch (e) {
      print('[MusicServer] search error: $e');
      return const MusicSearchResult();
    }
  }

  Future<List<Song>> getTrending({int limit = 20, List<String> genres = const []}) async {
    final params = <String, String>{'limit': '$limit'};
    if (genres.isNotEmpty) params['genres'] = genres.join(',');
    final uri = Uri.parse('$_base/songs/trending').replace(queryParameters: params);
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) return [];

      final data = jsonDecode(response.body);
      final List songs = data is List ? data : (data['songs'] as List? ?? []);
      final result = _mapSongs(songs);

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

  Future<String> getStreamUrl(String videoId) async {
    try {
      final uri = Uri.parse('$_base/songs/$videoId/stream-url');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) return '';
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['streamUrl'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Push a resolved stream URL to the server for caching.
  Future<void> pushStreamUrl(String id, String streamUrl, {bool isMix = false}) async {
    if (id.isEmpty || streamUrl.isEmpty) return;
    try {
      final expireMatch = RegExp(r'expire=(\d+)').firstMatch(streamUrl);
      final expiresAt = expireMatch != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(expireMatch.group(1)!) * 1000).toUtc().toIso8601String()
          : DateTime.now().add(const Duration(hours: 6)).toUtc().toIso8601String();

      final path = isMix ? 'songs/mixes/$id/stream-url' : 'songs/$id/stream-url';
      final uri = Uri.parse('$_base/$path');
      await _client.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'streamUrl': streamUrl, 'expiresAt': expiresAt}),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[MusicServer] pushStreamUrl error: $e');
    }
  }

  Future<List<Song>> generatePlaylist(String id, {int limit = 30, String? search}) async {
    final params = <String, String>{'limit': '$limit'};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$_base/songs/$id/generate-playlist')
        .replace(queryParameters: params);
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) return [];
      final data = jsonDecode(response.body);
      final List songs = data is List ? data : (data['songs'] as List? ?? []);
      return _mapSongs(songs);
    } catch (e) {
      print('[MusicServer] generate-playlist error: $e');
      return [];
    }
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

    final uri = Uri.parse('$_base/vibe/generate');
    print('[MusicServer] POST $uri with payload: $payload');
    try {
      final response = await _client.post(
        uri,
        headers: _authHeaders,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 45));

      print('[MusicServer] AI Vibe status: ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) return [];

      final data = jsonDecode(response.body);
      final List songs = data['songs'] as List? ?? [];
      return _mapSongs(songs);
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

  // ── /users/me ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final res = await _client.get(Uri.parse('$_base/users/me'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  Future<List<String>> getLikedSongs() async {
    try {
      final res = await _client.get(Uri.parse('$_base/users/me/liked-songs'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      return List<String>.from(jsonDecode(res.body));
    } catch (_) { return []; }
  }

  Future<bool> isSongLiked(String songId) async {
    try {
      final res = await _client.get(Uri.parse('$_base/users/me/liked-songs/$songId'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      return (jsonDecode(res.body) as Map<String, dynamic>)['liked'] == true;
    } catch (_) { return false; }
  }

  Future<bool> likeSong(String songId) async {
    try {
      final res = await _client.post(Uri.parse('$_base/users/me/liked-songs/$songId'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) { return false; }
  }

  Future<bool> unlikeSong(String songId) async {
    try {
      final res = await _client.delete(Uri.parse('$_base/users/me/liked-songs/$songId'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) { return false; }
  }

  Future<List<String>> getDownloadedSongIds() async {
    try {
      final res = await _client.get(Uri.parse('$_base/users/me/downloads'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      return List<String>.from(jsonDecode(res.body));
    } catch (_) { return []; }
  }

  Future<bool> markDownloaded(String songId) async {
    try {
      final res = await _client.post(Uri.parse('$_base/users/me/downloads/$songId'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) { return false; }
  }

  Future<bool> removeDownload(String songId) async {
    try {
      final res = await _client.delete(Uri.parse('$_base/users/me/downloads/$songId'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) { return false; }
  }

  // ── Songs ──────────────────────────────────────────────────────────────────

  List<Song> _mapSongs(List songs) => songs.map((s) => Song(
    id: (s['youtubeId'] ?? s['videoId']) as String,
    serverId: s['id'] as String? ?? '',
    title: s['title'] as String,
    artist: s['artistName'] as String? ?? '',
    album: s['album'] as String? ?? '',
    imageUrl: s['thumbnailUrl'] as String? ?? '',
    audioUrl: '',
    duration: Duration(seconds: (s['duration'] as num?)?.toInt() ?? 0),
    genres: List<String>.from(s['genres'] ?? s['tags'] ?? []),
    streamUrl: s['streamUrl'] as String?,
    streamUrlExpiresAt: s['streamUrlExpiresAt'] != null
        ? DateTime.tryParse(s['streamUrlExpiresAt'] as String)
        : null,
  )).toList();
}
