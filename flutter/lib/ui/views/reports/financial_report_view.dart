import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/financial_report_service.dart';

class FinancialReportView extends StackedView<FinancialReportViewModel> {
  const FinancialReportView({super.key});
  @override
  FinancialReportViewModel viewModelBuilder(BuildContext context) =>
      FinancialReportViewModel(locator<FinancialReportService>());
  @override
  Widget builder(
          BuildContext context, FinancialReportViewModel vm, Widget? child) =>
      Scaffold(
        appBar: AppBar(title: const Text('Financial Dashboard'), actions: [
          IconButton(onPressed: vm.loadAll, icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
                child: TextFormField(
                    initialValue: vm.from,
                    decoration: const InputDecoration(
                        labelText: 'From (YYYY-MM-DD)',
                        border: OutlineInputBorder()),
                    onChanged: vm.setFrom)),
            const SizedBox(width: 10),
            Expanded(
                child: TextFormField(
                    initialValue: vm.to,
                    decoration: const InputDecoration(
                        labelText: 'To (YYYY-MM-DD)',
                        border: OutlineInputBorder()),
                    onChanged: vm.setTo))
          ]),
          const SizedBox(height: 10),
          TextField(
              decoration: const InputDecoration(
                  labelText: 'Branch ID (optional)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onChanged: vm.setBranch),
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: vm.loadAll,
              icon: const Icon(Icons.assessment),
              label: const Text('Generate report')),
          const SizedBox(height: 12),
          Text('Export Center', style: Theme.of(context).textTheme.titleMedium),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: vm.exportBusy ? null : () => vm.exportReport('financial', 'pdf'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Financial PDF')),
            OutlinedButton.icon(
                onPressed: vm.exportBusy ? null : () => vm.exportReport('financial', 'csv'),
                icon: const Icon(Icons.table_view),
                label: const Text('Financial Excel/CSV')),
            OutlinedButton.icon(
                onPressed: vm.exportBusy ? null : () => vm.exportReport('analytics', 'pdf'),
                icon: const Icon(Icons.analytics),
                label: const Text('Analytics PDF')),
            OutlinedButton.icon(
                onPressed: vm.exportBusy ? null : () => vm.exportReport('analytics', 'csv'),
                icon: const Icon(Icons.grid_on),
                label: const Text('Analytics Excel/CSV')),
          ]),
          if (vm.exportBusy) const LinearProgressIndicator(),
          if (vm.exportMessage != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(vm.exportMessage!)),
          if (vm.errorr != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child:
                    Text(vm.errorr!, style: const TextStyle(color: Colors.red))),
          if (vm.isBusy) const LinearProgressIndicator(),
          if (vm.data != null) ...[
            const SizedBox(height: 18),
            Text('Collections', style: Theme.of(context).textTheme.titleLarge),
            _MetricCard(
                'Verified collections',
                'PKR ${_money(vm.data!['collections']?['total'])}',
                Icons.payments),
            _MetricCard(
                'Approved expenses',
                'PKR ${_money(vm.data!['approvedExpenses']?['total'])}',
                Icons.receipt_long),
            _MetricCard(
                'Received purchases',
                'PKR ${_money(vm.data!['purchases']?['receivedTotal'])}',
                Icons.inventory_2),
            _MetricCard(
                'Supplier payments',
                'PKR ${_money(vm.data!['supplierPayments']?['total'])}',
                Icons.account_balance_wallet),
            _MetricCard(
                'Supplier outstanding',
                'PKR ${_money(vm.data!['purchases']?['supplierOutstanding'])}',
                Icons.pending_actions),
            const SizedBox(height: 12),
            Text('Cash Flow', style: Theme.of(context).textTheme.titleLarge),
            _MetricCard(
                'Cash collections',
                'PKR ${_money(vm.data!['cashFlow']?['cashCollections'])}',
                Icons.south_west),
            _MetricCard(
                'Cash expenses',
                'PKR ${_money(vm.data!['cashFlow']?['cashExpenses'])}',
                Icons.north_east),
            _MetricCard(
                'Cash supplier payments',
                'PKR ${_money(vm.data!['cashFlow']?['cashSupplierPayments'])}',
                Icons.store),
            _MetricCard(
                'Net cash movement',
                'PKR ${_money(vm.data!['cashFlow']?['netCashMovement'])}',
                Icons.account_balance),
            const SizedBox(height: 12),
            Text('Profitability',
                style: Theme.of(context).textTheme.titleLarge),
            _MetricCard(
                'Completed-order revenue',
                'PKR ${_money(vm.data!['profitability']?['salesRevenue'])}',
                Icons.point_of_sale),
            _MetricCard(
                'Estimated recipe COGS',
                'PKR ${_money(vm.data!['profitability']?['estimatedCogs'])}',
                Icons.restaurant),
            _MetricCard(
                'Gross profit',
                vm.data!['profitability']?['grossProfit'] == null
                    ? 'Incomplete'
                    : 'PKR ${_money(vm.data!['profitability']?['grossProfit'])}',
                Icons.trending_up),
            _MetricCard(
                'Net profit',
                vm.data!['profitability']?['netProfit'] == null
                    ? 'Incomplete'
                    : 'PKR ${_money(vm.data!['profitability']?['netProfit'])}',
                Icons.account_balance),
            if ((vm.data!['profitability']?['status'] ?? 'incomplete') !=
                'complete')
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                          'Profit calculation incomplete: ${vm.data!['profitability']?['missingCostLines'] ?? 0} order lines need valid recipe costs. Receive ingredients with unit costs, configure recipes and complete orders with stock auto-deduction enabled.'))),
            const SizedBox(height: 12),
            Text('Product Profitability',
                style: Theme.of(context).textTheme.titleLarge),
            ...((vm.data!['productProfitability'] as List? ?? []).map((item) =>
                Card(
                    child: ListTile(
                        title:
                            Text(item['productName']?.toString() ?? 'Product'),
                        subtitle: Text(
                            'Qty: ${item['quantity']} • Revenue: PKR ${item['revenue']} • COGS: ${item['cogs'] ?? 'Incomplete'}'),
                        trailing: Text(
                            item['grossProfit'] == null
                                ? 'Incomplete'
                                : 'PKR ${item['grossProfit']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)))))),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(vm.data!['accountingNotes']?['warning'] ??
                        'Profit uses completed orders, estimated recipe costs and approved expenses.'))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Restaurant Analytics',
                  style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                  onPressed: vm.loadAnalytics, icon: const Icon(Icons.refresh))
            ]),
            if (vm.analyticsError != null)
              Text(vm.analyticsError!,
                  style: const TextStyle(color: Colors.red)),
            if (vm.analyticsBusy) const LinearProgressIndicator(),
            if (vm.analytics != null) ...[
              _Bars(
                  title: 'Daily completed-order sales',
                  items: (vm.analytics!['dailySales'] as List? ?? [])
                      .map((e) => {
                            'label': e['date'].toString(),
                            'value':
                                double.tryParse(e['revenue'].toString()) ?? 0
                          })
                      .toList()),
              _Bars(
                  title: 'Best-selling products (quantity)',
                  items: (vm.analytics!['bestSellingProducts'] as List? ?? [])
                      .map((e) => {
                            'label': e['productName'].toString(),
                            'value':
                                double.tryParse(e['quantity'].toString()) ?? 0
                          })
                      .toList()),
              _Bars(
                  title: 'Highest revenue products',
                  items: (vm.analytics!['highestRevenueProducts'] as List? ??
                          [])
                      .map((e) => {
                            'label': e['productName'].toString(),
                            'value':
                                double.tryParse(e['revenue'].toString()) ?? 0
                          })
                      .toList()),
              Card(
                  child: ListTile(
                      title: const Text('Recorded wastage'),
                      subtitle: Text(
                          'Quantity: ${vm.analytics!['wastage']?['totalQuantity']}'),
                      trailing: Text(vm.analytics!['wastage']
                                  ?['estimatedCost'] ==
                              null
                          ? 'Cost incomplete'
                          : 'PKR ${vm.analytics!['wastage']?['estimatedCost']}'))),
              _Bars(
                  title: 'Lowest-margin products (%)',
                  items: (vm.analytics!['lowestMarginProducts'] as List? ?? [])
                      .map((e) => {
                            'label': e['productName'].toString(),
                            'value': double.tryParse(
                                    e['marginPercent'].toString()) ??
                                0
                          })
                      .toList()),
              Text('Branch comparison',
                  style: Theme.of(context).textTheme.titleMedium),
              ...((vm.analytics!['branchComparison'] as List? ?? []).map((b) =>
                  Card(
                      child: ListTile(
                          title: Text(b['branchName']?.toString() ?? 'Branch'),
                          subtitle: Text(
                              'Orders: ${b['orders']} • Revenue: PKR ${b['revenue']}'),
                          trailing: Text(b['grossProfit'] == null
                              ? 'COGS incomplete'
                              : 'Profit: PKR ${b['grossProfit']}')))))
            ],
          ]
        ]),
      );
  static String _money(dynamic value) =>
      (double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold))));
}

