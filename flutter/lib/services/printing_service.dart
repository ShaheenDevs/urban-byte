import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class PrintingService {
  PrintingService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<List<Map<String, dynamic>>> printers({String? branchId}) async {
    final query = branchId == null
        ? ''
        : '?branchId=${Uri.encodeQueryComponent(branchId)}';
    return _list(await _request('GET', '/printing/printers$query'));
  }

  Future<List<Map<String, dynamic>>> jobs(
      {String? branchId, String? status}) async {
    final query = <String, String>{
      if (branchId != null) 'branchId': branchId,
      if (status != null) 'status': status
    };
    final suffix = query.isEmpty ? '' : '?' + Uri(queryParameters: query).query;
    return _list(await _request('GET', '/printing/jobs$suffix'));
  }

  Future<void> registerPrinter(
      {required String branchId,
      required String name,
      required String connectionType,
      required String paperWidth,
      required String purpose,
      String? address,
      String? deviceIdentifier}) async {
    await _request('POST', '/printing/printers', body: {
      'branchId': int.parse(branchId),
      'name': name,
      'connectionType': connectionType,
      'paperWidth': paperWidth,
      'purpose': purpose,
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
      if (deviceIdentifier != null && deviceIdentifier.trim().isNotEmpty)
        'deviceIdentifier': deviceIdentifier.trim(),
    });
  }

  Future<void> enqueueReceipt(String orderId, {String? printerId}) async {
    await _request('POST', '/printing/orders/$orderId/receipt',
        body: {if (printerId != null) 'printerId': int.parse(printerId)});
  }

  Future<void> enqueueKitchenTicket(String orderId, {String? printerId}) async {
    await _request('POST', '/printing/orders/$orderId/kitchen-ticket',
        body: {if (printerId != null) 'printerId': int.parse(printerId)});
  }

  Future<void> retry(String jobId) async =>
      _request('POST', '/printing/jobs/$jobId/retry');

  List<Map<String, dynamic>> _list(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty)
      throw const PrintingException('Please sign in again.');
    final uri = Uri.parse(apiBaseUrl + path);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      _ => throw const PrintingException('Unsupported request.'),
    };
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const PrintingException('Unable to read server response.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw PrintingException(
          payload['message'] as String? ?? 'Printing request failed.');
    }
    return payload['data'];
  }
}

class PrintingException implements Exception {
  const PrintingException(this.message);
  final String message;
  @override
  String toString() => message;
}
