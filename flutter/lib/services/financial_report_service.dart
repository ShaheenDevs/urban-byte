import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'package:urban_byte/app/app.locator.dart';
import '../app/api_config.dart';
import 'auth_service.dart';

class FinancialReportService {
  FinancialReportService({http.Client? client})
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

  Future<Map<String, dynamic>> load(
      {required String from, required String to, String? branchId}) async {
    final query = <String, String>{
      'from': from,
      'to': to,
      if (branchId != null && branchId.trim().isNotEmpty)
        'branchId': branchId.trim()
    };
    final uri = Uri.parse('$apiBaseUrl/reports/financial')
        .replace(queryParameters: query);
    final response = await _client.get(uri, headers: await _headers);
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (decoded is Map && decoded['success'] == false)) {
      throw Exception(decoded is Map
          ? (decoded['message'] ?? 'Financial report failed.').toString()
          : 'Financial report failed.');
    }
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) throw Exception('Invalid financial report response.');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> loadAnalytics(
      {required String from, required String to, String? branchId}) async {
    final query = <String, String>{
      'from': from,
      'to': to,
      if (branchId != null && branchId.trim().isNotEmpty)
        'branchId': branchId.trim()
    };
    final uri = Uri.parse('$apiBaseUrl/reports/analytics')
        .replace(queryParameters: query);
    final response = await _client.get(uri, headers: await _headers);
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (decoded is Map && decoded['success'] == false)) {
      throw Exception(decoded is Map
          ? (decoded['message'] ?? 'Analytics report failed.').toString()
          : 'Analytics report failed.');
    }
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) throw Exception('Invalid analytics response.');
    return Map<String, dynamic>.from(data);
  }

  Future<Uint8List> exportReport({
    required String report,
    required String format,
    required String from,
    required String to,
    String? branchId,
  }) async {
    if (!const {'financial', 'analytics'}.contains(report) ||
        !const {'pdf', 'csv'}.contains(format)) {
      throw ArgumentError('Unsupported report export.');
    }
    final query = <String, String>{
      'from': from,
      'to': to,
      if (branchId != null && branchId.trim().isNotEmpty)
        'branchId': branchId.trim(),
    };
    final uri = Uri.parse('$apiBaseUrl/reports/$report/export.$format')
        .replace(queryParameters: query);
    final response = await _client.get(uri, headers: await _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message =
          'Report export failed (' + response.statusCode.toString() + ').';
      try {
        final payload = jsonDecode(response.body);
        if (payload is Map && payload['message'] != null) {
          message = payload['message'].toString();
        }
      } catch (_) {
        // Keep the safe fallback for non-JSON server/proxy errors.
      }
      throw Exception(message);
    }
    if (response.bodyBytes.isEmpty) {
      throw Exception('The server returned an empty report.');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> exportSupplierLedgerPdf(String supplierId) async {
    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in again.');
    }
    final uri = Uri.parse(
        '$apiBaseUrl/inventory/suppliers/${Uri.encodeComponent(supplierId)}/ledger/export.pdf');
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.bodyBytes.isEmpty) {
      throw Exception('Supplier PDF export failed (${response.statusCode}).');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> buildSupplierLedgerWorkbook({
    required Map<String, dynamic> ledger,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Supplier Ledger'];
    final supplier = ledger['supplier'];
    final supplierName = supplier is Map
        ? (supplier['name']?.toString() ?? 'Supplier')
        : 'Supplier';
    sheet.appendRow([
      TextCellValue('Urban Byte - Supplier Ledger'),
    ]);
    sheet.appendRow([TextCellValue('Supplier'), TextCellValue(supplierName)]);
    sheet.appendRow([
      TextCellValue('Purchase total'),
      DoubleCellValue(_number(ledger['purchaseTotal'])),
    ]);
    sheet.appendRow([
      TextCellValue('Paid total'),
      DoubleCellValue(_number(ledger['paidTotal'])),
    ]);
    sheet.appendRow([
      TextCellValue('Outstanding'),
      DoubleCellValue(_number(ledger['outstanding'])),
    ]);
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('Purchase #'),
      TextCellValue('Date'),
      TextCellValue('Total (PKR)'),
      TextCellValue('Paid (PKR)'),
      TextCellValue('Due (PKR)'),
    ]);
    for (final row in (ledger['purchases'] as List? ?? const [])) {
      if (row is! Map) continue;
      sheet.appendRow([
        TextCellValue(row['purchaseNumber']?.toString() ?? ''),
        TextCellValue(row['date']?.toString() ?? ''),
        DoubleCellValue(_number(row['total'])),
        DoubleCellValue(_number(row['paid'])),
        DoubleCellValue(_number(row['due'])),
      ]);
    }
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('Payment date'),
      TextCellValue('Method'),
      TextCellValue('Reference'),
      TextCellValue('Amount (PKR)'),
    ]);
    for (final payment in (ledger['payments'] as List? ?? const [])) {
      if (payment is! Map) continue;
      sheet.appendRow([
        TextCellValue(payment['createdAt']?.toString() ?? ''),
        TextCellValue(payment['method']?.toString() ?? ''),
        TextCellValue(payment['reference']?.toString() ?? ''),
        DoubleCellValue(_number(payment['amount'])),
      ]);
    }
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not generate supplier XLSX workbook.');
    }
    return Uint8List.fromList(bytes);
  }

  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;
}
