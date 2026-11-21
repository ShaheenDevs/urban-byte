import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';
import '../models/auth_session.dart';

class AuthService {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<AuthSession> login(
      {required String identifier, required String password}) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    final payload = _decode(response);
    final session =
        AuthSession.fromJson(payload['data'] as Map<String, dynamic>);
    if (session.accessToken.isEmpty || session.refreshToken.isEmpty) {
      throw const AuthException('The server returned an incomplete session.');
    }
    await _storage.write(key: 'access_token', value: session.accessToken);
    await _storage.write(key: 'refresh_token', value: session.refreshToken);
    await _storage.write(key: 'user_roles', value: jsonEncode(session.roles));
    await _storage.write(
        key: 'user_permissions', value: jsonEncode(session.permissions));
    return session;
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');

  Future<void> logout() async {
    final token = await _storage.read(key: 'refresh_token');
    if (token != null) {
      try {
        await _client.post(Uri.parse('$apiBaseUrl/auth/logout'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': token}));
      } finally {
        await _storage.deleteAll();
      }
    } else {
      await _storage.deleteAll();
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthException('Unable to read the server response.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw AuthException(
          payload['message'] as String? ?? 'Authentication failed.');
    }
    return payload;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
