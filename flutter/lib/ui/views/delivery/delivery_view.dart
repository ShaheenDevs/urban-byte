import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/operations_service.dart';

class DeliveryView extends StackedView<DeliveryViewModel> {
  const DeliveryView({super.key, required this.permissions});
  final Set<String> permissions;
  @override
  DeliveryViewModel viewModelBuilder(BuildContext context) =>
      DeliveryViewModel(locator<OperationsService>(), permissions)..load();

  @override
  Widget builder(BuildContext context, DeliveryViewModel vm, Widget? child) {
    final manager = vm.canManage;
    return Scaffold(
      appBar: AppBar(
        title: Text(manager ? 'Delivery Management' : 'My deliveries'),
        actions: [IconButton(onPressed: vm.isBusy ? null : vm.load, icon: const Icon(Icons.refresh))],
      ),
      body: vm.isBusy && !vm.loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: vm.load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (vm.loadingError != null)
                  Text(vm.loadingError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                Wrap(spacing: 8, children: [
                  _count('Assigned', vm.count('assigned')),
                  _count('Picked up', vm.count('picked_up')),
                  _count('On route', vm.count('out_for_delivery')),
                  _count('Delivered', vm.count('delivered')),
                ]),

                if (vm.performance.isNotEmpty) Card(child: ListTile(
                  title: const Text('Today rider performance'),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Delivered: ' + '${vm.performance['delivered'] ?? 0}' + ' · Cancelled: ' + '${vm.performance['cancelled'] ?? 0}' + ' · Pending: ' + '${vm.performance['pending'] ?? 0}' + ' · Success: ' + '${vm.performance['deliverySuccessRate'] ?? 0}%' + ' · Avg minutes: ' + '${vm.performance['averageDeliveryMinutes'] ?? '-'}'),
                    ...((vm.performance['riders'] as List? ?? []).map((r) => Text('Rider ' + '${r['riderId']}: ${r['delivered']}/${r['total']} delivered · COD PKR ${r['codAmount']}'))),
                  ]),
                )),
                if (vm.codReport.isNotEmpty) Card(child: ListTile(
                  title: const Text('Today COD collection'),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('PKR ' + '${vm.codReport['totalCollected'] ?? 0}' + ' · Orders: ' + '${vm.codReport['orders'] ?? 0}'),
                    ...((vm.codReport['byRider'] as List? ?? []).map((r) => Text('${r['riderName'] ?? 'Rider'}: Collected PKR ${r['amount'] ?? 0} · Approved PKR ${r['settledAmount'] ?? 0} · Pending approval PKR ${r['pendingAmount'] ?? 0} · Not handed over PKR ${r['unsettledAmount'] ?? 0}'))),
                  ]),
                )),
                if (!manager && vm.codPendingByBranch.isNotEmpty) ...[
                  Text('COD cash handover', style: Theme.of(context).textTheme.titleLarge),
                  ...vm.codPendingByBranch.entries.map((entry) => Card(child: ListTile(
                    title: Text('Branch ${entry.key} · Pending cash PKR ${entry.value.toStringAsFixed(2)}'),
                    subtitle: const Text('Submit collected COD cash to the cashier for manager approval.'),
                    trailing: FilledButton(
                      onPressed: vm.isBusy ? null : () => vm.submitCash(context, entry.key, entry.value),
                      child: const Text('Hand over'),
                    ),
                  ))),
                ],
                if (manager && vm.pendingCodSettlements.isNotEmpty) ...[
                  Text('COD handovers awaiting approval', style: Theme.of(context).textTheme.titleLarge),
                  ...vm.pendingCodSettlements.map((settlement) => Card(child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${settlement['rider']?['name'] ?? 'Rider'} · ${settlement['settlementDate'] ?? ''}', style: Theme.of(context).textTheme.titleMedium),
                      Text('Expected: PKR ${settlement['expectedAmount']} · Handed: PKR ${settlement['handedAmount']} · Variance: PKR ${settlement['variance']}'),
                      if ((settlement['riderNote'] ?? '').toString().isNotEmpty) Text('Rider note: ${settlement['riderNote']}'),
                      Wrap(spacing: 8, children: [
                        FilledButton(onPressed: vm.isBusy ? null : () => vm.reviewCash(context, '${settlement['id']}', true), child: const Text('Approve')),
                        OutlinedButton(onPressed: vm.isBusy ? null : () => vm.reviewCash(context, '${settlement['id']}', false), child: const Text('Reject')),
                      ]),
                    ]),
                  ))),
                ],
                if (vm.history.isNotEmpty) ...[
                  Text('Recent rider delivery history', style: Theme.of(context).textTheme.titleLarge),
                  ...vm.history.take(10).map((h) {
                    final order = Map<String, dynamic>.from(h['order'] as Map? ?? {});
                    final rider = Map<String, dynamic>.from(h['deliveryUser'] as Map? ?? {});
                    return ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text('${order['orderNumber'] ?? 'Delivery'} · ${order['customerName'] ?? 'Customer'}'),
                      subtitle: Text('${rider['name'] ?? 'Rider'} · ${h['deliveredAt'] ?? ''}'),
                      trailing: Text('PKR ' + '${order['deliveryFee'] ?? 0}'),
                    );
                  }),
                ],
                if (manager) ...[
                  const SizedBox(height: 20),
                  Text('Unassigned delivery orders', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (vm.unassignedOrders.isEmpty)
                    const Card(child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('No unassigned delivery orders'))),
                  ...vm.unassignedOrders.map((order) => _unassignedCard(context, vm, order)),
                  const SizedBox(height: 20),
                  Text('Assigned deliveries', style: Theme.of(context).textTheme.titleLarge),
                ],
                if (vm.assignments.isEmpty)
                  const Card(child: ListTile(leading: Icon(Icons.delivery_dining), title: Text('No delivery assignments'))),
                ...vm.assignments.map((assignment) => _assignmentCard(context, vm, assignment)),
              ]),
            ),
    );
  }

  Widget _unassignedCard(BuildContext context, DeliveryViewModel vm, Map<String, dynamic> order) {
    final id = '${order['id']}';
    final branchId = '${order['branchId']}';
    final drivers = vm.driversFor(branchId);
    final selected = vm.selectedDrivers[id];
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${order['orderNumber'] ?? 'Order #$id'}', style: Theme.of(context).textTheme.titleMedium),
        Text('${order['customerName'] ?? 'Customer'} • ${order['customerPhone'] ?? 'No phone'}'),
        Text('${order['deliveryAddress'] ?? 'No delivery address'}'),
        Text('Total: PKR ${order['grandTotal'] ?? '0.00'}'),
        Text('Delivery fee: PKR ${order['deliveryFee'] ?? 0} · Distance: ${order['deliveryDistanceKm'] ?? 0} km'),
        const SizedBox(height: 8),
        if (drivers.isEmpty)
          const Text('No active Delivery employee is assigned to this branch.')
        else
          DropdownButtonFormField<String>(
            value: drivers.any((d) => d['id'].toString() == selected) ? selected : null,
            decoration: const InputDecoration(labelText: 'Select delivery rider'),
            items: drivers.map((d) => DropdownMenuItem<String>(
              value: d['id'].toString(), child: Text(d['name']?.toString() ?? 'Delivery staff'),
            )).toList(),
            onChanged: vm.isBusy ? null : (value) => vm.selectDriver(id, value),
          ),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(
          onPressed: vm.isBusy || selected == null || drivers.isEmpty ? null : () => vm.assign(id, selected),
          icon: const Icon(Icons.person_add_alt_1), label: const Text('Assign rider'),
        )),
      ]),
    ));
  }

  Widget _assignmentCard(BuildContext context, DeliveryViewModel vm, Map<String, dynamic> a) {
    final order = Map<String, dynamic>.from(a['order'] as Map? ?? {});
    final rider = Map<String, dynamic>.from(a['deliveryUser'] as Map? ?? {});
    final status = '${a['status']}';
    final assignmentId = '${a['id']}';
    final orderId = '${order['id'] ?? a['orderId']}';
    final branchId = '${a['branchId']}';
    final cod = double.tryParse('${a['codAmount'] ?? 0}') ?? 0.0;
    final collected = a['codCollected'] == true;
    final drivers = vm.driversFor(branchId);
    final selected = vm.selectedDrivers[orderId];
    final canReassign = vm.canManage && status == 'assigned';
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${order['orderNumber'] ?? 'Delivery #$assignmentId'}', style: Theme.of(context).textTheme.titleMedium)),
          Chip(label: Text(status.replaceAll('_', ' '))),
        ]),
        Text('${order['customerName'] ?? 'Customer'} • ${order['customerPhone'] ?? 'No phone'}'),
        Text('${order['deliveryAddress'] ?? 'No delivery address'}'),
        Text('Order total: PKR ${order['grandTotal'] ?? '0.00'}'),
        Text('Delivery fee: PKR ${order['deliveryFee'] ?? 0} · Distance: ${order['deliveryDistanceKm'] ?? 0} km'),
        if (vm.canManage) Text('Rider: ${rider['name'] ?? 'Unknown'}'),
        if (cod > 0) Text('COD: PKR ${cod.toStringAsFixed(2)} • ${collected ? 'Collected' : 'Not collected'}'),
        if (canReassign && drivers.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: drivers.any((d) => d['id'].toString() == selected) ? selected : rider['id']?.toString(),
            decoration: const InputDecoration(labelText: 'Change delivery rider'),
            items: drivers.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text(d['name']?.toString() ?? 'Delivery staff'))).toList(),
            onChanged: vm.isBusy ? null : (value) => vm.selectDriver(orderId, value),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: vm.isBusy || selected == null || selected == rider['id']?.toString() ? null : () => vm.assign(orderId, selected),
            icon: const Icon(Icons.swap_horiz), label: const Text('Reassign rider'),
          )),
        ],
        if (!vm.canManage) Wrap(spacing: 8, children: [
          if (status == 'assigned') FilledButton(onPressed: vm.isBusy ? null : () => vm.update(assignmentId, 'picked_up'), child: const Text('Picked up')),
          if (status == 'picked_up') FilledButton(onPressed: vm.isBusy ? null : () => vm.update(assignmentId, 'out_for_delivery'), child: const Text('Start delivery')),
          if (status == 'out_for_delivery') FilledButton.tonal(onPressed: vm.isBusy ? null : () => vm.complete(context, assignmentId, cod > 0 && !collected), child: const Text('Mark delivered')),
        ]),
      ]),
    ));
  }

  Widget _count(String label, int value) => Chip(label: Text('$label: $value'));
}

