import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';

/// Single source of truth for play history and state persistence.
class PlayHistoryService {
  static const _historyKey = 'play_history';
  static const _songsKey = 'known_songs';
  static const _queueKey = 'saved_queue';
  static const _queueIndexKey = 'saved_queue_index';
  static const _searchHistoryKey = 'search_history';
  static const _vibeStateKey = 'saved_vibe_state';
  static const _vibeQueueKey = 'saved_vibe_queue';
  static const _vibeQueueIndexKey = 'saved_vibe_queue_index';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Map<String, dynamic> _songToMap(Song song) => {
    'id': song.id, 'serverId': song.serverId, 'title': song.title, 'artist': song.artist,
    'album': song.album, 'imageUrl': song.imageUrl,
    'audioUrl': '', 'duration': song.duration.inSeconds,
  };

  Future<Map<String, Map<String, dynamic>>> _loadHistory() async {
    final raw = (await _prefs).getString(_historyKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
  }

  Future<void> _saveHistory(Map<String, Map<String, dynamic>> data) async {
    await (await _prefs).setString(_historyKey, jsonEncode(data));
  }

  Future<void> _saveSongMetadata(Song song) async {
    final p = await _prefs;
    final raw = p.getString(_songsKey);
    final songs = raw != null ? Map<String, dynamic>.from(jsonDecode(raw)) : <String, dynamic>{};
    songs[song.id] = _songToMap(song);
    await p.setString(_songsKey, jsonEncode(songs));
  }

  Future<void> recordPlay(Song song, int listenedSeconds) async {
    final data = await _loadHistory();
    final entry = data[song.id] ?? {'playCount': 0, 'likedCount': 0};
    entry['playCount'] = (entry['playCount'] as int? ?? 0) + 1;
    entry['lastPlayedAt'] = DateTime.now().millisecondsSinceEpoch;
    entry['lastPosition'] = listenedSeconds;

    final durationSeconds = song.duration.inSeconds;
    final isLiked = durationSeconds >= 360
        ? listenedSeconds >= 180
        : listenedSeconds >= durationSeconds * 0.5;
    if (isLiked) {
      entry['likedCount'] = (entry['likedCount'] as int? ?? 0) + 1;
    } else if (listenedSeconds > 5) {
      entry['unlikedCount'] = (entry['unlikedCount'] as int? ?? 0) + 1;
    }

    data[song.id] = entry;
    await _saveHistory(data);
    await _saveSongMetadata(song);
  }

  Future<void> savePosition(Song song, int positionSeconds) async {
    final data = await _loadHistory();
    final entry = data[song.id] ?? {'playCount': 0, 'likedCount': 0};
    entry['lastPlayedAt'] = DateTime.now().millisecondsSinceEpoch;
    entry['lastPosition'] = positionSeconds;
    data[song.id] = entry;
    await _saveHistory(data);
    await _saveSongMetadata(song);
  }

  Future<int> getLastPosition(String songId) async {
    final data = await _loadHistory();
    return (data[songId]?['lastPosition'] as int?) ?? 0;
  }

  Future<bool> isLiked(String songId) async {
    final data = await _loadHistory();
    return (data[songId]?['manualLike'] as bool?) ?? false;
  }

  Future<void> toggleLike(Song song) async {
    final data = await _loadHistory();
    final entry = data[song.id] ?? {'playCount': 0, 'likedCount': 0};
    final current = (entry['manualLike'] as bool?) ?? false;
    entry['manualLike'] = !current;
    if (!current) {
      entry['likedCount'] = (entry['likedCount'] as int? ?? 0) + 1;
    }
    data[song.id] = entry;
    await _saveHistory(data);
    await _saveSongMetadata(song);
  }

  Future<List<Song>> getRecentSongs({int limit = 10}) async {
    final p = await _prefs;
    final songsRaw = p.getString(_songsKey);
    if (songsRaw == null) return [];
    final songsMap = Map<String, dynamic>.from(jsonDecode(songsRaw));
    final data = await _loadHistory();

    return (songsMap.entries
        .where((e) => data.containsKey(e.key))
        .map((e) => (song: Song.fromJson(e.value), lastPlayedAt: data[e.key]!['lastPlayedAt'] as int? ?? 0))
        .toList()
          ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt)))
        .take(limit)
        .map((e) => e.song)
        .toList();
  }

  /// Return the most liked songs from history (sorted by likedCount desc, then playCount desc).
  /// Only songs that have at least one like are returned.
  Future<List<Song>> getMostLikedSongs({int limit = 20}) async {
    final p = await _prefs;
    final songsRaw = p.getString(_songsKey);
    if (songsRaw == null) return [];
    final songsMap = Map<String, dynamic>.from(jsonDecode(songsRaw));
    final data = await _loadHistory();

    final stats = <({Song song, int likedCount, int playCount})>[];
    for (final e in songsMap.entries) {
      final id = e.key;
      final entry = data[id];
      if (entry == null) continue;
      final song = Song.fromJson(e.value);
      final liked = (entry['likedCount'] as int?) ?? ((entry['manualLike'] as bool?) == true ? 1 : 0);
      final play = (entry['playCount'] as int?) ?? 0;
      stats.add((song: song, likedCount: liked, playCount: play));
    }

    stats.sort((a, b) {
      final byLiked = b.likedCount.compareTo(a.likedCount);
      if (byLiked != 0) return byLiked;
      return b.playCount.compareTo(a.playCount);
    });

    return stats.where((s) => s.likedCount > 0).map((s) => s.song).take(limit).toList();
  }

  /// Given a list of known songs, return a list of records with their liked and play counts
  /// using the stored history. The returned list is sorted by likedCount desc then playCount desc.
  Future<List<({Song song, int likedCount, int playCount})>> getMostLiked(List<Song> knownSongs) async {
    final data = await _loadHistory();
    final stats = knownSongs.map((song) {
      final entry = data[song.id];
      final liked = (entry?['likedCount'] as int?) ?? ((entry?['manualLike'] as bool?) == true ? 1 : 0);
      final play = (entry?['playCount'] as int?) ?? 0;
      return (song: song, likedCount: liked, playCount: play);
    }).toList();

    stats.sort((a, b) {
      final byLiked = b.likedCount.compareTo(a.likedCount);
      if (byLiked != 0) return byLiked;
      return b.playCount.compareTo(a.playCount);
    });

    return stats;
  }

  Future<void> cacheTrending(List<Song> songs) async {
    final p = await _prefs;
    await p.setString(_trendingCacheKey, jsonEncode(songs.map(_songToMap).toList()));
  }

  Future<List<Song>> loadCachedTrending() async {
    final p = await _prefs;
    final raw = p.getString(_trendingCacheKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Song.fromJson(e)).toList();
  }

  Future<void> cacheSuggested(List<Song> songs) async {
    final p = await _prefs;
    await p.setString(_suggestedCacheKey, jsonEncode(songs.map(_songToMap).toList()));
  }

  Future<List<Song>> loadCachedSuggested() async {
    final p = await _prefs;
    final raw = p.getString(_suggestedCacheKey);
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Song.fromJson(e)).toList();
      }
    }
    return [];
  }

  Future<void> savePlaylist(String name, List<Song> songs) async {
    if (songs.isEmpty) return;
    final p = await _prefs;
    final raw = p.getString(_playlistsKey);
    final playlists = raw != null
        ? List<Map<String, dynamic>>.from(jsonDecode(raw))
        : <Map<String, dynamic>>[];

    playlists.removeWhere((pl) => pl['name'] == name);
    playlists.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'imageUrl': songs.first.imageUrl,
      'songs': songs.map(_songToMap).toList(),
    });

    await p.setString(_playlistsKey, jsonEncode(playlists.take(50).toList()));
  }

  Future<List<Playlist>> loadPlaylists() async {
    final p = await _prefs;
    final raw = p.getString(_playlistsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((pl) => Playlist(
      id: pl['id'],
      name: pl['name'],
      imageUrl: pl['imageUrl'] ?? '',
      songs: (pl['songs'] as List).map((s) => Song.fromJson(s)).toList(),
    )).toList();
  }

  Future<void> updatePlaylistSong(String serverId, String newId, String newAudioUrl) async {
    final p = await _prefs;
    final raw = p.getString(_playlistsKey);
    if (raw == null) return;
    final playlists = List<Map<String, dynamic>>.from(jsonDecode(raw));
    bool changed = false;
    for (final pl in playlists) {
      final songs = pl['songs'] as List;
      for (final s in songs) {
        if (s is Map<String, dynamic> && s['serverId'] == serverId) {
          s['id'] = newId;
          s['audioUrl'] = newAudioUrl;
          changed = true;
        }
      }
    }
    if (changed) {
      await p.setString(_playlistsKey, jsonEncode(playlists));
    }
  }

  Future<void> deletePlaylist(String id) async {
    final p = await _prefs;
    final raw = p.getString(_playlistsKey);
    if (raw == null) return;
    final playlists = List<Map<String, dynamic>>.from(jsonDecode(raw));
    playlists.removeWhere((pl) => pl['id'] == id);
    await p.setString(_playlistsKey, jsonEncode(playlists));
  }

  Future<void> saveQueue(List<Song> queue, int currentIndex) async {
    final p = await _prefs;
    await p.setString(_queueKey, jsonEncode(queue.map(_songToMap).toList()));
    await p.setInt(_queueIndexKey, currentIndex);
  }

  Future<({List<Song> queue, int currentIndex})?> loadQueue() async {
    final p = await _prefs;
    final raw = p.getString(_queueKey);
    if (raw == null) return null;
    final index = p.getInt(_queueIndexKey) ?? 0;
    final list = (jsonDecode(raw) as List).map((e) => Song.fromJson(e)).toList();
    if (list.isEmpty) return null;
    return (queue: list, currentIndex: index.clamp(0, list.length - 1));
  }

  Future<void> saveVibeQueue(List<Song> queue, int currentIndex) async {
    final p = await _prefs;
    await p.setString(_vibeQueueKey, jsonEncode(queue.map(_songToMap).toList()));
    await p.setInt(_vibeQueueIndexKey, currentIndex);
  }

  Future<({List<Song> queue, int currentIndex})?> loadVibeQueue() async {
    final p = await _prefs;
    final raw = p.getString(_vibeQueueKey);
    if (raw == null) return null;
    final index = p.getInt(_vibeQueueIndexKey) ?? 0;
    final list = (jsonDecode(raw) as List).map((e) => Song.fromJson(e)).toList();
    if (list.isEmpty) return null;
    return (queue: list, currentIndex: index.clamp(0, list.length - 1));
  }

  Future<void> saveSearch(String query) async {
    if (query.trim().isEmpty) return;
    final p = await _prefs;
    final raw = p.getString(_searchHistoryKey);
    final searches = raw != null ? List<String>.from(jsonDecode(raw)) : <String>[];
    searches.remove(query); 
    searches.insert(0, query);
    await p.setString(_searchHistoryKey, jsonEncode(searches.take(50).toList()));
  }

  Future<void> deleteSearch(String query) async {
    final p = await _prefs;
    final raw = p.getString(_searchHistoryKey);
    if (raw == null) return;
    final searches = List<String>.from(jsonDecode(raw));
    searches.remove(query);
    await p.setString(_searchHistoryKey, jsonEncode(searches));
  }

  Future<List<String>> getSearchHistory() async {
    final p = await _prefs;
    final raw = p.getString(_searchHistoryKey);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw));
  }

  Future<void> saveVibeState(String vibeId, String? subCategoryId) async {
    final p = await _prefs;
    await p.setString(_vibeStateKey, jsonEncode({
      'vibeId': vibeId,
      'subCategoryId': subCategoryId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  Future<({String vibeId, String? subCategoryId})?> loadVibeState() async {
    final p = await _prefs;
    final raw = p.getString(_vibeStateKey);
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return (
      vibeId: data['vibeId'] as String,
      subCategoryId: data['subCategoryId'] as String?,
    );
  }

  Future<void> clearVibeState() async {
    final p = await _prefs;
    await p.remove(_vibeStateKey);
    await p.remove(_vibeQueueKey);
    await p.remove(_vibeQueueIndexKey);
  }

  static const _playlistsKey = 'saved_playlists';
  static const _trendingCacheKey = 'cached_trending';
  static const _suggestedCacheKey = 'cached_suggested';
}
