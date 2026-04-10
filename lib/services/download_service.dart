import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';

class DownloadService {
  static const _metaKey = 'downloaded_songs';
  final Dio _dio = Dio();

  Future<String?> getDownloadedPath(Song song) async {
    final file = await _localFile(song);
    return (await file.exists()) ? file.path : null;
  }

  Future<String?> downloadSong(Song song, {void Function(int, int)? onProgress}) async {
    if (song.audioUrl.isEmpty) return null;
    try {
      final file = await _localFile(song);
      if (await file.exists()) return file.path;

      print('[Download] starting: ${song.title}');
      await _dio.download(
        song.audioUrl, file.path,
        onReceiveProgress: onProgress,
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://www.youtube.com/',
        }),
      );
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
