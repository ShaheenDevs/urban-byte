import 'package:flutter/material.dart';
import '../../../app/app.locator.dart';
import '../../../services/operations_service.dart';

class DashboardOrdersView extends StatefulWidget {
  const DashboardOrdersView({
    super.key,
    required this.title,
    this.statusGroup,
    this.paymentStatusGroup,
    this.paymentStatus,
    this.initialStartDate,
    this.initialEndDate,
  });
  final String title;
  final String? statusGroup;
  final String? paymentStatusGroup;
  final String? paymentStatus;
  final String? initialStartDate;
  final String? initialEndDate;

  @override
  State<DashboardOrdersView> createState() => _DashboardOrdersViewState();
}

class _DashboardOrdersViewState extends State<DashboardOrdersView> {
  final _api = locator<OperationsService>();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  String _period = 'Today';
  String _status = 'all';
  String _payment = 'all';
  bool _allDates = false;
  String? _startTime;
  String? _endTime;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime.tryParse(widget.initialStartDate ?? '') ?? DateTime(now.year, now.month, now.day);
    _end = DateTime.tryParse(widget.initialEndDate ?? '') ?? DateTime(now.year, now.month, now.day);
    _allDates = widget.statusGroup == 'open';
    _load();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _setPeriod(String value) async {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day);
    switch (value) {
      case 'Today':
        start = end;
        break;
      case 'Week':
        start = end.subtract(Duration(days: end.weekday - 1));
        break;
      case 'Month':
        start = DateTime(end.year, end.month, 1);
        break;
      case 'Year':
        start = DateTime(end.year, 1, 1);
        break;
      case 'Custom':
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(now.year + 2),
          initialDateRange: DateTimeRange(start: _start, end: _end),
        );
        if (range == null) return;
        final startTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 0, minute: 0));
        if (startTime == null) return;
        final endTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 23, minute: 59));
        if (endTime == null) return;
        _startTime = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        _endTime = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
        start = range.start;
        end = range.end;
        break;
      default:
        start = end;
    }
    if (value != 'Custom') { _startTime = null; _endTime = null; }
    setState(() { _period = value; _start = start; _end = end; _allDates = false; });
    await _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _orders = await _api.orders(
        statusGroup: widget.statusGroup ?? (_status == 'open' || _status == 'completed' ? _status : null),
        paymentStatusGroup: widget.paymentStatusGroup ?? (_payment == 'pending' ? 'pending' : null),
        paymentStatus: widget.paymentStatus ?? (_payment == 'paid' ? 'paid' : null),
        startDate: _allDates ? null : _date(_start),
        endDate: _allDates ? null : _date(_end),
        startTime: _allDates ? null : _startTime,
        endTime: _allDates ? null : _endTime,
      );
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), actions: [
      IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
    ]),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final item in ['Today', 'Week', 'Month', 'Year', 'Custom'])
            ChoiceChip(label: Text(item), selected: _period == item, onSelected: (_) => _setPeriod(item)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Expanded(child: Text(_allDates ? 'All dates' : '${_date(_start)}  →  ${_date(_end)}${_startTime != null ? ' • $_startTime–$_endTime' : ''}')),
          if (widget.statusGroup == null)
            DropdownButton<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All orders')),
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
              ],
              onChanged: (v) { if (v != null) setState(() => _status = v); _load(); },
            ),
          if (widget.paymentStatusGroup == null && widget.paymentStatus == null)
            DropdownButton<String>(
              value: _payment,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All payments')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
              ],
              onChanged: (v) { if (v != null) setState(() => _payment = v); _load(); },
            ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center)))
          : _orders.isEmpty
            ? const Center(child: Text('No orders found for this date range.'))
            : RefreshIndicator(onRefresh: _load, child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  final total = double.tryParse('${order['grandTotal'] ?? 0}') ?? 0;
                  final payments = (order['payments'] as List? ?? []);
                  final paid = payments.where((p) => p['status'] == 'verified').fold<double>(0, (sum, p) => sum + (double.tryParse('${p['amount'] ?? 0}') ?? 0));
                  final due = (total - paid).clamp(0, total).toDouble();
                  final items = (order['items'] as List? ?? []);
                  return Card(child: ListTile(
                    title: Text('${order['orderNumber'] ?? 'Order'} • PKR ${total.toStringAsFixed(2)}'),
                    subtitle: Text('${order['orderType']} • ${order['status']} • ${order['paymentStatus']}\nPaid: PKR ${paid.toStringAsFixed(2)} • Due: PKR ${due.toStringAsFixed(2)}\n${items.map((i) => '${i['quantity']} × ${i['productName']}').join(', ')}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.receipt_long_outlined),
                  ));
                },
              ))),
    ]),
  );
}
