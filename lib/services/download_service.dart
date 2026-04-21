import 'dart:convert';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/music_models.dart';

class DownloadService {
  static const _metaKey = 'downloaded_songs';

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

  Future<String?> downloadSong(Song song, {void Function(int, int)? onProgress}) async {
    try {
      final file = await _localFile(song);
      if (await file.exists()) return file.path;

      final yt = YoutubeExplode();
      try {
        print('[Download] fetching stream manifest for ${song.id}');
        final manifest = await yt.videos.streamsClient.getManifest(
          song.id,
          ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
        );
        final streamInfo = manifest.audioOnly.withHighestBitrate();
        final totalSize = streamInfo.size.totalBytes;
        int received = 0;

        final stream = yt.videos.streamsClient.get(streamInfo);
        final output = file.openWrite();
        await for (final chunk in stream) {
          output.add(chunk);
          received += chunk.length;
          onProgress?.call(received, totalSize);
        }
        await output.close();
      } finally {
        yt.close();
      }

      await _saveMeta(song, file.path);
      print('[Download] complete: ${file.path}');
      return file.path;
    } catch (e) {
      print('[Download] error: $e');
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
    list.insert(0, {
      'id': song.id, 'title': song.title, 'artist': song.artist,
      'album': song.album, 'imageUrl': song.imageUrl,
      'audioUrl': localPath, 'duration': song.duration.inSeconds,
      'genres': song.genres,
    });
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
