import 'package:flutter/material.dart';
import 'package:urban_byte/models/inventory_item.dart';
import '../../../services/expense_service.dart';
import '../../../services/inventory_service.dart';

class ExpensesView extends StatefulWidget {
  const ExpensesView({super.key});
  @override
  State<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends State<ExpensesView> {
  final _service = ExpenseService();
  final _inventory = InventoryService();
  List<Map<String, dynamic>> _expenses = [];
  List<RestaurantBranch> _branches = [];
  String _status = 'all';
  String? _branchId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([_service.getExpenses(status: _status), _inventory.branches()]);
      if (!mounted) return;
      setState(() {
        _expenses = results[0] as List<Map<String, dynamic>>;
        _branches = results[1] as List<RestaurantBranch>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _create() async {
    if (_branches.isEmpty) { _message('Create a branch before recording expenses.'); return; }
    final description = TextEditingController();
    final amount = TextEditingController();
    final reference = TextEditingController();
    final customCategory = TextEditingController();
    String category = 'Rent';
    String method = 'cash';
    String branch = _branchId ?? _branches.first.id;
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setStateDialog) => AlertDialog(
      title: const Text('Add expense'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: branch, decoration: const InputDecoration(labelText: 'Branch'), items: _branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(), onChanged: (v) { if (v != null) setStateDialog(() => branch = v); }),
        DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category'), items: const ['Rent','Electricity','Gas','Salary','Grocery','Maintenance','Delivery','Marketing','Miscellaneous','Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setStateDialog(() => category = v); }),
        if (category == 'Other') TextField(controller: customCategory, decoration: const InputDecoration(labelText: 'Custom category')),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (PKR)')),
        DropdownButtonFormField<String>(value: method, decoration: const InputDecoration(labelText: 'Payment method'), items: const [
          DropdownMenuItem(value: 'cash', child: Text('Cash')),
          DropdownMenuItem(value: 'card', child: Text('Card')),
          DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
          DropdownMenuItem(value: 'easypaisa', child: Text('Easypaisa')),
          DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')),
        ], onChanged: (v) { if (v != null) setStateDialog(() => method = v); }),
        TextField(controller: reference, decoration: const InputDecoration(labelText: 'Reference (optional)')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit for approval')),
      ],
    )));
    if (saved == true) {
      final value = double.tryParse(amount.text.trim());
      final categoryValue = category == 'Other' ? customCategory.text.trim() : category;
      if (value == null || value <= 0 || description.text.trim().isEmpty || categoryValue.isEmpty) {
        _message('Enter a valid category, description and amount.');
      } else {
        setState(() => _busy = true);
        try {
          await _service.create(branchId: int.parse(branch), category: categoryValue, description: description.text.trim(), amount: value, paymentMethod: method, expenseDate: _today(), reference: reference.text);
          _message('Expense submitted for approval.');
          await _load();
        } catch (e) { _message(e.toString()); }
        finally { if (mounted) setState(() => _busy = false); }
      }
    }
    description.dispose(); amount.dispose(); reference.dispose(); customCategory.dispose();
  }

  Future<void> _review(Map<String, dynamic> expense, bool approve) async {
    final id = int.tryParse(expense['id'].toString());
    if (id == null) return;
    String reason = '';
    if (!approve) {
      final controller = TextEditingController();
      final result = await showDialog<String>(context: context, builder: (context) => AlertDialog(
        title: const Text('Reject expense'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Reject'))],
      ));
      controller.dispose();
      if (result == null || result.isEmpty) return;
      reason = result;
    }
    setState(() => _busy = true);
    try {
      if (approve) { await _service.approve(id); } else { await _service.reject(id, reason); }
      _message(approve ? 'Expense approved.' : 'Expense rejected.');
      await _load();
    } catch (e) { _message(e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Expense Management'), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _busy ? null : _create, icon: const Icon(Icons.add), label: const Text('Add expense')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: DropdownButtonFormField<String>(value: _status, decoration: const InputDecoration(labelText: 'Expense status'), items: const [
        DropdownMenuItem(value: 'all', child: Text('All expenses')),
        DropdownMenuItem(value: 'pending', child: Text('Pending approval')),
        DropdownMenuItem(value: 'approved', child: Text('Approved')),
        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
      ], onChanged: (v) { if (v != null) { setState(() => _status = v); _load(); } })),
      if (_busy) const LinearProgressIndicator(),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), FilledButton(onPressed: _load, child: const Text('Retry'))]))
        : _expenses.isEmpty ? const Center(child: Text('No expenses found.'))
        : RefreshIndicator(onRefresh: _load, child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88), itemCount: _expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final e = _expenses[index];
            final pending = e['status'] == 'pending';
            return Card(child: ListTile(
              title: Text('${e['category']} · PKR ${e['amount']}'),
              subtitle: Text('${e['description']}\n${e['expenseDate']} · ${e['paymentMethod']} · ${e['status']}'),
              isThreeLine: true,
              trailing: pending ? PopupMenuButton<String>(
                enabled: !_busy,
                onSelected: (v) => _review(e, v == 'approve'),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'approve', child: Text('Approve')),
                  PopupMenuItem(value: 'reject', child: Text('Reject')),
                ],
              ) : null,
            ));
          },
        )),
      ),
    ]),
  );
}
