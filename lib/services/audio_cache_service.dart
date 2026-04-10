import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Service to handle caching of audio files downloaded from YouTube.
class AudioCacheService {
  static const _cacheFolder = 'audio_cache';
  static const int maxCacheSizeBytes = 500 * 1024 * 1024; // 500MB

  /// Returns the directory where audio files are cached.
  Future<Directory> getCacheDir() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/$_cacheFolder');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Returns the file path for a given YouTube video ID.
  Future<File> getCachedFile(String videoId) async {
    final dir = await getCacheDir();
    return File('${dir.path}/$videoId.m4a');
  }

  /// Checks if the audio file for the given video ID is cached.
  Future<bool> isCached(String videoId) async {
    final file = await getCachedFile(videoId);
    final exists = await file.exists();
    if (exists) {
      print('[AudioCacheService] Song $videoId is cached at: ${file.path}');
    } else {
      print('[AudioCacheService] Song $videoId is not cached.');
    }
    return exists;
  }

  /// Returns a local file path to the cached audio if available, otherwise returns null.
  Future<String?> getCachedAudioPath(String videoId) async {
    final file = await getCachedFile(videoId);
    if (await file.exists()) {
      print('[AudioCacheService] Song $videoId is cached at: \\${file.path}');
      return file.path;
    } else {
      print('[AudioCacheService] Song $videoId is not cached.');
      return null;
    }
  }

  /// Downloads and caches the audio stream for the given video ID.
  /// Returns the local file path.
  Future<String> downloadAndCacheAudio(String videoId, YoutubeExplode yt) async {
    final file = await getCachedFile(videoId);
    if (await file.exists()) {
      print('[AudioCacheService] Song $videoId is already cached at: ${file.path}');
      return file.path;
    }
    print('[AudioCacheService] Downloading and caching song $videoId...');
    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    final streamInfo = manifest.audioOnly.withHighestBitrate();
    final stream = yt.videos.streamsClient.get(streamInfo);
    final output = file.openWrite();
    await stream.pipe(output);
    await output.close();
    print('[AudioCacheService] Song $videoId cached at: ${file.path}');
    await _enforceCacheLimit();
    return file.path;
  }

  /// Enforces the cache size limit by deleting least recently used files.
  Future<void> _enforceCacheLimit() async {
    final dir = await getCacheDir();
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) => a.statSync().accessed.compareTo(b.statSync().accessed));
    int totalSize = files.fold(0, (sum, f) => sum + f.lengthSync());
    while (totalSize > maxCacheSizeBytes && files.isNotEmpty) {
      final file = files.removeAt(0);
      totalSize -= file.lengthSync();
      await file.delete();
    }
  }

  /// Removes a cached file for a given video ID.
  Future<void> removeCachedFile(String videoId) async {
    final file = await getCachedFile(videoId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clears the entire audio cache.
  Future<void> clearCache() async {
    final dir = await getCacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
