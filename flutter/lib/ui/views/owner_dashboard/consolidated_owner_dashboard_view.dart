import 'package:flutter/material.dart';
import '../../../services/report_service.dart';

class ConsolidatedOwnerDashboardView extends StatefulWidget {
  const ConsolidatedOwnerDashboardView({super.key});

  @override
  State<ConsolidatedOwnerDashboardView> createState() =>
      _ConsolidatedOwnerDashboardViewState();
}

class _ConsolidatedOwnerDashboardViewState
    extends State<ConsolidatedOwnerDashboardView> {
  final ReportService _reports = ReportService();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  String _date(DateTime value) =>
      '\${value.year.toString().padLeft(4, '0')}-\${value.month.toString().padLeft(2, '0')}-\${value.day.toString().padLeft(2, '0')}';
  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;
  String _money(dynamic value) => value == null
      ? 'N/A'
      : 'PKR \${_number(value).toStringAsFixed(2)}';

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
      final result = await _reports.consolidated(
        from: _date(_from),
        to: _date(_to),
      );
      if (!mounted) return;
      setState(() {
        _report = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
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

  Widget _metric(BuildContext context, String title, dynamic value,
      {bool prominent = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 7),
            Text(
              value is num ? value.toString() : _money(value),
              style: prominent
                  ? Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )
                  : Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _report ?? {};
    final totals = Map<String, dynamic>.from(data['totals'] as Map? ?? {});
    final branches = (data['branches'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final incomplete = totals['profitabilityStatus'] != 'complete';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner · All Branches'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text('From \${_date(_from)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _pickDate(false),
                    icon: const Icon(Icons.event),
                    label: Text('To \${_date(_to)}'),
                  ),
                ),
              ],
            ),
          ),
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
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            Text(
                              'Consolidated performance',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\${data['branchCount'] ?? branches.length} active branches · Pakistan time',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            GridView.count(
                              crossAxisCount:
                                  MediaQuery.sizeOf(context).width > 800
                                      ? 3
                                      : 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.8,
                              children: [
                                _metric(context, 'Completed orders',
                                    totals['ordersCompleted'] ?? 0),
                                _metric(context, 'Sales revenue',
                                    totals['salesRevenue'],
                                    prominent: true),
                                _metric(context, 'Verified collections',
                                    totals['collections']),
                                _metric(context, 'Gross profit',
                                    totals['grossProfit'],
                                    prominent: true),
                                _metric(context, 'Operating expenses',
                                    totals['operatingExpenses']),
                                _metric(context, 'Net profit',
                                    totals['netProfit'],
                                    prominent: true),
                                _metric(context, 'Cash net movement',
                                    totals['cashMovement']),
                                _metric(context, 'Received purchases',
                                    totals['purchaseReceivedTotal']),
                                _metric(context, 'Supplier outstanding',
                                    totals['supplierOutstanding']),
                              ],
                            ),
                            if (incomplete)
                              Card(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                child: const ListTile(
                                  leading: Icon(Icons.warning_amber),
                                  title: Text('Profit calculation incomplete'),
                                  subtitle: Text(
                                    'At least one branch is missing recipe cost data. Gross and net profit are withheld until cost records are complete.',
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'Branch comparison',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            if (branches.isEmpty)
                              const Card(
                                child: ListTile(
                                  title: Text('No active branches found.'),
                                ),
                              ),
                            ...branches.map((branch) {
                              final status =
                                  branch['profitabilityStatus']?.toString() ??
                                      'incomplete';
                              return Card(
                                child: ExpansionTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.storefront_outlined),
                                  ),
                                  title: Text(
                                    branch['branchName']?.toString() ??
                                        'Branch',
                                  ),
                                  subtitle: Text(
                                    '\${branch['ordersCompleted'] ?? 0} completed orders · $status',
                                  ),
                                  children: [
                                    _detail('Sales revenue',
                                        branch['salesRevenue']),
                                    _detail('Estimated COGS',
                                        branch['estimatedCogs']),
                                    _detail(
                                        'Gross profit', branch['grossProfit']),
                                    _detail('Operating expenses',
                                        branch['operatingExpenses']),
                                    _detail('Net profit', branch['netProfit']),
                                    _detail('Collections',
                                        branch['collections']),
                                    _detail('Cash movement',
                                        branch['cashMovement']),
                                    _detail('Received purchases',
                                        branch['purchaseReceivedTotal']),
                                    _detail('Supplier outstanding',
                                        branch['supplierOutstanding']),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            const Text(
                              'Accounting note: purchase totals and supplier payments are cash-flow / liability indicators, not operating expenses. Profit is based on completed orders, estimated recipe COGS and approved operating expenses.',
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, dynamic value) => ListTile(
        dense: true,
        title: Text(label),
        trailing: Text(_money(value)),
      );
}
