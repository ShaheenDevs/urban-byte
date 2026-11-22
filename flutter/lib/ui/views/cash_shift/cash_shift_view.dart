import 'package:flutter/material.dart';
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
  String? _branchId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final branches = await _inventory.branches();
      if (branches.isEmpty) throw Exception('No active branch found.');
      final branch = _branchId ?? branches.first.id;
      final shifts = await _service.current(branchId: branch);
      if (!mounted) return;
      setState(() { _branches = branches; _branchId = branch; _shift = shifts.isEmpty ? null : shifts.first; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<double?> _amountDialog(String title, {String initial = '0'}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<double>(context: context, builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (PKR)')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final n = double.tryParse(controller.text.trim()); if (n != null && n >= 0) Navigator.pop(context, n); }, child: const Text('Continue'))],
    ));
    controller.dispose();
    return value;
  }

  Future<void> _open() async {
    final amount = await _amountDialog('Open cashier shift');
    if (amount == null) return;
    setState(() => _busy = true);
    try { await _service.open(branchId: _branchId!, openingCash: amount); await _load(); }
    catch (e) { if (mounted) _message(e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _entry(String type) async {
    final amount = await _amountDialog(type == 'cash_in' ? 'Cash in' : 'Cash out');
    if (amount == null || amount <= 0) return;
    final note = TextEditingController();
    final description = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Description'),
      content: TextField(controller: note, decoration: const InputDecoration(hintText: 'Reason / details')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, note.text.trim()), child: const Text('Save'))],
    ));
    note.dispose();
    if (description == null) return;
    setState(() => _busy = true);
    try { await _service.entry(shiftId: _shift!['id'].toString(), type: type, amount: amount, description: description); await _load(); }
    catch (e) { if (mounted) _message(e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _close() async {
    final actual = await _amountDialog('Count actual cash');
    if (actual == null) return;
    setState(() => _busy = true);
    try {
      final result = await _service.close(shiftId: _shift!['id'].toString(), actualCash: actual);
      final variance = result['cashVariance'] ?? result['cash_variance'] ?? '—';
      if (mounted) _message('Shift closed. Cash variance: PKR $variance');
      await _load();
    } catch (e) { if (mounted) _message(e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cashier Shift'), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null
      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), FilledButton(onPressed: _load, child: const Text('Retry'))]))
      : ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(value: _branchId, decoration: const InputDecoration(labelText: 'Branch'), items: _branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(), onChanged: _busy ? null : (v) { if (v != null) { setState(() => _branchId = v); _load(); } }),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_shift == null ? 'No open shift' : 'Shift #${_shift!['id']} is OPEN', style: Theme.of(context).textTheme.titleLarge),
          if (_shift != null) Text('Opening cash: PKR ${_shift!['openingCash'] ?? _shift!['opening_cash'] ?? '0.00'}'),
          const SizedBox(height: 12),
          if (_shift == null) FilledButton.icon(onPressed: _busy ? null : _open, icon: const Icon(Icons.play_arrow), label: const Text('Open shift'))
          else Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _busy ? null : () => _entry('cash_in'), icon: const Icon(Icons.add), label: const Text('Cash in')),
            OutlinedButton.icon(onPressed: _busy ? null : () => _entry('cash_out'), icon: const Icon(Icons.remove), label: const Text('Cash out')),
            FilledButton.icon(onPressed: _busy ? null : _close, icon: const Icon(Icons.lock), label: const Text('Close shift')),
          ])
        ]))),
        if (_busy) const LinearProgressIndicator(),
        const Text('Expected cash is calculated by the server using opening cash, verified cash payments, cash-in and cash-out entries.'),
      ]),
  );
}
