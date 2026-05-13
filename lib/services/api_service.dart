import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  factory ApiException.fromResponse(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return ApiException(res.statusCode, body['message']?.toString() ?? 'Unknown error');
    } catch (_) {
      return ApiException(res.statusCode, res.body);
    }
  }
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static const String baseUrl = 'https://music-app-server-lupbg4y2ha-uc.a.run.app';
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<String?> _getToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {bool requiresAuth = true, Duration timeout = const Duration(seconds: 15)}) async {
    final res = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(requiresAuth: requiresAuth),
    ).timeout(timeout);
    if (res.statusCode >= 400) throw ApiException.fromResponse(res);
    return jsonDecode(res.body);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool requiresAuth = true, Duration timeout = const Duration(seconds: 15)}) async {
    final res = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(requiresAuth: requiresAuth),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(timeout);
    if (res.statusCode >= 400) throw ApiException.fromResponse(res);
    return res.statusCode == 204 ? null : jsonDecode(res.body);
  }

  Future<void> delete(String path, {bool requiresAuth = true, Duration timeout = const Duration(seconds: 15)}) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(requiresAuth: requiresAuth),
    ).timeout(timeout);
    if (res.statusCode >= 400) throw ApiException.fromResponse(res);
  }
}
