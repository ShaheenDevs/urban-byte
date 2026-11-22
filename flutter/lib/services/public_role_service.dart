import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class PublicRoleService {
  PublicRoleService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<Map<String, dynamic>>> fetchRoles() async {
    final response = await _client.get(Uri.parse('$apiBaseUrl/auth/roles'));
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Unable to read roles response from server.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw Exception(
          payload['message']?.toString() ?? 'Unable to load roles.');
    }
    final data = payload['data'];
    if (data is! List) throw Exception('Invalid roles response.');
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
