import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ??
            const String.fromEnvironment('API_BASE_URL',
                defaultValue: 'http://127.0.0.1:8090'),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? accessToken;
  String? refreshToken;
  static String? _sharedAccessToken;
  static String? _sharedRefreshToken;
  static void Function()? onSessionExpired;
  Future<void>? _refreshInFlight;

  static void setSharedTokens({String? accessToken, String? refreshToken}) {
    _sharedAccessToken = accessToken;
    _sharedRefreshToken = refreshToken;
  }

  static void clearSharedTokens() {
    _sharedAccessToken = null;
    _sharedRefreshToken = null;
  }

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, String>? query}) async {
    final response = await _send(() => _client.get(_uri(path, query), headers: _headers()));
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(String path,
      [Map<String, dynamic> body = const {}]) async {
    final response = await _send(() => _client.post(_uri(path),
        headers: _headers(), body: jsonEncode(body)));
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final response = await _send(() => _client.delete(_uri(path), headers: _headers()));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Map<String, String> _headers() {
    final token = _sharedAccessToken ?? accessToken;
    return {
      'content-type': 'application/json',
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _send(Future<http.Response> Function() send) async {
    final response = await send();
    if (response.statusCode != 401 || (_sharedRefreshToken ?? refreshToken) == null) {
      return response;
    }
    final refreshed = await _refreshAccessToken();
    if (!refreshed) return response;
    return send();
  }

  Future<bool> _refreshAccessToken() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      await inFlight;
      return _sharedAccessToken != null || accessToken != null;
    }
    final refresh = _sharedRefreshToken ?? refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    final completer = Future<void>(() async {
      final response = await _client.post(
        _uri('/api/v1/auth/refresh'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        accessToken = null;
        refreshToken = null;
        clearSharedTokens();
        onSessionExpired?.call();
        return;
      }
      final data = jsonDecode(response.body) as Map;
      accessToken = data['accessToken']?.toString();
      refreshToken = data['refreshToken']?.toString();
      setSharedTokens(accessToken: accessToken, refreshToken: refreshToken);
    });
    _refreshInFlight = completer;
    try {
      await completer;
      return (_sharedAccessToken ?? accessToken) != null;
    } finally {
      if (identical(_refreshInFlight, completer)) _refreshInFlight = null;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
          response.statusCode,
          decoded is Map
              ? decoded['error']?.toString() ?? response.body
              : response.body);
    }
    return Map<String, dynamic>.from(decoded as Map);
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ApiException($statusCode): $message';
}
