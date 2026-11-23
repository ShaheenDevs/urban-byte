import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../services/printing_service.dart';

class PrintingView extends StackedView<PrintingViewModel> {
  const PrintingView({super.key, required this.permissions});
  final Set<String> permissions;
  @override
  PrintingViewModel viewModelBuilder(BuildContext context) =>
      PrintingViewModel(PrintingService(), permissions)..load();
  @override
  Widget builder(BuildContext context, PrintingViewModel vm, Widget? child) =>
      Scaffold(
        appBar: AppBar(title: const Text('Printer management'), actions: [
          IconButton(
              onPressed: vm.isBusy ? null : vm.load,
              icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: vm.canManage
            ? FloatingActionButton.extended(
                onPressed: () => _showRegister(context, vm),
                icon: const Icon(Icons.add),
                label: const Text('Add printer'))
            : null,
        body: vm.isBusy && !vm.loaded
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: vm.load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  if (vm.loadingError != null)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(vm.loadingError!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)))),
                  Text('Configured printers',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (vm.printers.isEmpty)
                    const Card(
                        child: ListTile(
                            leading: Icon(Icons.print_disabled),
                            title: Text('No printers configured'),
                            subtitle: Text(
                                'Add a printer and select its connection type.'))),
                  ...vm.printers.map((p) => Card(
                    child: ListTile(
                      onTap: () => _showPrinterDetails(context, vm, p),
                      leading: const CircleAvatar(child: Icon(Icons.print)),
                      title: Text('${p['name'] ?? 'Printer'}'),
                      subtitle: Text('${p['connectionType']} • ${p['paperWidth']} • ${p['purpose']}'),
                      trailing: Wrap(children: [
                        if (vm.canManage) IconButton(
                          tooltip: 'Edit printer',
                          onPressed: () => _showPrinterForm(context, vm, existing: p),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        if (vm.canManage) IconButton(
                          tooltip: 'Delete printer',
                          onPressed: () async {
                            final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                              title: const Text('Delete printer?'),
                              content: Text('Remove ${p['name']}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                              ],
                            ));
                            if (yes == true) await vm.deletePrinter(p['id'].toString());
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                        Icon(p['isActive'] == true ? Icons.check_circle : Icons.pause_circle, color: p['isActive'] == true ? Colors.green : null),
                      ]),
                    ),
                  )),
                  const SizedBox(height: 20),
                  Text('Recent print jobs',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (vm.jobs.isEmpty)
                    const Card(
                        child: ListTile(title: Text('No print jobs yet'))),
                  ...vm.jobs.map((j) => Card(
                          child: ListTile(
                        leading: Icon(_jobIcon('${j['status']}')),
                        title: Text('${j['jobType']} • Order #${j['orderId']}'),
                        subtitle: Text(
                            'Status: ${j['status']} • Attempts: ${j['attempts'] ?? 0}${j['lastError'] == null ? '' : '\n${j['lastError']}'}'),
                        isThreeLine: j['lastError'] != null,
                        trailing: j['status'] == 'failed' && vm.canRetry
                            ? IconButton(
                                tooltip: 'Retry',
                                onPressed: vm.isBusy
                                    ? null
                                    : () => vm.retry('${j['id']}'),
                                icon: const Icon(Icons.replay))
                            : null,
                      ))),
                  const SizedBox(height: 90),

                ]),
              ),
      );

  IconData _jobIcon(String status) => switch (status) {
        'printed' => Icons.check_circle,
        'failed' => Icons.error_outline,
        'printing' => Icons.print,
        _ => Icons.schedule,
      };

  Future<void> _showRegister(BuildContext context, PrintingViewModel vm) =>
      _showPrinterForm(context, vm);

  Future<void> _showPrinterForm(BuildContext context, PrintingViewModel vm, {Map<String,dynamic>? existing}) async {
    final editing = existing != null;
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final branch = TextEditingController(text: existing?['branchId']?.toString() ?? '');
    final address = TextEditingController(text: existing?['address']?.toString() ?? '');
    final device = TextEditingController(text: existing?['deviceIdentifier']?.toString() ?? '');
    String connection = existing?['connectionType']?.toString() ?? 'network';
    String width = existing?['paperWidth']?.toString() ?? '80mm';
    String purpose = existing?['purpose']?.toString() ?? 'both';
    String? selectedMac = device.text.isEmpty ? null : device.text;
    List<Map<String,String>> paired = [];
    bool scanning = false;
    String? scanError;
    if (connection == 'bluetooth') {
      try {
        paired = await vm.pairedBluetoothDevices();
        if (paired.any((d) => d['mac'] == selectedMac)) {
          selectedMac = device.text;
        } else if (!editing && paired.length == 1) {
          selectedMac = paired.first['mac'];
          device.text = selectedMac ?? '';
        }
      } catch (e) {
        scanError = e.toString();
      }
    }
    Future<void> scan(StateSetter setDialogState) async {
      setDialogState(() { scanning = true; scanError = null; });
      try {
        final devices = await vm.pairedBluetoothDevices();
        setDialogState(() {
          paired = devices;
          scanning = false;
          if (selectedMac != null && !paired.any((d) => d['mac'] == selectedMac)) selectedMac = null;
          if (selectedMac == null && paired.length == 1) selectedMac = paired.first['mac'];
          if (selectedMac != null) {
            device.text = selectedMac!;
            final found = paired.where((d) => d['mac'] == selectedMac);
            if (found.isNotEmpty && name.text.trim().isEmpty) name.text = found.first['name'] ?? '';
          }
        });
      } catch (e) {
        setDialogState(() { scanning = false; scanError = e.toString(); });
      }
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(editing ? 'Edit printer' : 'Register printer'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Printer name')),
              TextField(controller: branch, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Branch ID')),
              DropdownButtonFormField<String>(
                value: connection,
                decoration: const InputDecoration(labelText: 'Connection'),
                items: const [
                  DropdownMenuItem(value: 'network', child: Text('Network')),
                  DropdownMenuItem(value: 'usb', child: Text('USB')),
                  DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth')),
                  DropdownMenuItem(value: 'windows_bridge', child: Text('Windows bridge')),
                ],
                onChanged: (v) => setState(() { connection = v ?? connection; selectedMac = null; device.clear(); if (connection == 'bluetooth') scan(setState); }),
              ),
              if (connection == 'bluetooth') ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Expanded(child: Text('Paired Bluetooth devices')),
                  TextButton.icon(
                    onPressed: scanning ? null : () => scan(setState),
                    icon: scanning ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.refresh),
                    label: Text(scanning ? 'Loading...' : 'Load list'),
                  ),
                ]),
                DropdownButtonFormField<String>(
                  value: paired.any((d) => d['mac'] == selectedMac) ? selectedMac : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select printer device'),
                  items: paired.map((d) => DropdownMenuItem<String>(
                    value: d['mac'],
                    child: Text('${d['name'] ?? 'Bluetooth device'} • ${d['mac'] ?? ''}', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setState(() {
                    selectedMac = v;
                    device.text = v ?? '';
                    final found = paired.where((d) => d['mac'] == v);
                    if (found.isNotEmpty) name.text = found.first['name'] ?? name.text;
                  }),
                ),
                if (scanError != null) Align(alignment: Alignment.centerLeft, child: Text(scanError!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                if (!scanning && paired.isEmpty && scanError == null) const Align(alignment: Alignment.centerLeft, child: Text('No paired devices found. Pair the printer in phone Bluetooth settings, then load list.')),
                if (selectedMac != null) Align(alignment: Alignment.centerLeft, child: Text('MAC: $selectedMac')),
              ],
              DropdownButtonFormField<String>(
                value: width,
                decoration: const InputDecoration(labelText: 'Paper width'),
                items: const [DropdownMenuItem(value: '58mm', child: Text('58mm')), DropdownMenuItem(value: '80mm', child: Text('80mm'))],
                onChanged: (v) => setState(() => width = v ?? width),
              ),
              DropdownButtonFormField<String>(
                value: purpose,
                decoration: const InputDecoration(labelText: 'Purpose'),
                items: const [DropdownMenuItem(value: 'receipt', child: Text('Receipt')), DropdownMenuItem(value: 'kitchen', child: Text('Kitchen')), DropdownMenuItem(value: 'both', child: Text('Both'))],
                onChanged: (v) => setState(() => purpose = v ?? purpose),
              ),
              if (connection == 'network') TextField(controller: address, decoration: const InputDecoration(labelText: 'Network address / IP')),
              if (connection != 'bluetooth') TextField(controller: device, decoration: const InputDecoration(labelText: 'Device identifier (optional)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: vm.isBusy || name.text.trim().isEmpty || branch.text.trim().isEmpty || (connection == 'bluetooth' && (selectedMac == null || selectedMac!.isEmpty)) ? null : () async {
                Navigator.pop(dialogContext);
                if (editing) {
                  await vm.updatePrinter(
                    id: existing['id'].toString(), branchId: branch.text.trim(), name: name.text.trim(),
                    connection: connection, width: width, purpose: purpose, address: address.text, device: connection == 'bluetooth' ? selectedMac! : device.text,
                  );
                } else {
                  await vm.register(
                    branchId: branch.text.trim(), name: name.text.trim(), connection: connection,
                    width: width, purpose: purpose, address: address.text, device: connection == 'bluetooth' ? selectedMac! : device.text,
                  );
                }
              },
              child: Text(editing ? 'Update printer' : 'Save printer'),
            ),
          ],
        ),
      ),
    );
    name.dispose(); branch.dispose(); address.dispose(); device.dispose();
  }

  Future<void> _showPrinterDetails(BuildContext context, PrintingViewModel vm, Map<String,dynamic> printer) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(printer['name']?.toString() ?? 'Printer details'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Connection: ${printer['connectionType']}'),
          Text('MAC / Device: ${printer['deviceIdentifier'] ?? '-'}'),
          Text('Network address: ${printer['address'] ?? '-'}'),
          Text('Paper: ${printer['paperWidth']}'),
          Text('Purpose: ${printer['purpose']}'),
          Text('Branch ID: ${printer['branchId']}'),
          Text('Status: ${printer['isActive'] == true ? 'Active' : 'Inactive'}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          if (vm.canManage) TextButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok = await vm.testPrint(printer);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Printer test completed.' : vm.loadingError ?? 'Printer test failed.')));
            },
            icon: const Icon(Icons.print), label: const Text('Test printer'),
          ),
          if (vm.canManage) TextButton.icon(
            onPressed: () { Navigator.pop(dialogContext); _showPrinterForm(context, vm, existing: printer); },
            icon: const Icon(Icons.edit), label: const Text('Edit'),
          ),
          if (vm.canManage) TextButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Delete printer?'),
                content: Text('Remove ${printer['name']} from configured printers?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ));
              if (confirmed == true) await vm.deletePrinter(printer['id'].toString());
            },
            icon: const Icon(Icons.delete_outline), label: const Text('Delete'),
          ),
        ],
      ),
    );
  }

}

