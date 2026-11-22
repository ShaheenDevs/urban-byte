import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class PaymentService {
  PaymentService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> record({
    required String orderId,
    required double amount,
    required String method,
    String? reference,
    String? notes,
  }) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) throw Exception('Please sign in again.');
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/payments'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'orderId': int.parse(orderId),
        'amount': amount,
        'method': method,
        if (reference != null && reference.trim().isNotEmpty) 'reference': reference.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      }),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300 || payload['success'] != true) {
      throw Exception(payload['message']?.toString() ?? 'Unable to record payment.');
    }
    return Map<String, dynamic>.from(payload['data'] as Map);
  }
}
