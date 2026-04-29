import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists YouTube stream URLs locally with expiry.
/// Survives app restarts — no network call needed on cache hit.
class StreamUrlCache {
  static const _key = 'stream_url_cache';

  Future<Map<String, dynamic>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> _save(Map<String, dynamic> cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(cache));
  }

  /// Returns cached stream URL if it exists and hasn't expired.
  Future<String?> get(String videoId) async {
    final cache = await _load();
    final entry = cache[videoId] as Map<String, dynamic>?;
    if (entry == null) return null;
    final expiresAt = DateTime.tryParse(entry['expiresAt'] as String? ?? '');
    if (expiresAt == null || expiresAt.isBefore(DateTime.now().toUtc())) {
      // Expired — remove it
      cache.remove(videoId);
      await _save(cache);
      return null;
    }
    return entry['url'] as String?;
  }

  /// Saves a stream URL with its expiry.
  Future<void> put(String videoId, String url, DateTime expiresAt) async {
    final cache = await _load();
    cache[videoId] = {'url': url, 'expiresAt': expiresAt.toUtc().toIso8601String()};
    // Evict expired entries to keep cache small
    cache.removeWhere((_, v) {
      final exp = DateTime.tryParse((v as Map)['expiresAt'] as String? ?? '');
      return exp == null || exp.isBefore(DateTime.now().toUtc());
    });
    await _save(cache);
  }
}
