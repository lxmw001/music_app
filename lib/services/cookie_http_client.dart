import 'package:http/http.dart' as http;

/// An http.Client that injects a Cookie header into every request.
class CookieHttpClient extends http.BaseClient {
  final http.Client _inner;
  final String cookieHeader;

  CookieHttpClient(this.cookieHeader) : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Cookie'] = cookieHeader;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
