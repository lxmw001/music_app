import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';

class PlayHistoryService {
  static const _key = 'play_history';
  static const _lastSongKey = 'last_played_song';
  static const _songsKey = 'known_songs';
  static const _recentKey = 'recent_songs';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Map<String, dynamic> _songToMap(Song song) => {
    'id': song.id, 'title': song.title, 'artist': song.artist,
    'album': song.album, 'imageUrl': song.imageUrl,
    'audioUrl': '', 'duration': song.duration.inSeconds,
  };

  // songId -> {playCount, likedCount}
  Future<Map<String, Map<String, int>>> _load() async {
    final raw = (await _prefs).getString(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, Map<String, int>.from(v)));
  }

  Future<void> _save(Map<String, Map<String, int>> data) async {
    await (await _prefs).setString(_key, jsonEncode(data));
  }

  /// Call when a song finishes or is skipped. [listenedSeconds] how many seconds played.
  Future<void> recordPlay(Song song, int listenedSeconds) async {
    final data = await _load();
    final entry = data[song.id] ?? {'playCount': 0, 'likedCount': 0};
    entry['playCount'] = (entry['playCount'] ?? 0) + 1;
    final durationSeconds = song.duration.inSeconds;
    final isLiked = durationSeconds >= 360
        ? listenedSeconds >= 180
        : listenedSeconds >= durationSeconds * 0.5;
    if (isLiked) {
      entry['likedCount'] = (entry['likedCount'] ?? 0) + 1;
    }
    data[song.id] = entry;
    await _save(data);
    await _saveSongMetadata(song);
    await _saveRecentSong(song);
    await saveLastSong(song);
  }

  Future<void> _saveRecentSong(Song song) async {
    final p = await _prefs;
    final raw = p.getString(_recentKey);
    final list = raw != null ? List<dynamic>.from(jsonDecode(raw)) : [];
    list.removeWhere((e) => e['id'] == song.id); // avoid duplicates
    list.insert(0, _songToMap(song));
    if (list.length > 10) list.removeLast();
    await p.setString(_recentKey, jsonEncode(list));
  }

  Future<List<Song>> getRecentSongs() async {
    final raw = (await _prefs).getString(_recentKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Song.fromJson(e)).toList();
  }

  Future<void> _saveSongMetadata(Song song) async {
    final p = await _prefs;
    final raw = p.getString(_songsKey);
    final songs = raw != null ? Map<String, dynamic>.from(jsonDecode(raw)) : <String, dynamic>{};
    songs[song.id] = _songToMap(song);
    await p.setString(_songsKey, jsonEncode(songs));
  }

  Future<List<Song>> getMostLikedSongs() async {
    final p = await _prefs;
    final songsRaw = p.getString(_songsKey);
    if (songsRaw == null) {
      print('[PlayHistoryService] no songs metadata saved yet');
      return [];
    }
    final songsMap = Map<String, dynamic>.from(jsonDecode(songsRaw));
    final data = await _load();
    print('[PlayHistoryService] history data: $data');
    final results = songsMap.entries
        .where((e) => (data[e.key]?['likedCount'] ?? 0) > 0)
        .map((e) => (song: Song.fromJson(e.value), likedCount: data[e.key]!['likedCount'] as int))
        .toList()
      ..sort((a, b) => b.likedCount.compareTo(a.likedCount));
    print('[PlayHistoryService] liked songs: ${results.map((e) => "${e.song.title}(${e.likedCount})").toList()}');
    return results.map((e) => e.song).toList();
  }

  Future<void> saveLastSong(Song song, {int lastPositionSeconds = 0}) async {
    await (await _prefs).setString(_lastSongKey, jsonEncode({
      ..._songToMap(song),
      'audioUrl': song.audioUrl,
      'lastPosition': lastPositionSeconds,
    }));
  }

  Future<({Song song, int lastPositionSeconds})?> loadLastSong() async {
    final raw = (await _prefs).getString(_lastSongKey);
    if (raw == null) return null;
    final map = jsonDecode(raw);
    return (song: Song.fromJson(map), lastPositionSeconds: (map['lastPosition'] as int?) ?? 0);
  }

  /// Returns songs sorted by likedCount descending
  Future<List<({Song song, int likedCount, int playCount})>> getMostLiked(
      List<Song> knownSongs) async {
    final data = await _load();
    final results = knownSongs
        .where((s) => data.containsKey(s.id))
        .map((s) => (
              song: s,
              likedCount: data[s.id]!['likedCount'] ?? 0,
              playCount: data[s.id]!['playCount'] ?? 0,
            ))
        .where((e) => e.likedCount > 0)
        .toList()
      ..sort((a, b) => b.likedCount.compareTo(a.likedCount));
    return results;
  }
}
