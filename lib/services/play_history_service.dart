import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';

class PlayHistoryService {
  static const _key = 'play_history';

  // songId -> {playCount, likedCount}
  Future<Map<String, Map<String, int>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, Map<String, int>.from(v)));
  }

  Future<void> _save(Map<String, Map<String, int>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  /// Call when a song finishes or is skipped. [listenedPercent] 0.0–1.0
  Future<void> recordPlay(Song song, double listenedPercent) async {
    final data = await _load();
    final entry = data[song.id] ?? {'playCount': 0, 'likedCount': 0};
    entry['playCount'] = (entry['playCount'] ?? 0) + 1;
    if (listenedPercent >= 0.5) {
      entry['likedCount'] = (entry['likedCount'] ?? 0) + 1;
    }
    data[song.id] = entry;
    await _save(data);
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
