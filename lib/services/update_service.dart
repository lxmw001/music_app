import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const _repo = 'lxmw001/music_app';
  static const _currentVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '');

  static const _channel = MethodChannel('com.lxmw.musicapp/install');

  /// Returns the download URL if a newer release exists, null otherwise.
  Future<String?> checkForUpdate() async {
    if (_currentVersion.isEmpty) return null;
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      );
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      final latestTag = (data['tag_name'] as String).replaceFirst('v', '');
      final assets = data['assets'] as List;
      if (assets.isEmpty) return null;

      if (_isNewer(latestTag, _currentVersion)) {
        return assets.first['browser_download_url'] as String;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads the APK and triggers the system installer.
  /// Calls [onProgress] with 0.0–1.0 during download.
  Future<void> downloadAndInstall(
    String url, {
    void Function(double)? onProgress,
  }) async {
    final dir = await getExternalStorageDirectory();
    final file = File('${dir!.path}/update.apk');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      final total = response.contentLength ?? 0;
      int received = 0;

      final sink = file.openWrite();
      await response.stream.map((chunk) {
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
        return chunk;
      }).pipe(sink);
      await sink.close();
    } finally {
      client.close();
    }

    await _channel.invokeMethod('installApk', {'path': file.path});
  }

  bool _isNewer(String latest, String current) {
    return _buildNumber(latest) > _buildNumber(current);
  }

  int _buildNumber(String version) {
    if (!version.contains('+')) return 0;
    return int.tryParse(version.split('+').last) ?? 0;
  }
}
