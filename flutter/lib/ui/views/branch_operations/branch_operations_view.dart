import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/branch_operations_service.dart';
import '../../../services/inventory_service.dart';
import 'branch_operations_viewmodel.dart';

class BranchOperationsView extends StackedView<BranchOperationsViewModel> {
  const BranchOperationsView({super.key});

  @override
  BranchOperationsViewModel viewModelBuilder(BuildContext context) =>
      BranchOperationsViewModel(locator<BranchOperationsService>(), locator<InventoryService>());

  @override
  void onViewModelReady(BranchOperationsViewModel model) => model.initialise();

  String _money(dynamic value) =>
      'PKR ${(double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2)}';

  @override
  Widget builder(BuildContext context, BranchOperationsViewModel model, Widget? child) {
    final summary = Map<String, dynamic>.from(model.purchases['summary'] as Map? ?? {});
    final branchRows = (model.purchases['byBranch'] as List? ?? const []).whereType<Map>().toList();
    final supplierRows = (model.purchases['bySupplier'] as List? ?? const []).whereType<Map>().toList();
    final itemRows = (model.purchases['costByBranchAndItem'] as List? ?? const []).whereType<Map>().toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Branch Operations'), actions: [
        IconButton(onPressed: model.isBusy ? null : model.loadAll, icon: const Icon(Icons.refresh)),
      ]),
      body: model.isBusy && model.branches.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: model.loadAll,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                DropdownButtonFormField<String?>(
                  value: model.branchId,
                  decoration: const InputDecoration(labelText: 'Branch scope', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All authorized branches')),
                    ...model.branches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name))),
                  ],
                  onChanged: model.isBusy ? null : model.selectBranch,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: model.isBusy ? null : () async {
                      final range = await showDateRangePicker(
                        context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: DateTimeRange(start: model.from, end: model.to),
                      );
                      if (range != null) await model.selectRange(range.start, range.end);
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text('${model.fromDate} → ${model.toDate}'),
                  )),
                ]),
                if (model.errorMessage.isNotEmpty)
                  Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(
                    padding: const EdgeInsets.all(12), child: Text(model.errorMessage))),
                const SizedBox(height: 12),
                Text('Purchase analytics', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _metric(context, 'Received purchases', _money(summary['receivedPurchaseTotal'])),
                  _metric(context, 'Paid amount', _money(summary['paidForSelectedPurchases'])),
                  _metric(context, 'Outstanding', _money(summary['outstandingForSelectedPurchases'])),
                  _metric(context, 'Purchase count', '${summary['purchaseCount'] ?? 0}'),
                ]),
                const SizedBox(height: 18),
                Text('Purchases by branch', style: Theme.of(context).textTheme.titleMedium),
                if (branchRows.isEmpty) const ListTile(title: Text('No received purchases in this period.')),
                ...branchRows.map((row) => Card(child: ListTile(
                  title: Text(row['branchName']?.toString() ?? 'Branch'),
                  subtitle: Text('Purchases: ${row['purchaseCount'] ?? 0} · Paid: ${_money(row['paid'])} · Due: ${_money(row['outstanding'])}'),
                  trailing: Text(_money(row['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
                ))),
                const SizedBox(height: 16),
                Text('Supplier outstanding', style: Theme.of(context).textTheme.titleMedium),
                if (supplierRows.isEmpty) const ListTile(title: Text('No supplier purchases found.')),
                ...supplierRows.map((row) => Card(child: ListTile(
                  title: Text(row['supplierName']?.toString() ?? 'Supplier'),
                  subtitle: Text('Paid: ${_money(row['paid'])} · Purchases: ${row['purchaseCount'] ?? 0}'),
                  trailing: Text(_money(row['outstanding'])),
                ))),
                const SizedBox(height: 16),
                Text('Item cost by branch', style: Theme.of(context).textTheme.titleMedium),
                if (itemRows.isEmpty) const ListTile(title: Text('No item cost comparison available.')),
                ...itemRows.map((row) => Card(child: ListTile(
                  title: Text(row['itemName']?.toString() ?? 'Inventory item'),
                  subtitle: Text('${row['branchName'] ?? 'Branch'} · Qty: ${row['quantity'] ?? 0} ${row['unit'] ?? ''}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_money(row['totalCost'])),
                    Text('Unit: ${_money(row['averageUnitCost'])}', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ))),
                const Divider(height: 32),
                Text('Audit history', style: Theme.of(context).textTheme.titleLarge),
                if (model.auditItems.isEmpty) const ListTile(title: Text('No audit events found for this period.')),
                ...model.auditItems.map((event) {
                  final actor = event['actor'] is Map ? (event['actor'] as Map)['name'] : null;
                  final before = event['beforeData'];
                  final after = event['afterData'];
                  return Card(child: ExpansionTile(
                    leading: const Icon(Icons.history),
                    title: Text(event['action']?.toString() ?? 'Operation'),
                    subtitle: Text('${event['entityType'] ?? 'Record'} #${event['entityId'] ?? ''} · ${actor ?? 'System'} · ${event['createdAt'] ?? ''}'),
                    children: [
                      if (before != null) ListTile(title: const Text('Before'), subtitle: Text(before.toString())),
                      if (after != null) ListTile(title: const Text('After'), subtitle: Text(after.toString())),
                      if (event['metadata'] != null) ListTile(title: const Text('Details'), subtitle: Text(event['metadata'].toString())),
                    ],
                  ));
                }),
              ]),
            ),
    );
  }

  Widget _metric(BuildContext context, String title, String value) => SizedBox(
    width: 160, child: Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ]),
    )),
  );
}
