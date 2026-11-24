import 'package:flutter/material.dart';
import 'package:urban_byte/models/inventory_item.dart';
import '../../../services/cash_shift_service.dart';
import '../../../services/inventory_service.dart';

class CashShiftView extends StatefulWidget {
  const CashShiftView({super.key});
  @override
  State<CashShiftView> createState() => _CashShiftViewState();
}

class _CashShiftViewState extends State<CashShiftView> {
  final _service = CashShiftService();
  final _inventory = InventoryService();
  List<RestaurantBranch> _branches = [];
  Map<String, dynamic>? _shift;
  List<Map<String, dynamic>> _history = [];
  String? _branchId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      if (branches.isEmpty) throw Exception('No active branch found.');
      final branch = _branchId ?? branches.first.id;
      final today = DateTime.now();
      final fromDate = today.subtract(const Duration(days: 30));
      String dateText(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final results = await Future.wait([
        _service.current(branchId: branch),
        _service.history(
            branchId: branch,
            from: dateText(fromDate),
            to: dateText(today)),
      ]);
      final shifts = results[0];
      final history = results[1];
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _branchId = branch;
        _shift = shifts.isEmpty ? null : shifts.first;
        _history = history;
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

  Future<double?> _amountDialog(String title, {String initial = '0'}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (PKR)')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      final n = double.tryParse(controller.text.trim());
                      if (n != null && n >= 0) Navigator.pop(context, n);
                    },
                    child: const Text('Continue'))
              ],
            ));
    controller.dispose();
    return value;
  }

  Future<void> _open() async {
    final amount = await _amountDialog('Open cashier shift');
    if (amount == null) return;
    setState(() => _busy = true);
    try {
      await _service.open(branchId: _branchId!, openingCash: amount);
      await _load();
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _entry(String type) async {
    final amount =
        await _amountDialog(type == 'cash_in' ? 'Cash in' : 'Cash out');
    if (amount == null || amount <= 0) return;
    final note = TextEditingController();
    final description = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Description'),
              content: TextField(
                  controller: note,
                  decoration:
                      const InputDecoration(hintText: 'Reason / details')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, note.text.trim()),
                    child: const Text('Save'))
              ],
            ));
    note.dispose();
    if (description == null) return;
    setState(() => _busy = true);
    try {
      await _service.entry(
          shiftId: _shift!['id'].toString(),
          type: type,
          amount: amount,
          description: description);
      await _load();
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final actual = await _amountDialog('Count actual cash');
    if (actual == null) return;
    setState(() => _busy = true);
    try {
      final result = await _service.close(
          shiftId: _shift!['id'].toString(), actualCash: actual);
      final variance = result['cashVariance'] ?? result['cash_variance'] ?? '—';
      if (mounted) _message('Shift closed. Cash variance: PKR $variance');
      await _load();
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(Map<String, dynamic> shift, bool approve) async {
    final id = shift['id']?.toString();
    if (id == null) return;
    String note = '';
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve
            ? 'Approve cash reconciliation'
            : 'Reject cash reconciliation'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: approve ? 'Note (optional)' : 'Reason (required)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                dialogContext, controller.text.trim()),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || (!approve && result.isEmpty)) return;
    note = result;
    setState(() => _busy = true);
    try {
      if (approve) {
        await _service.approveReconciliation(id, note: note);
      } else {
        await _service.rejectReconciliation(id, note);
      }
      _message(approve
          ? 'Reconciliation approved.'
          : 'Reconciliation rejected.');
      await _load();
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _historyCard(Map<String, dynamic> shift) {
    dynamic field(String camel, String snake) =>
        shift[camel] ?? shift[snake];
    final status = (field('reconciliationStatus', 'reconciliation_status') ??
            'not_submitted')
        .toString();
    final pending = status == 'pending_approval';
    final branchId = field('branchId', 'branch_id')?.toString();
    final branchNames = _branches
        .where((branch) => branch.id == branchId)
        .map((branch) => branch.name)
        .toList();
    final branchName = branchNames.isEmpty ? 'Branch $branchId' : branchNames.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shift #${shift['id']} · $branchName',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Expected: PKR ${field('expectedCash', 'expected_cash') ?? '—'}'),
            Text('Counted: PKR ${field('actualCash', 'actual_cash') ?? '—'}'),
            Text('Variance: PKR ${field('cashVariance', 'cash_variance') ?? '—'}'),
            Text('Status: ${status.replaceAll('_', ' ')}'),
            if (pending)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, children: [
                  TextButton(
                    onPressed: _busy ? null : () => _review(shift, false),
                    child: const Text('Reject'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _review(shift, true),
                    child: const Text('Approve'),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cashier Shift'), actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    FilledButton(onPressed: _load, child: const Text('Retry'))
                  ]))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    DropdownButtonFormField<String>(
                        value: _branchId,
                        decoration: const InputDecoration(labelText: 'Branch'),
                        items: _branches
                            .map((b) => DropdownMenuItem(
                                value: b.id, child: Text(b.name)))
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (v) {
                                if (v != null) {
                                  setState(() => _branchId = v);
                                  _load();
                                }
                              }),
                    const SizedBox(height: 16),
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      _shift == null
                                          ? 'No open shift'
                                          : 'Shift #${_shift!['id']} is OPEN',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  if (_shift != null)
                                    Text(
                                        'Opening cash: PKR ${_shift!['openingCash'] ?? _shift!['opening_cash'] ?? '0.00'}'),
                                  const SizedBox(height: 12),
                                  if (_shift == null)
                                    FilledButton.icon(
                                        onPressed: _busy ? null : _open,
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Open shift'))
                                  else
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      OutlinedButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _entry('cash_in'),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Cash in')),
                                      OutlinedButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _entry('cash_out'),
                                          icon: const Icon(Icons.remove),
                                          label: const Text('Cash out')),
                                      FilledButton.icon(
                                          onPressed: _busy ? null : _close,
                                          icon: const Icon(Icons.lock),
                                          label: const Text('Close shift')),
                                    ])
                                ]))),
                    if (_busy) const LinearProgressIndicator(),
                    const Text(
                        'Expected cash is calculated by the server using opening cash, verified cash payments, cash-in, cash-out and approved cash expenses.'),
                    const SizedBox(height: 20),
                    Text('Cash reconciliation history (last 30 days)',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (_history.isEmpty)
                      const Text('No closed shifts found for this branch.')
                    else
                      ..._history.map(_historyCard),
                  ]),
      );
}
