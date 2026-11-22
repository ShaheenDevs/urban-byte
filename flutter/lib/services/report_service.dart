import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class ReportService {
  ReportService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> financial(
      {required String from, required String to, String? branchId}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty)
      throw Exception('Please sign in again.');
    final query = <String, String>{
      'from': from,
      'to': to,
      if (branchId != null) 'branchId': branchId
    };
    final uri = Uri.parse('$apiBaseUrl/reports/financial')
        .replace(queryParameters: query);
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw Exception(
          payload['message']?.toString() ?? 'Unable to load financial report.');
    }
    return Map<String, dynamic>.from(payload['data'] as Map);
  }

  Future<Map<String, dynamic>> analytics(
      {required String from, required String to, String? branchId}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty)
      throw Exception('Please sign in again.');
    final query = <String, String>{
      'from': from,
      'to': to,
      if (branchId != null) 'branchId': branchId
    };
    final uri = Uri.parse('$apiBaseUrl/reports/analytics')
        .replace(queryParameters: query);
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw Exception(
          payload['message']?.toString() ?? 'Unable to load analytics.');
    }
    return Map<String, dynamic>.from(payload['data'] as Map);
  }
}