class _Bars extends StatelessWidget {
  const _Bars({required this.title, required this.items});
  final String title;
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(
        0, (m, e) => (e['value'] as double) > m ? e['value'] as double : m);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...items.map((e) {
                final value = e['value'] as double;
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                          width: 105,
                          child: Text(e['label'].toString(),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(
                          child: LinearProgressIndicator(
                              value: maxValue <= 0 ? 0 : value / maxValue,
                              minHeight: 9)),
                      const SizedBox(width: 8),
                      Text(value.toStringAsFixed(0))
                    ]));
              })
            ])));
  }
}

class FinancialReportViewModel extends BaseViewModel {
  FinancialReportViewModel(this._service) {
    final now = DateTime.now();
    from = _date(now);
    to = from;
    loadAll();
  }
  final FinancialReportService _service;
  late String from, to;
  String? branchId, errorr, analyticsError;
  Map<String, dynamic>? data, analytics;
  bool analyticsBusy = false;
  bool exportBusy = false;
  String? exportMessage;

  Future<void> exportReport(String report, String format) async {
    exportBusy = true;
    exportMessage = null;
    notifyListeners();
    try {
      final bytes = await _service.exportReport(
          report: report, format: format, from: from, to: to,
          branchId: branchId);
      final directory = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${directory.path}/urban_byte_${report}_${stamp}.${format == 'csv' ? 'csv' : 'pdf'}');
      await file.writeAsBytes(bytes, flush: true);
      // await Share.shareXFiles([XFile(file.path)],
      //     text: 'Urban Byte ${report} report (${from} to ${to})');
      exportMessage = 'Report prepared. Choose Save or Share in the system sheet.';
    } catch (e) {
      exportMessage = e.toString();
    } finally {
      exportBusy = false;
      notifyListeners();
    }
  }
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  void setFrom(String v) {
    from = v;
  }

  void setTo(String v) {
    to = v;
  }

  void setBranch(String v) {
    branchId = v;
  }

  Future<void> loadAll() async {
    await Future.wait([load(), loadAnalytics()]);
  }

  Future<void> load() async {
    setBusy(true);
    errorr = null;
    try {
      data = await _service.load(from: from, to: to, branchId: branchId);
    } catch (e) {
      errorr = e.toString();
    }
    setBusy(false);
    notifyListeners();
  }

  Future<void> loadAnalytics() async {
    analyticsBusy = true;
    analyticsError = null;
    notifyListeners();
    try {
      analytics =
          await _service.loadAnalytics(from: from, to: to, branchId: branchId);
    } catch (e) {
      analyticsError = e.toString();
    }
    analyticsBusy = false;
    notifyListeners();
  }
}
