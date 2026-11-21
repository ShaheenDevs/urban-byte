import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:urban_byte/app/app.locator.dart';
import '../app/api_config.dart';
import 'auth_service.dart';

class ExpenseService {
  ExpenseService({http.Client? client})
      : _client = client ?? http.Client();
  final AuthService _authService = locator<AuthService>();
  final http.Client _client;
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

  dynamic _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (decoded is Map && decoded['success'] == false)) {
      throw Exception(decoded is Map
          ? (decoded['message'] ?? 'Expense request failed.').toString()
          : 'Expense request failed.');
    }
    return decoded is Map ? decoded['data'] : null;
  }

  List<Map<String, dynamic>> _rows(dynamic data) {
    final rows = data is Map ? (data['items'] ?? data['data']) : data;
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getExpenses(
      {String status = 'all', String? from, String? to}) async {
    final query = <String, String>{
      if (status != 'all') 'status': status,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      'limit': '100'
    };
    final uri =
        Uri.parse('$apiBaseUrl/expenses').replace(queryParameters: query);
    return _rows(_decode(await _client.get(uri, headers: await _headers)));
  }

  Future<void> create(
      {required int branchId,
      required String category,
      required String description,
      required double amount,
      required String paymentMethod,
      required String expenseDate,
      String? reference}) async {
    final response = await _client.post(Uri.parse('$apiBaseUrl/expenses'),
        headers: await _headers,
        body: jsonEncode({
          'branchId': branchId,
          'category': category,
          'description': description,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'expenseDate': expenseDate,
          'reference': reference
        }));
    _decode(response);
  }

  Future<void> approve(int id) async {
    _decode(await _client.post(Uri.parse('$apiBaseUrl/expenses/$id/approve'),
        headers: await _headers));
  }

  Future<void> reject(int id, String reason) async {
    _decode(await _client.post(Uri.parse('$apiBaseUrl/expenses/$id/reject'),
        headers: await _headers, body: jsonEncode({'reason': reason})));
  }

  Future<Map<String, dynamic>> getSummary() async {
    final data = _decode(await _client.get(
        Uri.parse('$apiBaseUrl/expenses/reports/summary'),
        headers: await _headers));
    return data is Map
        ? Map<String, dynamic>.from(data)
        : {'total': 0, 'byPaymentMethod': []};
  }
}
