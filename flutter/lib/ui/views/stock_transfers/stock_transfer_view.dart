import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../models/inventory_item.dart';
import '../../../services/inventory_service.dart';
import '../../../services/stock_transfer_service.dart';
import 'stock_transfer_viewmodel.dart';

class StockTransferView extends StackedView<StockTransferViewModel> {
  const StockTransferView({super.key});
  @override
  StockTransferViewModel viewModelBuilder(BuildContext context) =>
      StockTransferViewModel(locator<StockTransferService>(), locator<InventoryService>());
  @override
  void onViewModelReady(StockTransferViewModel model) => model.initialise();

  @override
  Widget builder(BuildContext context, StockTransferViewModel model, Widget? child) => Scaffold(
    appBar: AppBar(title: const Text('Inter-Branch Stock Transfers'), actions: [
      IconButton(onPressed: model.isBusy ? null : model.reload, icon: const Icon(Icons.refresh)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: model.isBusy || model.branches.length < 2 || model.catalog.isEmpty ? null : () => _create(context, model),
      icon: const Icon(Icons.add), label: const Text('New transfer')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: DropdownButtonFormField<String?>(
          value: model.branchId,
          decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder(), isDense: true),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('All authorized')), ...model.branches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name)))],
          onChanged: model.isBusy ? null : (v) => model.filter(branch: v, newStatus: model.status))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String?>(
          value: model.status,
          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('All statuses')),
            DropdownMenuItem<String?>(value: 'requested', child: Text('Requested')),
            DropdownMenuItem<String?>(value: 'in_transit', child: Text('In transit')),
            DropdownMenuItem<String?>(value: 'partially_received', child: Text('Partial')),
            DropdownMenuItem<String?>(value: 'received', child: Text('Received')),
            DropdownMenuItem<String?>(value: 'rejected', child: Text('Rejected')),
          ],
          onChanged: model.isBusy ? null : (v) => model.filter(branch: model.branchId, newStatus: v))),
      ])),
      if (model.errorMessage.isNotEmpty) Material(color: Theme.of(context).colorScheme.errorContainer, child: ListTile(title: Text(model.errorMessage))),
      Expanded(child: model.isBusy && model.branches.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: model.reload, child: model.transfers.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No stock transfers found.'))])
          : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), itemCount: model.transfers.length,
              itemBuilder: (context, index) => _card(context, model, model.transfers[index])))),
    ]),
  );

  Widget _card(BuildContext context, StockTransferViewModel model, Map<String, dynamic> t) {
    final lines = (t['items'] as List? ?? const []).whereType<Map>().toList();
    final source = t['sourceBranch'] is Map ? (t['sourceBranch'] as Map)['name'] : 'Source';
    final dest = t['destinationBranch'] is Map ? (t['destinationBranch'] as Map)['name'] : 'Destination';
    final status = t['status']?.toString() ?? 'unknown';
    final id = '\${t['id']}';
    return Card(child: ExpansionTile(
      leading: const CircleAvatar(child: Icon(Icons.swap_horiz)),
      title: Text('\${t['reference'] ?? 'Transfer #$id'}'),
      subtitle: Text('$source → $dest\\n\${status.replaceAll('_', ' ').toUpperCase()}'),
      children: [
        ...lines.map((line) {
          final item = line['inventoryItem'] is Map ? line['inventoryItem'] as Map : const {};
          return ListTile(dense: true, title: Text(item['name']?.toString() ?? 'Item #\${line['inventoryItemId']}'),
            subtitle: Text('Requested: \${line['requestedQuantity']} · Received: \${line['receivedQuantity']} \${item['baseUnit'] ?? ''}'));
        }),
        if (t['note'] != null) ListTile(title: const Text('Note'), subtitle: Text('\${t['note']}')),
        if (status == 'requested') Wrap(alignment: WrapAlignment.end, children: [
          TextButton(onPressed: model.isBusy ? null : () => _reject(context, model, id), child: const Text('Reject')),
          FilledButton(onPressed: model.isBusy ? null : () => _confirm(context, () => model.approve(id)), child: const Text('Approve & dispatch')),
        ]),
        if (status == 'in_transit' || status == 'partially_received')
          Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.all(8),
            child: FilledButton(onPressed: model.isBusy ? null : () => _receive(context, model, id, lines), child: const Text('Receive stock')))),
      ],
    ));
  }

  Future<void> _confirm(BuildContext context, Future<void> Function() action) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Approve and dispatch?'),
      content: const Text('This deducts requested quantities from source branch stock.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm'))]));
    if (yes == true) await action();
  }

  Future<void> _reject(BuildContext context, StockTransferViewModel model, String id) async {
    final note = TextEditingController();
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reject transfer'), content: TextField(controller: note, decoration: const InputDecoration(labelText: 'Reason (optional)')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject'))]));
    if (yes == true) await model.reject(id, note: note.text);
    note.dispose();
  }

  Future<void> _receive(BuildContext context, StockTransferViewModel model, String id, List<Map> lines) async {
    final controllers = <String, TextEditingController>{};
    for (final line in lines) {
      final remaining = (double.tryParse('\${line['requestedQuantity']}') ?? 0) - (double.tryParse('\${line['receivedQuantity']}') ?? 0);
      if (remaining > 0) controllers['\${line['inventoryItemId']}'] = TextEditingController(text: remaining.toString());
    }
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Receive dispatched stock'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: controllers.entries.map((entry) {
        final line = lines.firstWhere((e) => '\${e['inventoryItemId']}' == entry.key);
        final item = line['inventoryItem'] is Map ? line['inventoryItem'] as Map : const {};
        final remaining = (double.tryParse('\${line['requestedQuantity']}') ?? 0) - (double.tryParse('\${line['receivedQuantity']}') ?? 0);
        return TextField(controller: entry.value, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: '\${item['name'] ?? 'Item'} · remaining $remaining'));
      }).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record receiving'))]));
    if (yes == true) {
      final items = <Map<String, dynamic>>[];
      var valid = true;
      for (final e in controllers.entries) {
        final qty = double.tryParse(e.value.text);
        if (qty == null || qty <= 0) { valid = false; break; }
        items.add({'inventoryItemId': int.parse(e.key), 'quantity': qty});
      }
      if (valid && items.isNotEmpty) { await model.receive(id, items); }
      else { model.errorMessage = 'Enter positive received quantities.'; model.notifyListeners(); }
    }
    for (final c in controllers.values) { c.dispose(); }
  }

  Future<void> _create(BuildContext context, StockTransferViewModel model) async {
    String? source = model.branchId ?? model.branches.first.id;
    String? destination = model.branches.firstWhere((b) => b.id != source).id;
    String? itemId = model.catalog.first.id;
    final qty = TextEditingController(text: '1'), note = TextEditingController();
    final form = GlobalKey<FormState>();
    final yes = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: const Text('New stock transfer'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: source, decoration: const InputDecoration(labelText: 'Source branch'),
          items: model.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
          onChanged: (v) => set(() { source = v; if (destination == source) destination = model.branches.firstWhere((b) => b.id != source).id; })),
        DropdownButtonFormField<String>(value: destination, decoration: const InputDecoration(labelText: 'Destination branch'),
          items: model.branches.where((b) => b.id != source).map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
          onChanged: (v) => set(() => destination = v)),
        DropdownButtonFormField<String>(value: itemId, decoration: const InputDecoration(labelText: 'Inventory item'),
          items: model.catalog.map((InventoryItem i) => DropdownMenuItem(value: i.id, child: Text('\${i.name} (\${i.unit})'))).toList(),
          onChanged: (v) => set(() => itemId = v)),
        TextFormField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity'),
          validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n <= 0 ? 'Enter positive quantity' : null; }),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (form.currentState?.validate() == true && source != null && destination != null && itemId != null) Navigator.pop(ctx, true); }, child: const Text('Submit'))])));
    if (yes == true && source != null && destination != null && itemId != null) {
      await model.create(sourceBranchId: source!, destinationBranchId: destination!,
        items: [{'inventoryItemId': int.parse(itemId!), 'quantity': double.parse(qty.text)}], note: note.text);
    }
    qty.dispose(); note.dispose();
  }
}
