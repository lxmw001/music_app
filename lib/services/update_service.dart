import 'dart:convert';
import 'package:http/http.dart' as http;

class UpdateService {
  static const _repo = 'lxmw001/music_app';
  static const _currentVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '');

  /// Returns the download URL if a newer release exists, null otherwise.
  Future<String?> checkForUpdate() async {
    // Skip if version wasn't injected at build time (dev/debug builds)
    if (_currentVersion.isEmpty) return null;
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      );
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      final latestTag =
          (data['tag_name'] as String).replaceFirst('v', '');
      final assets = data['assets'] as List;
      if (assets.isEmpty) return null;

      if (_isNewer(latestTag, _currentVersion)) {
        return assets.first['browser_download_url'] as String;
      }
    } catch (_) {}
    return null;
  }

  bool _isNewer(String latest, String current) {
    return _buildNumber(latest) > _buildNumber(current);
  }

  int _buildNumber(String version) {
    if (!version.contains('+')) return 0;
    return int.tryParse(version.split('+').last) ?? 0;
  }
}
