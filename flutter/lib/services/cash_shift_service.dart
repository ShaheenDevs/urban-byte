import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class CashShiftService {
  CashShiftService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) throw Exception('Please sign in again.');
    final uri = Uri.parse('$apiBaseUrl/cash-shifts$path');
    final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.post(uri, headers: headers, body: jsonEncode(body ?? {}));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300 || payload['success'] != true) {
      throw Exception(payload['message']?.toString() ?? 'Cash shift request failed.');
    }
    return payload['data'];
  }

  Future<List<Map<String, dynamic>>> current({String? branchId}) async {
    final query = branchId == null ? '' : '?branchId=${Uri.encodeQueryComponent(branchId)}';
    final data = await _request('GET', '/current$query');
    if (data is! List) throw Exception('Invalid cash shift response.');
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> open({required String branchId, required double openingCash}) async =>
      Map<String, dynamic>.from(await _request('POST', '/open', body: {'branchId': int.parse(branchId), 'openingCash': openingCash}) as Map);

  Future<void> entry({required String shiftId, required String type, required double amount, required String description}) async {
    await _request('POST', '/$shiftId/entries', body: {'entryType': type, 'amount': amount, 'description': description});
  }

  Future<Map<String, dynamic>> close({required String shiftId, required double actualCash, String? notes}) async =>
      Map<String, dynamic>.from(await _request('POST', '/$shiftId/close', body: {'actualCash': actualCash, if (notes != null && notes.isNotEmpty) 'notes': notes}) as Map);

  Future<Map<String, dynamic>> report(String shiftId) async =>
      Map<String, dynamic>.from(await _request('GET', '/$shiftId/report') as Map);
}
