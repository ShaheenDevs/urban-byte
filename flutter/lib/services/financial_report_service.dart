import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app/api_config.dart';
import 'auth_service.dart';

class FinancialReportService {
  FinancialReportService(this._auth,{http.Client? client}):_client=client??http.Client();
  final AuthService _auth;
  final http.Client _client;
  Future<Map<String,String>> get _headers async {
    final token=await _auth.getAccessToken();
    if(token==null||token.isEmpty)throw Exception('Please sign in again.');
    return {'Content-Type':'application/json','Authorization':'Bearer $token'};
  }
  Future<Map<String,dynamic>> load({required String from,required String to,String? branchId}) async {
    final query=<String,String>{'from':from,'to':to,if(branchId!=null&&branchId.trim().isNotEmpty)'branchId':branchId.trim()};
    final uri=Uri.parse('$apiBaseUrl/reports/financial').replace(queryParameters:query);
    final response=await _client.get(uri,headers:await _headers);
    final decoded=jsonDecode(response.body);
    if(response.statusCode<200||response.statusCode>=300||(decoded is Map&&decoded['success']==false)) {
      throw Exception(decoded is Map?(decoded['message']??'Financial report failed.').toString():'Financial report failed.');
    }
    final data=decoded is Map?decoded['data']:null;
    if(data is! Map)throw Exception('Invalid financial report response.');
    return Map<String,dynamic>.from(data);
  }

  Future<Map<String,dynamic>> loadAnalytics({required String from,required String to,String? branchId}) async {
    final query=<String,String>{'from':from,'to':to,if(branchId!=null&&branchId.trim().isNotEmpty)'branchId':branchId.trim()};
    final uri=Uri.parse('$apiBaseUrl/reports/analytics').replace(queryParameters:query);
    final response=await _client.get(uri,headers:await _headers);
    final decoded=jsonDecode(response.body);
    if(response.statusCode<200||response.statusCode>=300||(decoded is Map&&decoded['success']==false)) {
      throw Exception(decoded is Map?(decoded['message']??'Analytics report failed.').toString():'Analytics report failed.');
    }
    final data=decoded is Map?decoded['data']:null;
    if(data is! Map)throw Exception('Invalid analytics response.');
    return Map<String,dynamic>.from(data);
  }
}