import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';
import '../models/inventory_item.dart';
class InventoryService {
  InventoryService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(), _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;
  Future<List<InventoryItem>> items() async {
    final data = await _get('/inventory/items');
    return (data as List<dynamic>).map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }
  Future<List<BranchStockEntry>> stock(String branchId) async {
    final data = await _get('/inventory/stock?branchId=${Uri.encodeQueryComponent(branchId)}');
    return (data as List<dynamic>).map((e) => BranchStockEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
  Future<List<BranchStockEntry>> lowStock(String branchId) async {
    final data = await _get('/inventory/stock/low?branchId=${Uri.encodeQueryComponent(branchId)}');
    return (data as List<dynamic>).map((e) => BranchStockEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
  Future<void> createItem({required String name, required String itemType, required String unit, String? sku}) async {
    await _request('POST', '/inventory/items', body: {'name':name,'itemType':itemType,'unit':unit,if(sku!=null&&sku.isNotEmpty)'sku':sku});
  }
  Future<dynamic> _get(String path) => _request('GET', path);
  Future<dynamic> _request(String method,String path,{Map<String,dynamic>? body}) async {
    final token=await _storage.read(key:'access_token');
    if(token==null||token.isEmpty) throw const InventoryException('Please sign in again.');
    final uri=Uri.parse('$apiBaseUrl$path');
    final headers={'Authorization':'Bearer $token','Content-Type':'application/json'};
    final response=switch(method){
      'GET'=>await _client.get(uri,headers:headers),
      'POST'=>await _client.post(uri,headers:headers,body:jsonEncode(body)),
      _=>throw const InventoryException('Unsupported request method.')
    };
    Map<String,dynamic> payload;
    try{payload=jsonDecode(response.body) as Map<String,dynamic>;}catch(_){throw const InventoryException('Server response could not be read.');}
    if(response.statusCode<200||response.statusCode>=300||payload['success']!=true)throw InventoryException(payload['message'] as String? ?? 'Inventory request failed.');
    return payload['data'];
  }
}
class InventoryException implements Exception {
  const InventoryException(this.message);
  final String message;
  @override String toString()=>message;
}
