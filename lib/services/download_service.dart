import "package:music_app/utils/logger.dart";
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';

class DownloadService {
  static const _metaKey = 'downloaded_songs';
  static const _serverBase = 'https://music-app-server-950104611859.us-central1.run.app';

  Future<String?> getDownloadedPath(Song song) async {
    final file = await _localFile(song);
    return (await file.exists()) ? file.path : null;
  }

  Future<String?> getDownloadedPathById(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null) return null;
    final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
    final entry = list.cast<Map<String, dynamic>?>().firstWhere(
      (e) => e!['id'] == videoId, orElse: () => null);
    if (entry == null) return null;
    final path = entry['audioUrl'] as String?;
    if (path == null || !await File(path).exists()) return null;
    return path;
  }

  /// Downloads audio for [song] via the server proxy (yt-dlp android client).
  /// Falls back to nothing on failure — the server resolves the stream URL
  /// server-side so the Android IP restriction doesn't apply.
  Future<String?> downloadSong(Song song, {void Function(int, int)? onProgress}) async {
    try {
      final file = await _localFile(song);
      if (await file.exists()) return file.path;

      final uri = Uri.parse('$_serverBase/songs/${song.id}/audio-stream');
      final request = http.Request('GET', uri);

      // Use an HTTP client with a long timeout — yt-dlp resolution + download
      // can take 30–60 s for longer tracks.
      final client = http.Client();
      try {
        final streamedResponse = await client.send(request).timeout(
          const Duration(minutes: 5),
        );

        if (streamedResponse.statusCode != 200 &&
            streamedResponse.statusCode != 206) {
          rlog('[DownloadService] server returned ${streamedResponse.statusCode} for ${song.id}');
          return null;
        }

        final contentLength = streamedResponse.contentLength;
        int received = 0;

        final output = file.openWrite();
        await for (final chunk in streamedResponse.stream) {
          output.add(chunk);
          received += chunk.length;
          if (contentLength != null && contentLength > 0) {
            onProgress?.call(received, contentLength);
          }
        }
        await output.close();
      } finally {
        client.close();
      }

      await _saveMeta(song, file.path);
      return file.path;
    } catch (e) {
      rlog('[DownloadService] downloadSong error for ${song.id}: $e');
      return null;
    }
  }

  Future<void> deleteDownload(Song song) async {
    final file = await _localFile(song);
    if (await file.exists()) await file.delete();
    await _removeMeta(song.id);
  }

  Future<List<Song>> getDownloadedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Song.fromJson(e)).toList();
  }

  Future<void> _saveMeta(Song song, String localPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    final list = raw != null ? List<Map<String, dynamic>>.from(jsonDecode(raw)) : <Map<String, dynamic>>[];
    list.removeWhere((e) => e['id'] == song.id);
    
    // Create a JSON-serializable map from the Song object
    final songJson = song.toJson();
    songJson['audioUrl'] = localPath;
    
    list.insert(0, songJson);
    await prefs.setString(_metaKey, jsonEncode(list));
  }

  Future<void> _removeMeta(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null) return;
    final list = List<Map<String, dynamic>>.from(jsonDecode(raw))
      ..removeWhere((e) => e['id'] == songId);
    await prefs.setString(_metaKey, jsonEncode(list));
  }

  Future<File> _localFile(Song song) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeId = song.id.replaceAll(RegExp(r'[^\w]'), '_');
    final file = File('${dir.path}/downloads/$safeId.mp4');
    await file.parent.create(recursive: true);
    return file;
  }
}
