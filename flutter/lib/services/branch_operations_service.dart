import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class BranchOperationsService {
  BranchOperationsService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> purchaseAnalytics({
    required String from,
    required String to,
    String? branchId,
  }) async {
    final query = <String, String>{
      'from': from,
      'to': to,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
    };
    return _get('/inventory/analytics/purchases', query);
  }

  Future<Map<String, dynamic>> auditHistory({
    String? branchId,
    String? action,
    String? entityType,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, String>{
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (action != null && action.isNotEmpty) 'action': action,
      if (entityType != null && entityType.isNotEmpty) 'entityType': entityType,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      'page': '$page',
      'limit': '$limit',
    };
    return _get('/audit', query);
  }

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> query) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw const BranchOperationsException('Please sign in again.');
    }
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const BranchOperationsException('Unable to read server response.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw BranchOperationsException(
          payload['message']?.toString() ?? 'Request failed.');
    }
    final data = payload['data'];
    if (data is! Map) {
      throw const BranchOperationsException('Invalid server response.');
    }
    return Map<String, dynamic>.from(data);
  }
}

class BranchOperationsException implements Exception {
  const BranchOperationsException(this.message);
  final String message;
  @override
  String toString() => message;
}
