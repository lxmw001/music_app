import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';

class ErrorReportingService {
  static final ErrorReportingService _instance = ErrorReportingService._();
  static ErrorReportingService get instance => _instance;
  ErrorReportingService._();

  final ApiService _api = ApiService();
  String? _deviceInfo;
  String? _appVersion;

  Future<void> report({
    required String error,
    String? stackTrace,
    String? file,
    String? line,
    String? screen,
    String? action,
    String? endpoint,
    int? statusCode,
    String? songId,
    String? youtubeId,
    String? requestBody,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      _deviceInfo ??= await _getDeviceInfo();
      _appVersion ??= await _getAppVersion();
      await _api.post('/users/me/error-report', body: {
        'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (file != null) 'file': file,
        if (line != null) 'line': line,
        if (screen != null) 'screen': screen,
        if (action != null) 'action': action,
        if (endpoint != null) 'endpoint': endpoint,
        if (statusCode != null) 'statusCode': statusCode,
        if (songId != null) 'songId': songId,
        if (youtubeId != null) 'youtubeId': youtubeId,
        if (requestBody != null) 'requestBody': requestBody,
        'deviceInfo': _deviceInfo,
        'appVersion': _appVersion,
      });
    } catch (_) {}
  }

  Future<String> _getDeviceInfo() async {
    try {
      final info = await DeviceInfoPlugin().deviceInfo;
      final data = info.data;
      if (data.containsKey('model') && data.containsKey('version')) {
        final version = data['version'] as Map?;
        return '${data['model']}, Android ${version?['release'] ?? ''}';
      }
      return '${data['model'] ?? 'Unknown'}';
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }
}
