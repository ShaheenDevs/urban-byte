import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class AiAgentService {
  AiAgentService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;
  Future<List<Map<String, dynamic>>> conversations() async =>
      _list(await _request('GET', '/ai/conversations'));
  Future<List<Map<String, dynamic>>> approvals() async =>
      _list(await _request('GET', '/ai/approvals'));
  Future<void> review(String id, String decision, {String? note}) async {
    await _request('POST', '/ai/approvals/$id/review',
        body: {'decision': decision, 'note': note});
  }

  Future<void> sendWhatsAppText(String conversationId, String text) async {
    await _request('POST', '/ai/conversations/$conversationId/whatsapp/send',
        body: {'text': text});
  }

  Future<Map<String, dynamic>> createConversation(
          {String? name, String? phone, String channel = 'manual'}) async =>
      Map<String, dynamic>.from(await _request('POST', '/ai/conversations',
          body: {
            'customerName': name,
            'customerPhone': phone,
            'channel': channel
          }) as Map);
  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty)
      throw const AiAgentException('Please sign in again.');
    final uri = Uri.parse(apiBaseUrl + path);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      _ => throw const AiAgentException('Unsupported request.')
    };
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiAgentException('Unable to read server response.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true)
      throw AiAgentException(
          data['message'] as String? ?? 'AI request failed.');
    return data['data'];
  }

  List<Map<String, dynamic>> _list(dynamic d) =>
      (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

class AiAgentException implements Exception {
  const AiAgentException(this.message);
  final String message;
  @override
  String toString() => message;
}
