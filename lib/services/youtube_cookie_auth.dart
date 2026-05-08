import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages YouTube cookies extracted from an in-app WebView login session.
class YoutubeCookieAuth {
  static const _prefsKey = 'yt_cookies';
  static final _cookieManager = CookieManager.instance();

  /// Extracts relevant YouTube cookies from the WebView after login.
  static Future<Map<String, String>> extractCookies() async {
    final domains = ['youtube.com', '.youtube.com', 'www.youtube.com'];
    final needed = {'SID', 'HSID', 'SSID', 'APISID', 'SAPISID', '__Secure-3PSID'};
    final result = <String, String>{};

    for (final domain in domains) {
      final cookies = await _cookieManager.getCookies(url: WebUri('https://www.youtube.com'), iosBelow11WebViewController: null);
      for (final c in cookies) {
        if (needed.contains(c.name)) result[c.name] = c.value.toString();
      }
      if (result.length >= 3) break;
    }
    return result;
  }

  /// Persists cookies to SharedPreferences.
  static Future<void> saveCookies(Map<String, String> cookies) async {
    final prefs = await SharedPreferences.getInstance();
    final header = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    await prefs.setString(_prefsKey, header);
  }

  /// Loads the persisted cookie header string, or null if not set.
  static Future<String?> loadCookieHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefsKey);
    return (v != null && v.isNotEmpty) ? v : null;
  }

  /// Clears saved cookies.
  static Future<void> clearCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Returns true if cookies are saved.
  static Future<bool> hasCookies() async {
    return (await loadCookieHeader()) != null;
  }
}
