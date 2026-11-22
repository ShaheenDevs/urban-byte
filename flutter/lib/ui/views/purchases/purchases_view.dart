import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../../../models/inventory_item.dart';

class PurchasesView extends StatefulWidget {
  const PurchasesView({super.key});
  @override
  State<PurchasesView> createState() => _PurchasesViewState();
}

class _PurchasesViewState extends State<PurchasesView> {
  final _service = InventoryService();
  List<Map<String, dynamic>> _purchases = [], _suppliers = [];
  List<RestaurantBranch> _branches = [];
  List<InventoryItem> _items = [];
  String? _branchId;
  bool _loading = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        _service.purchases(),
        _service.suppliers(),
        _service.branches(),
        _service.items()
      ]);
      if (!mounted) return;
      final branches = r[2] as List<RestaurantBranch>;
      setState(() {
        _purchases = r[0] as List<Map<String, dynamic>>;
        _suppliers = r[1] as List<Map<String, dynamic>>;
        _branches = branches;
        _items = r[3] as List<InventoryItem>;
        _branchId ??= branches.isNotEmpty ? branches.first.id : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String v) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v)));
  Future<void> _create() async {
    if (_branches.isEmpty || _items.isEmpty) {
      _message('Create a branch and inventory items first.');
      return;
    }
    String branch = _branchId ?? _branches.first.id;
    String? supplierId;
    final lines = <Map<String, dynamic>>[];
    InventoryItem selected = _items.first;
    final qty = TextEditingController(text: '1'),
        cost = TextEditingController(text: '0');
    final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setD) => AlertDialog(
                  title: const Text('New purchase invoice'),
                  content: SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<String>(
                            value: branch,
                            decoration:
                                const InputDecoration(labelText: 'Branch'),
                            items: _branches
                                .map((b) => DropdownMenuItem(
                                    value: b.id, child: Text(b.name)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setD(() => branch = v);
                            }),
                        DropdownButtonFormField<String?>(
                            value: supplierId,
                            decoration: const InputDecoration(
                                labelText: 'Supplier (optional)'),
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('No supplier')),
                              ..._suppliers.map((s) =>
                                  DropdownMenuItem<String?>(
                                      value: s['id'].toString(),
                                      child: Text(s['name'].toString())))
                            ],
                            onChanged: (v) => setD(() => supplierId = v)),
                        DropdownButtonFormField<InventoryItem>(
                            value: selected,
                            decoration: const InputDecoration(
                                labelText: 'Inventory item'),
                            items: _items
                                .map((i) => DropdownMenuItem(
                                    value: i,
                                    child: Text('${i.name} · ${i.unit}')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setD(() => selected = v);
                            }),
                        TextField(
                            controller: qty,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Quantity')),
                        TextField(
                            controller: cost,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Unit cost (PKR)')),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                            onPressed: () {
                              final q = double.tryParse(qty.text),
                                  c = double.tryParse(cost.text);
                              if (q == null || q <= 0 || c == null || c < 0)
                                return;
                              setD(() => lines.add({
                                    'inventoryItemId': int.parse(selected.id),
                                    'quantity': q,
                                    'unitCost': c
                                  }));
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add invoice line')),
                        ...lines.asMap().entries.map((e) => ListTile(
                            dense: true,
                            title: Text('Item #${e.value['inventoryItemId']}'),
                            subtitle: Text(
                                'Qty ${e.value['quantity']} × PKR ${e.value['unitCost']}'),
                            trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setD(() => lines.removeAt(e.key))))),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Create draft'))
                  ],
                )));
    qty.dispose();
    cost.dispose();
    if (result == true) {
      if (lines.isEmpty) {
        _message('Add at least one purchase line.');
        return;
      }
      setState(() => _busy = true);
      try {
        await _service.createPurchase(
            branchId: branch, supplierId: supplierId, items: lines);
        _message('Purchase draft created.');
        await _load();
      } catch (e) {
        _message(e.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _receive(Map<String, dynamic> p) async {
    setState(() => _busy = true);
    try {
      await _service.receivePurchase(p['id'].toString());
      _message('Purchase received; branch stock updated.');
      await _load();
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(Map<String, dynamic> p) async {
    final amount = TextEditingController();
    String method = 'cash';
    final ref = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setD) => AlertDialog(
                    title: const Text('Supplier payment'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Amount (PKR)')),
                      DropdownButtonFormField<String>(
                          value: method,
                          items: const [
                            DropdownMenuItem(
                                value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(
                                value: 'bank_transfer',
                                child: Text('Bank transfer')),
                            DropdownMenuItem(
                                value: 'easypaisa', child: Text('Easypaisa')),
                            DropdownMenuItem(
                                value: 'jazzcash', child: Text('JazzCash')),
                            DropdownMenuItem(value: 'card', child: Text('Card'))
                          ],
                          onChanged: (v) {
                            if (v != null) setD(() => method = v);
                          }),
                      TextField(
                          controller: ref,
                          decoration: const InputDecoration(
                              labelText: 'Reference (optional)')),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Record payment'))
                    ])));
    final value = double.tryParse(amount.text);
    amount.dispose();
    if (ok == true && value != null && value > 0) {
      setState(() => _busy = true);
      try {
        await _service.recordPurchasePayment(p['id'].toString(),
            amount: value, method: method, reference: ref.text);
        _message('Supplier payment recorded.');
        await _load();
      } catch (e) {
        _message(e.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    ref.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Purchases & Supplier Payments'),
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
            ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.add),
            label: const Text('New purchase')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _purchases.isEmpty
                    ? const Center(child: Text('No purchases found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _purchases.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) {
                          final p = _purchases[i];
                          final status = p['status']?.toString() ?? 'draft';
                          return Card(
                              child: ExpansionTile(
                                  title: Text(
                                      '${p['purchaseNumber'] ?? 'Purchase #${p['id']}'} · PKR ${p['totalCost'] ?? 0}'),
                                  subtitle: Text(
                                      'Status: $status · Branch #${p['branchId']}'),
                                  children: [
                                if (p['items'] is List)
                                  ...(p['items'] as List).map((line) => ListTile(
                                      dense: true,
                                      title: Text(
                                          'Inventory item #${line['inventoryItemId']}'),
                                      subtitle: Text(
                                          'Qty ${line['quantity']} × PKR ${line['unitCost']}'))),
                                Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Wrap(spacing: 8, children: [
                                      if (status == 'draft')
                                        FilledButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _receive(p),
                                            child: const Text(
                                                'Receive & update stock')),
                                      if (status == 'received' &&
                                          p['supplierId'] != null)
                                        OutlinedButton(
                                            onPressed:
                                                _busy ? null : () => _pay(p),
                                            child:
                                                const Text('Record payment')),
                                    ]))
                              ]));
                        }),
      );
}
