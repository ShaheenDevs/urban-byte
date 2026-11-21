import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/operations_service.dart';

class DeliveryView extends StackedView<DeliveryViewModel> {
  const DeliveryView({super.key, required this.permissions});
  final Set<String> permissions;
  @override
  DeliveryViewModel viewModelBuilder(BuildContext context) => DeliveryViewModel(locator<OperationsService>(), permissions)..load();
  @override
  Widget builder(BuildContext context, DeliveryViewModel vm, Widget? child) => Scaffold(
    appBar: AppBar(title: const Text('My deliveries'), actions: [IconButton(onPressed: vm.isBusy ? null : vm.load, icon: const Icon(Icons.refresh))]),
    body: vm.isBusy && !vm.loaded ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: vm.load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (vm.error != null) Text(vm.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        Wrap(spacing: 8, children: [
          _count('Assigned', vm.count('assigned')),
          _count('Picked up', vm.count('picked_up')),
          _count('On route', vm.count('out_for_delivery')),
          _count('Delivered', vm.count('delivered')),
        ]),
        const SizedBox(height: 16),
        if (vm.assignments.isEmpty) const Card(child: ListTile(leading: Icon(Icons.delivery_dining), title: Text('No delivery assignments'), subtitle: Text('New assigned deliveries will appear here.'))),
        ...vm.assignments.map((a) {
          final order = Map<String, dynamic>.from(a['order'] as Map? ?? {});
          final status = '${a['status']}';
          final cod = Number.tryParse('${a['codAmount'] ?? 0}') ?? 0;
          final collected = a['codCollected'] == true;
          return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${order['orderNumber'] ?? 'Delivery #${a['id']}'}', style: Theme.of(context).textTheme.titleMedium)), Chip(label: Text(status.replaceAll('_',' ')))]),
            Text('${order['customerName'] ?? 'Customer'} • ${order['customerPhone'] ?? 'No phone'}'),
            const SizedBox(height: 6),
            Text('${order['deliveryAddress'] ?? 'No delivery address'}'),
            const SizedBox(height: 6),
            Text('Order total: PKR ${order['grandTotal'] ?? '0.00'}'),
            if (cod > 0) Text('COD: PKR ${cod.toStringAsFixed(2)} • ${collected ? 'Collected' : 'Not collected'}', style: TextStyle(fontWeight: FontWeight.w600, color: collected ? Colors.green : Theme.of(context).colorScheme.error)),
            if (order['notes'] != null && '${order['notes']}'.isNotEmpty) Text('Notes: ${order['notes']}'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (status == 'assigned') FilledButton(onPressed: vm.isBusy ? null : () => vm.update('${a['id']}', 'picked_up'), child: const Text('Picked up')),
              if (status == 'picked_up') FilledButton(onPressed: vm.isBusy ? null : () => vm.update('${a['id']}', 'out_for_delivery'), child: const Text('Start delivery')),
              if (status == 'out_for_delivery' || status == 'picked_up' || status == 'assigned') FilledButton.tonal(onPressed: vm.isBusy ? null : () => vm.complete(context, '${a['id']}', cod > 0 && !collected), child: const Text('Mark delivered')),
            ])
          ])));
        }),
      ]),
    ),
  );
  Widget _count(String label, int value) => Chip(label: Text('$label: $value'));
}

class DeliveryViewModel extends BaseViewModel {
  DeliveryViewModel(this.api, this.permissions);
  final OperationsService api;
  final Set<String> permissions;
  List<Map<String, dynamic>> assignments = [];
  String? error;
  bool loaded = false;
  int count(String status) => assignments.where((a) => a['status'] == status).length;
  Future<void> load() async {
    setBusy(true); error = null;
    try { assignments = await api.deliveryAssignments(); loaded = true; }
    catch (e) { error = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }
  Future<void> update(String id, String status) async {
    setBusy(true); error = null;
    try { await api.updateDeliveryStatus(id, status); await load(); }
    catch (e) { error = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }
  Future<void> complete(BuildContext context, String id, bool needsCod) async {
    var collected = !needsCod;
    if (needsCod) {
      final answer = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Confirm COD collection'),
        content: const Text('Did you receive the full cash amount from the customer?'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, collected'))],
      ));
      if (answer != true) return;
      collected = true;
    }
    setBusy(true); error = null;
    try { await api.updateDeliveryStatus(id, 'delivered', codCollected: collected); await load(); }
    catch (e) { error = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }
}
