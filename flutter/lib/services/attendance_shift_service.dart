import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class AttendanceShiftService {
  AttendanceShiftService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? query}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw const AttendanceShiftException('Please sign in again.');
    }
    final uri = Uri.parse('$apiBaseUrl$path');
    final target = query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response = switch (method) {
      'GET' => await _client.get(target, headers: headers),
      'POST' => await _client.post(target, headers: headers, body: jsonEncode(body ?? {})),
      'PATCH' => await _client.patch(target, headers: headers, body: jsonEncode(body ?? {})),
      _ => throw const AttendanceShiftException('Unsupported request method.'),
    };
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AttendanceShiftException('Unable to read server response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300 || payload['success'] != true) {
      throw AttendanceShiftException(payload['message']?.toString() ?? 'Request failed.');
    }
    return payload['data'];
  }

  Future<Map<String, dynamic>?> currentAttendance() async {
    final data = await _request('GET', '/attendance/me');
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<List<Map<String, dynamic>>> attendanceHistory({
    String? branchId, String? from, String? to,
  }) async {
    final data = await _request('GET', '/attendance', query: {
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return _rows(data);
  }

  Future<Map<String, dynamic>> checkIn({required String branchId, String? note}) async {
    final data = await _request('POST', '/attendance/check-in', body: {
      'branchId': int.parse(branchId),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> checkOut({String? note}) async {
    final data = await _request('POST', '/attendance/check-out', body: {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> shifts({
    String? branchId, String? from, String? to, String? status,
  }) async {
    final data = await _request('GET', '/employee-shifts', query: {
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return _rows(data);
  }

  Future<Map<String, dynamic>> createShift({
    required String branchId,
    required String userId,
    required String shiftDate,
    required String startTime,
    required String endTime,
    String? notes,
  }) async {
    final data = await _request('POST', '/employee-shifts', body: {
      'branchId': int.parse(branchId),
      'userId': int.parse(userId),
      'shiftDate': shiftDate,
      'startTime': startTime,
      'endTime': endTime,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> cancelShift(String id) async {
    await _request('PATCH', '/employee-shifts/$id/cancel');
  }

  List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is! List) return [];
    return data.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }
}

class AttendanceShiftException implements Exception {
  const AttendanceShiftException(this.message);
  final String message;
  @override
  String toString() => message;
}
