import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:urban_byte/models/inventory_item.dart';
import '../../../services/report_service.dart';
import '../../../services/inventory_service.dart';

class FinancialReportsView extends StatefulWidget {
  const FinancialReportsView({super.key});
  @override
  State<FinancialReportsView> createState() => _FinancialReportsViewState();
}

class _FinancialReportsViewState extends State<FinancialReportsView> {
  final _reports = ReportService();
  final _inventory = InventoryService();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String? _branchId;
  List<RestaurantBranch> _branches = [];
  Map<String, dynamic>? _financial;
  Map<String, dynamic>? _analytics;
  bool _loading = true;
  String? _error;

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _money(dynamic value) =>
      'PKR ${value == null ? '—' : (double.tryParse(value.toString()) ?? 0).toStringAsFixed(2)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await _inventory.branches();
      final results = await Future.wait([
        _reports.financial(
            from: _date(_from), to: _date(_to), branchId: _branchId),
        _reports.analytics(
            from: _date(_from), to: _date(_to), branchId: _branchId),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _financial = results[0];
        _analytics = results[1];
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
        context: context,
        initialDate: start ? _from : _to,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (picked == null) return;
    setState(() {
      if (start) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
    _load();
  }

  Widget _metric(String title, dynamic value, {bool prominent = false}) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(_money(value),
                style: prominent
                    ? Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)
                    : Theme.of(context).textTheme.titleMedium),
          ])));

  @override
  Widget build(BuildContext context) {
    final f = _financial ?? {};
    final collections =
        Map<String, dynamic>.from(f['collections'] as Map? ?? {});
    final expenses =
        Map<String, dynamic>.from(f['approvedExpenses'] as Map? ?? {});
    final purchases = Map<String, dynamic>.from(f['purchases'] as Map? ?? {});
    final cash = Map<String, dynamic>.from(f['cashFlow'] as Map? ?? {});
    final profit = Map<String, dynamic>.from(f['profitability'] as Map? ?? {});
    final notes = Map<String, dynamic>.from(f['accountingNotes'] as Map? ?? {});
    final analytics = _analytics ?? {};
    final days = analytics['dailySales'] as List? ?? [];
    final products = analytics['bestSellingProducts'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Reports'), actions: [
        IconButton(
            tooltip: 'Copy CSV for Excel',
            onPressed: _loading || _financial == null ? null : _copyCsv,
            icon: const Icon(Icons.file_download_outlined)),
        IconButton(
            onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))
      ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(children: [
              DropdownButtonFormField<String>(
                  value: _branchId,
                  decoration: const InputDecoration(
                      labelText: 'All branches / Select branch'),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('All branches')),
                    ..._branches.map((b) =>
                        DropdownMenuItem(value: b.id, child: Text(b.name)))
                  ],
                  onChanged: (v) {
                    setState(() => _branchId = v);
                    _load();
                  }),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _pickDate(true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text('From ${_date(_from)}'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _pickDate(false),
                        icon: const Icon(Icons.event),
                        label: Text('To ${_date(_to)}'))),
              ])
            ])),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                      onPressed: _load,
                                      child: const Text('Retry'))
                                ])))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              Text('Financial summary · PKR',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount:
                                      MediaQuery.sizeOf(context).width > 700
                                          ? 3
                                          : 2,
                                  childAspectRatio: 1.8,
                                  children: [
                                    _metric('Verified collections',
                                        collections['total'],
                                        prominent: true),
                                    _metric(
                                        'Approved expenses', expenses['total']),
                                    _metric('Received purchases',
                                        purchases['receivedTotal']),
                                    _metric('Cash net movement',
                                        cash['netCashMovement']),
                                    _metric(
                                        'Gross profit', profit['grossProfit'],
                                        prominent: true),
                                    _metric('Net profit', profit['netProfit'],
                                        prominent: true),
                                  ]),
                              Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Profitability status: ${profit['status'] ?? 'unknown'}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium),
                                            Text(
                                                'Completed orders: ${profit['completedOrders'] ?? 0}'),
                                            Text(
                                                'Missing recipe cost lines: ${profit['missingCostLines'] ?? 0}'),
                                            if (notes['warning'] != null)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8),
                                                  child: Text(
                                                      notes['warning']
                                                          .toString(),
                                                      style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .error))),
                                          ]))),
                              Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Cash movement',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium),
                                            _line('Cash collections',
                                                cash['cashCollections']),
                                            _line('Cash expenses',
                                                cash['cashExpenses']),
                                            _line('Cash supplier payments',
                                                cash['cashSupplierPayments']),
                                            _line('Net cash movement',
                                                cash['netCashMovement']),
                                          ]))),
                              Text('Daily sales',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              if (days.isEmpty)
                                const ListTile(
                                    title: Text(
                                        'No completed sales in this period.')),
                              ...days.map((d) => ListTile(
                                  dense: true,
                                  title: Text(d['date'].toString()),
                                  subtitle:
                                      Text('${d['orders']} completed orders'),
                                  trailing: Text(_money(d['revenue'])))),
                              const SizedBox(height: 8),
                              Text('Best-selling products',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              if (products.isEmpty)
                                const ListTile(
                                    title: Text('No product sales found.')),
                              ...products.take(10).map((p) => ListTile(
                                  dense: true,
                                  title: Text(p['productName'].toString()),
                                  subtitle: Text('Quantity: ${p['quantity']}'),
                                  trailing: Text(_money(p['revenue'])))),
                            ]))),
      ]),
    );
  }

  Future<void> _copyCsv() async {
    final f = _financial ?? {};
    final collections =
        Map<String, dynamic>.from(f['collections'] as Map? ?? {});
    final expenses =
        Map<String, dynamic>.from(f['approvedExpenses'] as Map? ?? {});
    final purchases = Map<String, dynamic>.from(f['purchases'] as Map? ?? {});
    final cash = Map<String, dynamic>.from(f['cashFlow'] as Map? ?? {});
    final profit = Map<String, dynamic>.from(f['profitability'] as Map? ?? {});
    final rows = <List<String>>[
      ['Urban Byte Financial Report'],
      [
        'From',
        _date(_from),
        'To',
        _date(_to),
        'Branch',
        _branchId ?? 'All branches'
      ],
      ['Metric', 'Amount (PKR)'],
      ['Verified collections', '${collections['total'] ?? 0}'],
      ['Approved expenses', '${expenses['total'] ?? 0}'],
      ['Received purchases', '${purchases['receivedTotal'] ?? 0}'],
      ['Cash collections', '${cash['cashCollections'] ?? 0}'],
      ['Cash expenses', '${cash['cashExpenses'] ?? 0}'],
      ['Cash supplier payments', '${cash['cashSupplierPayments'] ?? 0}'],
      ['Net cash movement', '${cash['netCashMovement'] ?? 0}'],
      ['Gross profit', '${profit['grossProfit'] ?? 0}'],
      ['Net profit', '${profit['netProfit'] ?? 0}'],
      ['Profitability status', '${profit['status'] ?? 'unknown'}'],
    ];
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    final csv = rows.map((row) => row.map(cell).join(',')).join('\r\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('CSV copied. Paste it into Excel or Google Sheets.')));
  }

  Widget _line(String label, dynamic value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label),
        Text(_money(value), style: const TextStyle(fontWeight: FontWeight.w600))
      ]));
}
