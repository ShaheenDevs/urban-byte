import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';
import '../models/inventory_item.dart';

class InventoryService {
  InventoryService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;
  Future<List<RestaurantBranch>> branches() async =>
      (await _get('/inventory/branches') as List)
          .map((e) => RestaurantBranch.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  Future<List<InventoryItem>> items() async =>
      (await _get('/inventory/items') as List)
          .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  Future<List<BranchStockEntry>> stock(String id) async =>
      (await _get('/inventory/stock?branchId=' + Uri.encodeQueryComponent(id))
              as List)
          .map((e) => BranchStockEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  Future<List<BranchStockEntry>> lowStock(String id) async => (await _get(
              '/inventory/stock/low?branchId=' + Uri.encodeQueryComponent(id))
          as List)
      .map((e) => BranchStockEntry.fromJson(Map<String, dynamic>.from(e)))
      .toList();
  Future<void> createItem(
      {required String name,
      required String itemType,
      required String unit,
      String? sku}) async {
    await _request('POST', '/inventory/items', body: {
      'name': name,
      'itemType': itemType,
      'unit': unit,
      if (sku != null && sku.isNotEmpty) 'sku': sku
    });
  }

  Future<List<Map<String, dynamic>>> suppliers() async =>
      _list(await _get('/inventory/suppliers'));
  Future<void> createSupplier(
      {required String name, String? phone, String? notes}) async {
    await _request('POST', '/inventory/suppliers',
        body: {'name': name, 'phone': phone, 'notes': notes});
  }

  Future<List<Map<String, dynamic>>> purchases() async =>
      _list(await _get('/inventory/purchases'));
  Future<void> createPurchase(
      {required String branchId,
      String? supplierId,
      required List<Map<String, dynamic>> items}) async {
    await _request('POST', '/inventory/purchases', body: {
      'branchId': int.parse(branchId),
      if (supplierId != null) 'supplierId': int.parse(supplierId),
      'items': items
    });
  }

  Future<void> receivePurchase(String id) async {
    await _request(
        'POST', '/inventory/purchases/' + Uri.encodeComponent(id) + '/receive');
  }

  Future<List<Map<String, dynamic>>> recipes() async =>
      _list(await _get('/inventory/recipes'));
  Future<void> saveRecipe(
      {required String variantId,
      required double yieldQuantity,
      required List<Map<String, dynamic>> items}) async {
    await _request('PUT', '/inventory/recipes', body: {
      'productVariantId': int.parse(variantId),
      'yieldQuantity': yieldQuantity,
      'items': items
    });
  }

  List<Map<String, dynamic>> _list(dynamic data) =>
      (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  Future<dynamic> _get(String path) => _request('GET', path);
  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty)
      throw const InventoryException('Please sign in again.');
    final uri = Uri.parse(apiBaseUrl + path);
    final headers = {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json'
    };
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      'PUT' => await _client.put(uri, headers: headers, body: encoded),
      _ => throw const InventoryException('Unsupported request method.')
    };
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const InventoryException('Server response could not be read.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true)
      throw InventoryException(
          payload['message'] as String? ?? 'Inventory request failed.');
    return payload['data'];
  }
}

class InventoryException implements Exception {
  const InventoryException(this.message);
  final String message;
  @override
  String toString() => message;
}
