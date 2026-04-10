import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/music_models.dart';

class DownloadService {
  final Dio _dio = Dio();

  /// Returns the local path if already downloaded, null otherwise.
  Future<String?> getDownloadedPath(Song song) async {
    final file = await _localFile(song);
    return (await file.exists()) ? file.path : null;
  }

  /// Download song audio to local storage. Returns local file path on success.
  Future<String?> downloadSong(
    Song song, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (song.audioUrl.isEmpty) return null;
    try {
      final file = await _localFile(song);
      if (await file.exists()) return file.path;

      print('[Download] starting: ${song.title}');
      await _dio.download(
        song.audioUrl,
        file.path,
        onReceiveProgress: onProgress,
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://www.youtube.com/',
        }),
      );
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
  }

  Future<File> _localFile(Song song) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeId = song.id.replaceAll(RegExp(r'[^\w]'), '_');
    return File('${dir.path}/downloads/$safeId.mp4')
      ..parent.create(recursive: true);
  }
}