class DeliveryViewModel extends BaseViewModel {
  DeliveryViewModel(this.api, this.permissions);
  final OperationsService api;
  final Set<String> permissions;
  bool get canManage => permissions.contains('delivery.assign');
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> unassignedOrders = [];
  final Map<String, List<Map<String, dynamic>>> _driversByBranch = {};
  final Map<String, String?> selectedDrivers = {};
  String? loadingError;
  Map<String, dynamic> performance = {};
  Map<String, dynamic> codReport = {};
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> codSettlements = [];
  bool loaded = false;

  List<Map<String, dynamic>> get pendingCodSettlements => codSettlements.where((s) => s['status'] == 'pending_approval').toList();
  Map<String, double> get codPendingByBranch {
    final result = <String, double>{};
    for (final a in assignments) {
      if (a['codCollected'] == true && a['codSettlementId'] == null) {
        final branch = '${a['branchId']}';
        result[branch] = (result[branch] ?? 0) + (double.tryParse('${a['codAmount'] ?? 0}') ?? 0);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> driversFor(String branchId) => _driversByBranch[branchId] ?? [];
  int count(String status) => assignments.where((a) => a['status'] == status).length;
  void selectDriver(String orderId, String? driverId) { selectedDrivers[orderId] = driverId; notifyListeners(); }

  Future<void> load() async {
    setBusy(true); loadingError = null;
    try {
      assignments = await api.deliveryAssignments();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final reports = await Future.wait<dynamic>([
        api.deliveryHistory(),
        api.deliveryPerformance(from: today, to: today),
        api.deliveryCodCollections(from: today, to: today),
      ]);
      history = reports[0] as List<Map<String, dynamic>>;
      performance = Map<String, dynamic>.from(reports[1] as Map);
      codReport = Map<String, dynamic>.from(reports[2] as Map);
      codSettlements = await api.deliveryCodSettlements(status: canManage ? 'pending_approval' : null);
      if (canManage) {
        unassignedOrders = await api.unassignedDeliveryOrders();
        final branchIds = <String>{...assignments.map((a) => '${a['branchId']}'), ...unassignedOrders.map((o) => '${o['branchId']}')};
        _driversByBranch.clear();
        for (final branchId in branchIds) {
          _driversByBranch[branchId] = await api.deliveryDrivers(branchId: branchId);
        }
      } else { unassignedOrders = []; }
      loaded = true;
    } catch (e) { loadingError = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }


  Future<void> submitCash(BuildContext context, String branchId, double expected) async {
    final amount = TextEditingController(text: expected.toStringAsFixed(2));
    final note = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Submit COD cash handover'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Expected COD: PKR ${expected.toStringAsFixed(2)}'),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cash handed over (PKR)')),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
      ],
    ));
    final handed = double.tryParse(amount.text.trim());
    final noteText = note.text;
    amount.dispose(); note.dispose();
    if (result != true) return;
    if (handed == null || handed < 0) { loadingError = 'Enter a valid handed amount.'; notifyListeners(); return; }
    setBusy(true); loadingError = null;
    try { await api.submitDeliveryCodSettlement(branchId: branchId, date: DateTime.now().toIso8601String().substring(0, 10), handedAmount: handed, note: noteText); await load(); }
    catch (e) { loadingError = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }

  Future<void> reviewCash(BuildContext context, String settlementId, bool approve) async {
    final note = TextEditingController();
    if (!approve) {
      final result = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Reject COD handover'),
        content: TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason (required)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Reject')),
        ],
      ));
      if (result != true) { note.dispose(); return; }
      if (note.text.trim().isEmpty) { note.dispose(); loadingError = 'Rejection reason is required.'; notifyListeners(); return; }
    } else {
      final result = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Approve COD handover'),
        content: const Text('Confirm that the handed cash amount has been physically received and counted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Approve')),
        ],
      ));
      if (result != true) { note.dispose(); return; }
    }
    final noteText = note.text; note.dispose();
    setBusy(true); loadingError = null;
    try { await api.reviewDeliveryCodSettlement(settlementId, approve: approve, note: noteText); await load(); }
    catch (e) { loadingError = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }

  Future<void> assign(String orderId, String driverId) async {
    setBusy(true); loadingError = null;
    try { await api.assignDelivery(orderId, driverId); selectedDrivers.remove(orderId); await load(); }
    catch (e) { loadingError = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }

  Future<void> update(String id, String status) async {
    setBusy(true); loadingError = null;
    try { await api.updateDeliveryStatus(id, status); await load(); }
    catch (e) { loadingError = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }

  Future<void> complete(BuildContext context, String id, bool needsCod) async {
    var collected = !needsCod;
    if (needsCod) {
      final answer = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Confirm COD collection'),
        content: const Text('Did you receive the full cash amount from the customer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, collected')),
        ],
      ));
      if (answer != true) return;
      collected = true;
    }
    setBusy(true); loadingError = null;
    try { await api.updateDeliveryStatus(id, 'delivered', codCollected: collected); await load(); }
    catch (e) { loadingError = e.toString(); }
    finally { setBusy(false); notifyListeners(); }
  }
}
