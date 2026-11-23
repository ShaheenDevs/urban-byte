import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:urban_byte/app/app.locator.dart';
import 'auth_service.dart';

class StaffService {
  final AuthService _authService = locator<AuthService>();
  String get _baseUrl => const String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://localhost:3000/api/v1');
  Future<Map<String, String>> get _headers async {
    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    };
  }

  Future<List<Map<String, dynamic>>> getStaff(
      {String search = '', bool? active}) async {
    final query = <String, String>{
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (active != null) 'active': active.toString()
    };
    final uri = Uri.parse('$_baseUrl/staff').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load staff (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    final rows = data is Map ? data['data'] ?? data['items'] : data;
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    final response = await http.get(Uri.parse('$_baseUrl/staff/roles'),
        headers: await _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load roles.');
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> updateStaff({
    required String id,
    required String name,
    required String contact,
    required List<int> roleIds,
    required bool isActive,
    String? password,
  }) async {
    final email = contact.contains('@') ? contact.trim().toLowerCase() : null;
    final phone = email == null ? contact.trim() : null;
    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email,
      'phone': phone,
      'roleIds': roleIds,
      'isActive': isActive,
      if (password != null && password.isNotEmpty) 'password': password,
    };
    final response = await http.patch(
      Uri.parse('$_baseUrl/staff/$id'),
      headers: await _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body);
      final message = decoded is Map ? decoded['message'] : null;
      throw Exception(message ?? 'Unable to update staff (${response.statusCode}).');
    }
  }

  Future<void> createStaff(
      {required String name,
      required String contact,
      required String password,
      required List<int> roleIds}) async {
    final email = contact.contains('@') ? contact.trim().toLowerCase() : null;
    final phone = email == null ? contact.trim() : null;
    final response = await http.post(Uri.parse('$_baseUrl/staff'),
        headers: await _headers,
        body: jsonEncode({
          'name': name.trim(),
          'email': email,
          'phone': phone,
          'password': password,
          'roleIds': roleIds
        }));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Unable to create staff (${response.statusCode}): ${response.body}');
    }
  }
}
