import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';

class OperationsService {
  OperationsService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;
  Future<Map<String, dynamic>> dashboardSummary(
      {String? branchId,
      String? startDate,
      String? endDate,
      String? startTime,
      String? endTime}) async {
    final query = <String, String>{
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime
    };
    final suffix = query.isEmpty ? '' : '?' + Uri(queryParameters: query).query;
    final data = await _request('GET', '/dashboard/summary$suffix');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> menu({String? branchId}) async {
    final suffix = branchId == null || branchId.isEmpty
        ? ''
        : '?branchId=${Uri.encodeQueryComponent(branchId)}';
    return _list(await _request('GET', '/menu/products$suffix'));
  }

  Future<List<Map<String, dynamic>>> orders(
      {String? status,
      String? branchId,
      String? statusGroup,
      String? paymentStatus,
      String? paymentStatusGroup,
      String? startDate,
      String? endDate,
      String? startTime,
      String? endTime}) async {
    final query = <String, String>{
      if (status != null) 'status': status,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (statusGroup != null) 'statusGroup': statusGroup,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (paymentStatusGroup != null) 'paymentStatusGroup': paymentStatusGroup,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'limit': '100',
    };
    final q = query.isEmpty ? '' : '?' + Uri(queryParameters: query).query;
    final data = await _request('GET', '/orders$q');
    if (data is Map && data['items'] is List) return _list(data['items']);
    return _list(data);
  }

  Future<List<Map<String, dynamic>>> kitchenQueue(
      {String? branchId, String? status}) async {
    final query = <String, String>{
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (status != null) 'status': status
    };
    final path = query.isEmpty
        ? '/kitchen/tickets'
        : '/kitchen/tickets?' + Uri(queryParameters: query).query;
    return _list(await _request('GET', path));
  }

  Future<List<Map<String, dynamic>>> deliveryAssignments(
      {String? status, String? branchId}) async {
    final query = <String, String>{
      if (status != null) 'status': status,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
    };
    final suffix = query.isEmpty ? '' : '?'+Uri(queryParameters: query).query;
    return _list(await _request('GET', '/delivery/assignments$suffix'));
  }

  Future<List<Map<String, dynamic>>> unassignedDeliveryOrders(
      {String? branchId}) async {
    final suffix = branchId == null || branchId.isEmpty
        ? ''
        : '?branchId=${Uri.encodeQueryComponent(branchId)}';
    return _list(await _request('GET', '/delivery/unassigned$suffix'));
  }

  Future<void> updateDeliveryStatus(String assignmentId, String status,
      {bool codCollected = false, String? note}) async {
    await _request('PATCH', '/delivery/assignments/$assignmentId/status',
        body: {
          'status': status,
          if (codCollected) 'codCollected': true,
          if (note != null && note.isNotEmpty) 'note': note,
        });
  }

  Future<String> createDeliveryTrackingLink(String assignmentId) async {
    final data = Map<String, dynamic>.from(await _request('POST', '/delivery/assignments/$assignmentId/tracking-link') as Map);
    return Uri.parse(apiBaseUrl).replace(path: data['trackingPath'].toString()).toString();
  }

  Future<void> updateRiderLocation(String assignmentId, {required double latitude, required double longitude, double? accuracy}) async {
    await _request('PATCH', '/delivery/assignments/$assignmentId/location', body: {'latitude': latitude, 'longitude': longitude, if (accuracy != null) 'accuracy': accuracy});
  }

  Future<List<Map<String, dynamic>>> deliveryDrivers({String? branchId}) async {
    final suffix = branchId == null || branchId.isEmpty
        ? ''
        : '?branchId=${Uri.encodeQueryComponent(branchId)}';
    return _list(await _request('GET', '/delivery/drivers$suffix'));
  }

  Future<List<Map<String, dynamic>>> deliveryHistory({String? riderId, String? branchId, String? from, String? to}) async => _list(await _request('GET', _deliveryReportPath('/delivery/history', riderId: riderId, branchId: branchId, from: from, to: to)));
  Future<Map<String, dynamic>> deliveryCodCollections({String? riderId, String? branchId, String? from, String? to}) async => Map<String, dynamic>.from(await _request('GET', _deliveryReportPath('/delivery/reports/cod-collections', riderId: riderId, branchId: branchId, from: from, to: to)) as Map);
  Future<Map<String, dynamic>> deliveryPerformance({String? riderId, String? branchId, String? from, String? to}) async => Map<String, dynamic>.from(await _request('GET', _deliveryReportPath('/delivery/reports/performance', riderId: riderId, branchId: branchId, from: from, to: to)) as Map);
  String _deliveryReportPath(String path, {String? riderId, String? branchId, String? from, String? to}) {
    final query = <String, String>{if (riderId != null) 'riderId': riderId, if (branchId != null) 'branchId': branchId, if (from != null) 'from': from, if (to != null) 'to': to};
    return query.isEmpty ? path : path + '?' + Uri(queryParameters: query).query;
  }

  Future<List<Map<String, dynamic>>> deliveryCodSettlements({String? branchId, String? riderId, String? status, String? date}) async {
    final query = <String, String>{if (branchId != null) 'branchId': branchId, if (riderId != null) 'riderId': riderId, if (status != null) 'status': status, if (date != null) 'date': date};
    final suffix = query.isEmpty ? '' : '?' + Uri(queryParameters: query).query;
    return _list(await _request('GET', '/delivery/cod-settlements$suffix'));
  }

  Future<Map<String, dynamic>> submitDeliveryCodSettlement({required String branchId, required String date, required double handedAmount, String? note}) async {
    final data = await _request('POST', '/delivery/cod-settlements', body: {'branchId': int.parse(branchId), 'date': date, 'handedAmount': handedAmount, if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> reviewDeliveryCodSettlement(String id, {required bool approve, String? note}) async {
    await _request('PATCH', '/delivery/cod-settlements/$id/review', body: {'approve': approve, if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
  }

  Future<void> assignDelivery(String orderId, String deliveryUserId) async {
    await _request('POST', '/delivery/orders/$orderId/assign',
        body: {'deliveryUserId': int.parse(deliveryUserId)});
  }

  Future<List<Map<String, dynamic>>> notifications(
      {bool unreadOnly = false}) async {
    final path = unreadOnly ? '/notifications?unread=true' : '/notifications';
    return _list(await _request('GET', path));
  }

  Future<int> unreadNotificationCount() async {
    final data = await _request('GET', '/notifications/unread-count');
    return (data as Map)['count'] as int? ?? 0;
  }

  Future<void> markNotificationRead(String id) async {
    await _request('PATCH', '/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _request('PATCH', '/notifications/read-all');
  }

  Future<Map<String, dynamic>> createOrder(
      {required String branchId,
      required String orderType,
      required List<Map<String, dynamic>> items,
      String? tableLabel,
      String? customerName,
      String? customerPhone,
      String? deliveryAddress,
      String? paymentMethod,
      double? discountAmount,
      double? deliveryDistanceKm,
      double? deliveryLatitude,
      double? deliveryLongitude}) async {
    final key = 'ub-' + DateTime.now().microsecondsSinceEpoch.toString();
    final data = await _request('POST', '/orders', body: {
      'branchId': int.parse(branchId),
      'orderType': orderType,
      'items': items,
      if (tableLabel != null) 'tableLabel': tableLabel,
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      if (deliveryDistanceKm != null) 'deliveryDistanceKm': deliveryDistanceKm,
      if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
      if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (discountAmount != null && discountAmount > 0)
        'discountAmount': discountAmount
    }, extraHeaders: {
      'Idempotency-Key': key
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> updateOrder(String id, String status) async {
    await _request('PATCH', '/orders/$id/status', body: {'status': status});
  }

  Future<void> kitchenAction(String id, String action) async {
    await _request('PATCH', '/kitchen/tickets/$id/$action');
  }

  List<Map<String, dynamic>> _list(dynamic d) =>
      (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? extraHeaders}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw const OperationsException('Please sign in again.');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?extraHeaders
    };
    final uri = Uri.parse(apiBaseUrl + path);
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      'PATCH' => await _client.patch(uri, headers: headers, body: encoded),
      _ => throw const OperationsException('Unsupported operation.')
    };
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const OperationsException('Unable to read server response.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw OperationsException(
          payload['message'] as String? ?? 'Request failed.');
    }
    return payload['data'];
  }
}

class OperationsException implements Exception {
  const OperationsException(this.message);
  final String message;
  @override
  String toString() => message;
}
