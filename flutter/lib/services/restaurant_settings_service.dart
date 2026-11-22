import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class RestaurantSettingsService {
  RestaurantSettingsService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> _request(String method, [Map<String, dynamic>? body]) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) throw Exception('Please sign in again.');
    final uri = Uri.parse(apiBaseUrl + '/settings');
    final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.put(uri, headers: headers, body: jsonEncode(body));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300 || payload['success'] != true) {
      throw Exception(payload['message'] ?? 'Settings request failed.');
    }
    return Map<String, dynamic>.from(payload['data'] as Map);
  }

  Future<Map<String, dynamic>> load() => _request('GET');
  Future<Map<String, dynamic>> save(Map<String, dynamic> values) => _request('PUT', values);
}