class PrintingViewModel extends BaseViewModel {
  PrintingViewModel(this.service, this.permissions);
  final PrintingService service;
  final Set<String> permissions;
  List<Map<String, dynamic>> printers = [];
  List<Map<String, dynamic>> jobs = [];
  bool loaded = false;
  String? loadingError;
  bool get canManage => permissions.contains('printers.manage');
  bool get canRetry => permissions.contains('printing.retry');
  Future<void> load() async {
    setBusy(true);
    loadingError = null;
    try {
      final result = await Future.wait([
        if (permissions.contains('printers.view')) service.printers(),
        if (permissions.contains('printing.view')) service.jobs(),
      ]);
      var index = 0;
      printers = permissions.contains('printers.view') ? result[index++] : [];
      jobs = permissions.contains('printing.view') ? result[index] : [];
      loaded = true;
    } catch (e) {
      loadingError = e.toString();
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> register(
      {required String branchId,
      required String name,
      required String connection,
      required String width,
      required String purpose,
      required String address,
      required String device}) async {
    setBusy(true);
    loadingError = null;
    try {
      await service.registerPrinter(
          branchId: branchId,
          name: name,
          connectionType: connection,
          paperWidth: width,
          purpose: purpose,
          address: address,
          deviceIdentifier: device);
      await load();
    } catch (e) {
      loadingError = e.toString();
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> updatePrinter({
    required String id,
    required String branchId,
    required String name,
    required String connection,
    required String width,
    required String purpose,
    required String address,
    required String device,
  }) async {
    setBusy(true);
    loadingError = null;
    try {
      await service.updatePrinter(id, branchId: branchId, name: name,
        connectionType: connection, paperWidth: width, purpose: purpose,
        address: address, deviceIdentifier: device);
      await load();
    } catch (e) {
      loadingError = e.toString();
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> deletePrinter(String id) async {
    setBusy(true);
    loadingError = null;
    try {
      await service.deletePrinter(id);
      await load();
    } catch (e) {
      loadingError = e.toString();
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<List<Map<String, String>>> pairedBluetoothDevices() => service.pairedBluetoothDevices();

  Future<bool> testPrint(Map<String, dynamic> printer) async {
    setBusy(true);
    loadingError = null;
    try {
      await service.testPrinter(printer);
      return true;
    } catch (e) {
      loadingError = e.toString();
      return false;
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> retry(String id) async {
    setBusy(true);
    loadingError = null;
    try {
      await service.retry(id);
      await load();
    } catch (e) {
      loadingError = e.toString();
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }
}
