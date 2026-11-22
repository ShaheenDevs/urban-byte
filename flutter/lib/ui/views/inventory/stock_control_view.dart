import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../../../models/inventory_item.dart';

class StockControlView extends StatefulWidget {
  const StockControlView({super.key});
  @override
  State<StockControlView> createState() => _StockControlViewState();
}

class _StockControlViewState extends State<StockControlView> {
  final _api = InventoryService();
  List<RestaurantBranch> _branches = [];
  List<InventoryItem> _items = [];
  List<Map<String, dynamic>> _purchases = [];
  Map<String, dynamic> _valuation = {};
  String? _branchId;
  bool _loading = true, _busy = false;
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
      final r =
          await Future.wait([_api.branches(), _api.items(), _api.purchases()]);
      final branches = r[0] as List<RestaurantBranch>;
      final branch =
          _branchId ?? (branches.isNotEmpty ? branches.first.id : null);
      final valuation = await _api.inventoryValuation(branchId: branch);
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _items = r[1] as List<InventoryItem>;
        _purchases = r[2] as List<Map<String, dynamic>>;
        _branchId = branch;
        _valuation = valuation;
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

  void _message(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> _transfer() async {
    if (_branches.length < 2 || _items.isEmpty) {
      _message('At least two branches and one inventory item are required.');
      return;
    }
    String from = _branchId ?? _branches.first.id,
        to = _branches.firstWhere((b) => b.id != from).id,
        item = _items.first.id;
    final qty = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setD) => AlertDialog(
                  title: const Text('Transfer stock between branches'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                        value: from,
                        decoration:
                            const InputDecoration(labelText: 'From branch'),
                        items: _branches
                            .map((b) => DropdownMenuItem(
                                value: b.id, child: Text(b.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null)
                            setD(() {
                              from = v;
                              if (to == from)
                                to = _branches
                                    .firstWhere((b) => b.id != from)
                                    .id;
                            });
                        }),
                    DropdownButtonFormField<String>(
                        value: to,
                        decoration:
                            const InputDecoration(labelText: 'To branch'),
                        items: _branches
                            .where((b) => b.id != from)
                            .map((b) => DropdownMenuItem(
                                value: b.id, child: Text(b.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setD(() => to = v);
                        }),
                    DropdownButtonFormField<String>(
                        value: item,
                        decoration:
                            const InputDecoration(labelText: 'Inventory item'),
                        items: _items
                            .map((i) => DropdownMenuItem(
                                value: i.id, child: Text(i.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setD(() => item = v);
                        }),
                    TextField(
                        controller: qty,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Quantity')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Transfer'))
                  ],
                )));
    final q = double.tryParse(qty.text);
    qty.dispose();
    if (ok == true && q != null && q > 0) {
      setState(() => _busy = true);
      try {
        final result = await _api.transferStock(
            fromBranchId: from,
            toBranchId: to,
            inventoryItemId: item,
            quantity: q);
        _message('Stock transferred: ${result['reference']}');
        await _load();
      } catch (e) {
        _message(e.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _return(
      Map<String, dynamic> purchase, Map<String, dynamic> line) async {
    final qty = TextEditingController(text: '1'),
        note = TextEditingController(text: 'Supplier return');
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Return purchase item'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      'Purchase ${purchase['purchaseNumber'] ?? purchase['id']} · Item #${line['inventoryItemId']}'),
                  TextField(
                      controller: qty,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Return quantity')),
                  TextField(
                      controller: note,
                      decoration: const InputDecoration(labelText: 'Reason')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Return stock'))
                ]));
    final q = double.tryParse(qty.text);
    final n = note.text;
    qty.dispose();
    note.dispose();
    if (ok == true && q != null && q > 0) {
      setState(() => _busy = true);
      try {
        await _api.returnPurchase(
            purchaseId: purchase['id'].toString(),
            purchaseItemId: line['id'].toString(),
            quantity: q,
            note: n);
        _message('Returned stock recorded.');
        await _load();
      } catch (e) {
        _message(e.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Stock Control'), actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _busy ? null : _transfer,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Transfer stock')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              FilledButton(
                                  onPressed: _load, child: const Text('Retry'))
                            ])))
                : Column(children: [
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: DropdownButtonFormField<String>(
                            value: _branchId,
                            decoration: const InputDecoration(
                                labelText: 'Valuation branch'),
                            items: [
                              const DropdownMenuItem<String>(
                                  value: null, child: Text('All branches')),
                              ..._branches.map((b) => DropdownMenuItem(
                                  value: b.id, child: Text(b.name)))
                            ],
                            onChanged: (v) {
                              setState(() => _branchId = v);
                              _load();
                            })),
                    if (_busy) const LinearProgressIndicator(),
                    Expanded(
                        child: ListView(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            children: [
                          Card(
                              child: ListTile(
                                  leading: const Icon(
                                      Icons.account_balance_wallet_outlined),
                                  title:
                                      const Text('Estimated inventory value'),
                                  subtitle: Text(
                                      _valuation['note']?.toString() ?? ''),
                                  trailing: Text(_valuation['totalValuation'] ==
                                          null
                                      ? 'Incomplete'
                                      : 'PKR ${_valuation['totalValuation']}'))),
                          Text('Stock valuation',
                              style: Theme.of(context).textTheme.titleLarge),
                          ...((_valuation['items'] as List? ?? []).map((e) =>
                              ListTile(
                                  title: Text(e['name'].toString()),
                                  subtitle: Text(
                                      'Qty ${e['quantity']} ${e['unit']} · Avg cost ${e['averageUnitCost'] ?? 'Missing'}'),
                                  trailing: Text(e['valuation'] == null
                                      ? '—'
                                      : 'PKR ${e['valuation']}')))),
                          const SizedBox(height: 12),
                          Text('Purchase returns',
                              style: Theme.of(context).textTheme.titleLarge),
                          ..._purchases
                              .where((p) => p['status'] == 'received')
                              .map((p) => Card(
                                      child: ExpansionTile(
                                          title: Text(
                                              '${p['purchaseNumber']} · PKR ${p['totalCost']}'),
                                          subtitle:
                                              const Text('Received purchase'),
                                          children: [
                                        ...((p['items'] as List? ?? []).map(
                                            (line) => ListTile(
                                                title: Text(
                                                    'Item #${line['inventoryItemId']} · Qty ${line['quantity']}'),
                                                trailing: TextButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _return(
                                                            p,
                                                            Map<String,
                                                                    dynamic>.from(
                                                                line)),
                                                    child: const Text(
                                                        'Return'))))),
                                      ]))),
                        ])),
                  ]),
      );
}
