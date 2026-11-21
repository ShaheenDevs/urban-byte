import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../services/printing_service.dart';

class PrintingView extends StackedView<PrintingViewModel> {
  const PrintingView({super.key, required this.permissions});
  final Set<String> permissions;
  @override
  PrintingViewModel viewModelBuilder(BuildContext context) => PrintingViewModel(PrintingService(), permissions)..load();
  @override
  Widget builder(BuildContext context, PrintingViewModel vm, Widget? child) => Scaffold(
    appBar: AppBar(title: const Text('Printer management'), actions: [IconButton(onPressed: vm.isBusy ? null : vm.load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: vm.canManage ? FloatingActionButton.extended(onPressed: () => _showRegister(context, vm), icon: const Icon(Icons.add), label: const Text('Add printer')) : null,
    body: vm.isBusy && !vm.loaded ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: vm.load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (vm.error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(vm.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
        Text('Configured printers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (vm.printers.isEmpty) const Card(child: ListTile(leading: Icon(Icons.print_disabled), title: Text('No printers configured'), subtitle: Text('Add a printer and select its connection type.'))),
        ...vm.printers.map((p) => Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.print)),
          title: Text('${p['name'] ?? 'Printer'}'),
          subtitle: Text('${p['connectionType']} • ${p['paperWidth']} • ${p['purpose']}'),
          trailing: Icon(p['isActive'] == true ? Icons.check_circle : Icons.pause_circle, color: p['isActive'] == true ? Colors.green : null),
        ))),
        const SizedBox(height: 20),
        Text('Recent print jobs', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (vm.jobs.isEmpty) const Card(child: ListTile(title: Text('No print jobs yet'))),
        ...vm.jobs.map((j) => Card(child: ListTile(
          leading: Icon(_jobIcon('${j['status']}')),
          title: Text('${j['jobType']} • Order #${j['orderId']}'),
          subtitle: Text('Status: ${j['status']} • Attempts: ${j['attempts'] ?? 0}${j['lastError'] == null ? '' : '\n${j['lastError']}'}'),
          isThreeLine: j['lastError'] != null,
          trailing: j['status'] == 'failed' && vm.canRetry ? IconButton(tooltip: 'Retry', onPressed: vm.isBusy ? null : () => vm.retry('${j['id']}'), icon: const Icon(Icons.replay)) : null,
        ))),
        const SizedBox(height: 90),
        const Text('USB and Bluetooth devices require a local Flutter print bridge. This screen manages printer records and the server queue; it does not send raw print data to a physical printer yet.', style: TextStyle(fontSize: 12)),
      ]),
    ),
  );

  IconData _jobIcon(String status) => switch (status) {
    'printed' => Icons.check_circle,
    'failed' => Icons.error_outline,
    'printing' => Icons.print,
    _ => Icons.schedule,
  };

  Future<void> _showRegister(BuildContext context, PrintingViewModel vm) async {
    final name = TextEditingController();
    final branch = TextEditingController();
    final address = TextEditingController();
    final device = TextEditingController();
    String connection = 'network', width = '80mm', purpose = 'both';
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: const Text('Register printer'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Printer name')),
        TextField(controller: branch, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Branch ID')),
        DropdownButtonFormField(value: connection, decoration: const InputDecoration(labelText: 'Connection'), items: const [
          DropdownMenuItem(value: 'network', child: Text('Network')),
          DropdownMenuItem(value: 'usb', child: Text('USB')),
          DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth')),
          DropdownMenuItem(value: 'windows_bridge', child: Text('Windows bridge')),
        ], onChanged: (v) => setState(() => connection = v ?? connection)),
        DropdownButtonFormField(value: width, decoration: const InputDecoration(labelText: 'Paper width'), items: const [DropdownMenuItem(value: '58mm', child: Text('58mm')), DropdownMenuItem(value: '80mm', child: Text('80mm'))], onChanged: (v) => setState(() => width = v ?? width)),
        DropdownButtonFormField(value: purpose, decoration: const InputDecoration(labelText: 'Purpose'), items: const [DropdownMenuItem(value: 'receipt', child: Text('Receipt')), DropdownMenuItem(value: 'kitchen', child: Text('Kitchen')), DropdownMenuItem(value: 'both', child: Text('Both'))], onChanged: (v) => setState(() => purpose = v ?? purpose)),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'Network address (optional)')),
        TextField(controller: device, decoration: const InputDecoration(labelText: 'Device identifier (optional)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async {
        if (name.text.trim().isEmpty || branch.text.trim().isEmpty) return;
        Navigator.pop(dialogContext);
        await vm.register(branchId: branch.text.trim(), name: name.text.trim(), connection: connection, width: width, purpose: purpose, address: address.text, device: device.text);
      }, child: const Text('Save'))],
    )));
    name.dispose(); branch.dispose(); address.dispose(); device.dispose();
  }
}

class PrintingViewModel extends BaseViewModel {
  PrintingViewModel(this.service, this.permissions);
  final PrintingService service;
  final Set<String> permissions;
  List<Map<String, dynamic>> printers = [];
  List<Map<String, dynamic>> jobs = [];
  bool loaded = false;
  String? error;
  bool get canManage => permissions.contains('printers.manage');
  bool get canRetry => permissions.contains('printing.retry');
  Future<void> load() async {
    setBusy(true); error = null;
    try {
      final result = await Future.wait([
        if (permissions.contains('printers.view')) service.printers(),
        if (permissions.contains('printing.view')) service.jobs(),
      ]);
      var index = 0;
      printers = permissions.contains('printers.view') ? result[index++] as List<Map<String, dynamic>> : [];
      jobs = permissions.contains('printing.view') ? result[index] as List<Map<String, dynamic>> : [];
      loaded = true;
    } catch (e) { error = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }
  Future<void> register({required String branchId, required String name, required String connection, required String width, required String purpose, required String address, required String device}) async {
    setBusy(true); error = null;
    try { await service.registerPrinter(branchId: branchId, name: name, connectionType: connection, paperWidth: width, purpose: purpose, address: address, deviceIdentifier: device); await load(); }
    catch (e) { error = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }
  Future<void> retry(String id) async {
    setBusy(true); error = null;
    try { await service.retry(id); await load(); }
    catch (e) { error = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }
}
