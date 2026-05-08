import 'package:http/http.dart' as http;

/// An http.Client that injects auth headers into every request.
class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> headers;

  AuthHttpClient(this.headers) : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    headers.forEach((k, v) => request.headers[k] = v);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
