import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';

/// Single source of truth for play history.
/// Stores everything under two keys:
///   - `play_history`: songId → {playCount, likedCount, lastPlayedAt (ms), lastPosition}
///   - `known_songs`:  songId → song metadata
class PlayHistoryService {
  static const _historyKey = 'play_history';
  static const _songsKey = 'known_songs';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Map<String, dynamic> _songToMap(Song song) => {
    'id': song.id, 'title': song.title, 'artist': song.artist,
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
    if (isLiked) entry['likedCount'] = (entry['likedCount'] as int? ?? 0) + 1;

    data[song.id] = entry;
    await _saveHistory(data);
    await _saveSongMetadata(song);
  }

  /// Save current position without recording a full play event
  Future<void> savePosition(Song song, int positionSeconds) async {
    final data = await _loadHistory();
    final entry = data[song.id] ?? {'playCount': 0, 'likedCount': 0};
    entry['lastPlayedAt'] = DateTime.now().millisecondsSinceEpoch;
    entry['lastPosition'] = positionSeconds;
    data[song.id] = entry;
    await _saveHistory(data);
    await _saveSongMetadata(song);
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
      // Liking manually also counts as a like
      entry['likedCount'] = (entry['likedCount'] as int? ?? 0) + 1;
    }
    data[song.id] = entry;
    await _saveHistory(data);
    await _saveSongMetadata(song);
  }
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

  Future<({Song song, int lastPositionSeconds})?> loadLastSong() async {
    final recent = await getRecentSongs(limit: 1);
    if (recent.isEmpty) return null;
    final song = recent.first;
    final data = await _loadHistory();
    final pos = data[song.id]?['lastPosition'] as int? ?? 0;
    song.audioUrl = ''; // always fetch fresh URL
    return (song: song, lastPositionSeconds: pos);
  }

  Future<List<Song>> getMostLikedSongs() async {
    final p = await _prefs;
    final songsRaw = p.getString(_songsKey);
    if (songsRaw == null) return [];
    final songsMap = Map<String, dynamic>.from(jsonDecode(songsRaw));
    final data = await _loadHistory();
    print('[PlayHistoryService] history data: $data');
    final results = songsMap.entries
        .where((e) => (data[e.key]?['likedCount'] as int? ?? 0) > 0)
        .map((e) => (song: Song.fromJson(e.value), likedCount: data[e.key]!['likedCount'] as int))
        .toList()
      ..sort((a, b) => b.likedCount.compareTo(a.likedCount));
    print('[PlayHistoryService] liked songs: ${results.map((e) => "${e.song.title}(${e.likedCount})").toList()}');
    return results.map((e) => e.song).toList();
  }

  /// Legacy — kept for backward compat with provider
  Future<List<({Song song, int likedCount, int playCount})>> getMostLiked(List<Song> knownSongs) async {
    final data = await _loadHistory();
    return knownSongs
        .where((s) => (data[s.id]?['likedCount'] as int? ?? 0) > 0)
        .map((s) => (
              song: s,
              likedCount: data[s.id]!['likedCount'] as int,
              playCount: data[s.id]!['playCount'] as int? ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.likedCount.compareTo(a.likedCount));
  }
}
