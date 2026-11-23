import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app/api_config.dart';

class PrintingService {
  PrintingService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<List<Map<String, dynamic>>> printers({String? branchId}) async {
    final query = branchId == null
        ? ''
        : '?branchId=${Uri.encodeQueryComponent(branchId)}';
    return _list(await _request('GET', '/printing/printers$query'));
  }

  Future<List<Map<String, dynamic>>> jobs(
      {String? branchId, String? status}) async {
    final query = <String, String>{
      if (branchId != null) 'branchId': branchId,
      if (status != null) 'status': status
    };
    final suffix = query.isEmpty ? '' : '?' + Uri(queryParameters: query).query;
    return _list(await _request('GET', '/printing/jobs$suffix'));
  }

  Future<void> registerPrinter(
      {required String branchId,
      required String name,
      required String connectionType,
      required String paperWidth,
      required String purpose,
      String? address,
      String? deviceIdentifier}) async {
    await _request('POST', '/printing/printers', body: {
      'branchId': int.parse(branchId),
      'name': name,
      'connectionType': connectionType,
      'paperWidth': paperWidth,
      'purpose': purpose,
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
      if (deviceIdentifier != null && deviceIdentifier.trim().isNotEmpty)
        'deviceIdentifier': deviceIdentifier.trim(),
    });
  }

  Future<void> _ensureBluetoothPermission() async {
    if (Platform.isAndroid) {
      final statuses = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
      if (statuses.values.any((status) => !status.isGranted)) {
        throw const PrintingException('Allow Nearby devices / Bluetooth permission for Urban Byte in Android app settings.');
      }
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      if (!status.isGranted) throw const PrintingException('Allow Bluetooth permission for Urban Byte in iPhone settings.');
    }
    final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!granted) throw const PrintingException('Bluetooth permission is not granted.');
  }

  Future<List<Map<String, String>>> pairedBluetoothDevices() async {
    await _ensureBluetoothPermission();
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices.map((d) => {'name': d.name, 'mac': d.macAdress}).toList();
  }

  Future<void> printBluetoothText(String mac, String text) async {
    await _ensureBluetoothPermission();
    if (!await PrintBluetoothThermal.bluetoothEnabled) throw const PrintingException('Turn on Bluetooth on this phone.');
    final connected = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (!connected) throw const PrintingException('Could not connect to the selected Bluetooth printer. Pair it in phone settings first.');
    try {
      final ok = await PrintBluetoothThermal.writeString(printText: PrintTextSize(size: 1, text: text));
      if (!ok) throw const PrintingException('Bluetooth printer did not accept the receipt data.');
    } finally {
      await PrintBluetoothThermal.disconnect;
    }
  }

  Future<void> testPrinter(Map<String, dynamic> printer) async {
    final connection = printer['connectionType']?.toString();
    if (connection == 'bluetooth') {
      final mac = printer['deviceIdentifier']?.toString().trim() ?? '';
      if (mac.isEmpty) throw const PrintingException('Select a paired Bluetooth printer MAC address in printer settings.');
      await printBluetoothText(mac, 'URBAN BYTE\nBLUETOOTH PRINTER TEST\n------------------------------\nIf this prints, mobile Bluetooth is connected.\n\n\n');
      return;
    }
    if (connection == 'usb') {
      throw const PrintingException('Direct Android USB printing is not configured in this mobile build. Use Bluetooth or network printing.');
    }
    if (connection != 'network') {
      final id = printer['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const PrintingException('Printer ID is missing.');
      }
      await _request('POST', '/printing/printers/$id/test');
      return;
    }
    final address = printer['address']?.toString().trim() ?? '';
    if (address.isEmpty) {
      throw const PrintingException(
          'This printer has no network IP/host configured.');
    }
    final width = printer['paperWidth']?.toString() == '58mm' ? 32 : 48;
    final now = DateTime.now().toString().substring(0, 19);
    final lines = <String>[
      'URBAN BYTE',
      'PRINTER TEST',
      '------------------------------',
      'Connection: Network',
      'Printer: ${printer['name'] ?? 'Receipt printer'}',
      'Paper: ${printer['paperWidth'] ?? '80mm'}',
      'Time: $now',
      '------------------------------',
      'If you can read this,',
      'the printer is working.',
      '',
      '',
    ];
    final text = lines
        .map((line) => line.length > width ? line.substring(0, width) : line)
        .join('\n');
    Socket? socket;
    try {
      socket = await Socket.connect(address, 9100,
          timeout: const Duration(seconds: 5));
      socket.add([0x1B, 0x40, 0x1B, 0x61, 0x01, 0x1B, 0x45, 0x01]);
      socket.add(latin1.encode(text));
      socket.add([0x1B, 0x45, 0x00, 0x1B, 0x61, 0x00, 0x1D, 0x56, 0x00]);
      await socket.flush().timeout(const Duration(seconds: 5));
    } on SocketException catch (e) {
      throw PrintingException(
          'Cannot connect to printer at $address: ${e.message}');
    } on TimeoutException {
      throw PrintingException(
          'Printer at $address did not respond within 5 seconds.');
    } finally {
      socket?.destroy();
    }
  }

  Future<void> enqueueReceipt(String orderId, {String? printerId}) async {
    await _request('POST', '/printing/orders/$orderId/receipt',
        body: {if (printerId != null) 'printerId': int.parse(printerId)});
  }

  Future<void> enqueueKitchenTicket(String orderId, {String? printerId}) async {
    await _request('POST', '/printing/orders/$orderId/kitchen-ticket',
        body: {if (printerId != null) 'printerId': int.parse(printerId)});
  }

  Future<void> retry(String jobId) async =>
      _request('POST', '/printing/jobs/$jobId/retry');

  List<Map<String, dynamic>> _list(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty)
      throw const PrintingException('Please sign in again.');
    final uri = Uri.parse(apiBaseUrl + path);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      _ => throw const PrintingException('Unsupported request.'),
    };
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const PrintingException('Unable to read server response.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw PrintingException(
          payload['message'] as String? ?? 'Printing request failed.');
    }
    return payload['data'];
  }
}

class PrintingException implements Exception {
  const PrintingException(this.message);
  final String message;
  @override
  String toString() => message;
}
