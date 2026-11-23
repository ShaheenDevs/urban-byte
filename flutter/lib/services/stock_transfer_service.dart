import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class StockTransferService {
  StockTransferService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? query}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw const StockTransferException('Please sign in again.');
    }
    final uri = Uri.parse('$apiBaseUrl$path');
    final target = query == null ? uri : uri.replace(queryParameters: query);
    final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
    final response = switch (method) {
      'GET' => await _client.get(target, headers: headers),
      'POST' => await _client.post(target, headers: headers, body: jsonEncode(body ?? {})),
      _ => throw const StockTransferException('Unsupported request method.'),
    };
    Map<String, dynamic> payload;
    try { payload = jsonDecode(response.body) as Map<String, dynamic>; }
    catch (_) { throw const StockTransferException('Unable to read server response.'); }
    if (response.statusCode < 200 || response.statusCode >= 300 || payload['success'] != true) {
      throw StockTransferException(payload['message']?.toString() ?? 'Stock transfer request failed.');
    }
    return payload['data'];
  }

  Future<List<Map<String, dynamic>>> list({String? branchId, String? status}) async {
    final data = await _request('GET', '/stock-transfers', query: {
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (status != null && status.isNotEmpty) 'status': status,
      'limit': '250',
    });
    if (data is! List) return [];
    return data.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> create({
    required String sourceBranchId,
    required String destinationBranchId,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    final data = await _request('POST', '/stock-transfers', body: {
      'sourceBranchId': int.parse(sourceBranchId),
      'destinationBranchId': int.parse(destinationBranchId),
      'items': items,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> approve(String id) async =>
      Map<String, dynamic>.from(await _request('POST', '/stock-transfers/$id/approve') as Map);

  Future<Map<String, dynamic>> reject(String id, {String? note}) async =>
      Map<String, dynamic>.from(await _request('POST', '/stock-transfers/$id/reject', body: {
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }) as Map);

  Future<Map<String, dynamic>> receive(String id, List<Map<String, dynamic>> items) async =>
      Map<String, dynamic>.from(await _request('POST', '/stock-transfers/$id/receive', body: {'items': items}) as Map);
}

class StockTransferException implements Exception {
  const StockTransferException(this.message);
  final String message;
  @override
  String toString() => message;
}
