import 'package:flutter/material.dart';
import '../../../app/app.locator.dart';
import '../../../services/inventory_service.dart';
import '../../../services/operations_service.dart';

class PosView extends StatefulWidget {
  const PosView({super.key});
  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final _ops = locator<OperationsService>();
  final _inventory = locator<InventoryService>();
  final _cart = <String, Map<String, dynamic>>{};
  final _table = TextEditingController();
  final _customer = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  List<RestaurantBranch> _branches = [];
  List<Map<String, dynamic>> _products = [];
  String? _branchId;
  String? _categoryId;
  String _type = 'takeaway';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _table.dispose(); _customer.dispose(); _phone.dispose(); _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final branches = await _inventory.branches();
      if (branches.isEmpty) throw Exception('No active branch found.');
      final branchId = _branchId ?? branches.first.id;
      final products = await _ops.menu(branchId: branchId);
      if (!mounted) return;
      setState(() {
        _branches = branches; _branchId = branchId;
        _products = products.where((p) => p['isActive'] != false && p['isAvailable'] != false).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double get _total => _cart.values.fold(0.0, (sum, item) =>
      sum + (double.tryParse(item['price'].toString()) ?? 0) * (item['qty'] as int));

  void _add(Map<String, dynamic> product) {
    final variants = (product['variants'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .where((v) => v['isActive'] != false).toList();
    if (variants.isEmpty) { _message('No active price variant for this product.'); return; }
    final variant = variants.firstWhere((v) => v['isDefault'] == true, orElse: () => variants.first);
    final prices = (variant['branchPrices'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map)).toList();
    if (prices.isNotEmpty && prices.first['isAvailable'] == false) { _message('Product unavailable at this branch.'); return; }
    final price = double.tryParse((prices.isNotEmpty ? prices.first['salePrice'] : variant['basePrice']).toString()) ?? 0;
    final id = variant['id'].toString();
    setState(() {
      if (_cart.containsKey(id)) { _cart[id]!['qty'] = (_cart[id]!['qty'] as int) + 1; }
      else { _cart[id] = {'variantId': id, 'name': product['name'].toString() + ' · ' + variant['name'].toString(), 'price': price, 'qty': 1}; }
    });
  }

  Future<void> _place() async {
    if (_cart.isEmpty || _branchId == null) return;
    if (_type == 'dine_in' && _table.text.trim().isEmpty) { _message('Enter table label.'); return; }
    if (_type == 'delivery' && _address.text.trim().isEmpty) { _message('Enter delivery address.'); return; }
    setState(() => _saving = true);
    try {
      final result = await _ops.createOrder(
        branchId: _branchId!, orderType: _type,
        tableLabel: _type == 'dine_in' ? _table.text.trim() : null,
        deliveryAddress: _type == 'delivery' ? _address.text.trim() : null,
        customerName: _customer.text.trim().isEmpty ? null : _customer.text.trim(),
        customerPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        items: _cart.values.map((i) => {'variantId': int.parse(i['variantId'].toString()), 'quantity': i['qty']}).toList(),
      );
      if (!mounted) return;
      setState(() { _cart.clear(); _saving = false; });
      _message('Order created: ' + (result['orderNumber']?.toString() ?? result['id'].toString()));
    } catch (e) {
      if (mounted) { setState(() => _saving = false); _message(e.toString()); }
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final categories = <String, String>{};
    for (final p in _products) {
      final c = p['category'];
      if (c is Map && c['id'] != null) categories[c['id'].toString()] = c['name'].toString();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Urban Byte POS'), actions: [
        IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry'))
          ])))
        : LayoutBuilder(builder: (context, size) {
            final menu = _menu(categories);
            final cart = _cartPanel();
            return size.maxWidth >= 850
              ? Row(children: [Expanded(flex: 3, child: menu), const VerticalDivider(width: 1), Expanded(flex: 2, child: cart)])
              : Column(children: [Expanded(child: menu), const Divider(height: 1), SizedBox(height: 310, child: cart)]);
          }),
    );
  }

  Widget _menu(Map<String, String> categories) => Column(children: [
    Padding(padding: const EdgeInsets.all(10), child: DropdownButtonFormField<String>(
      value: _branchId, decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder()),
      items: _branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
      onChanged: (v) { if (v != null) { setState(() { _branchId = v; _cart.clear(); }); _load(); } },
    )),
    SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, children: [
      ChoiceChip(label: const Text('All'), selected: _categoryId == null, onSelected: (_) => setState(() => _categoryId = null)),
      ...categories.entries.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text(e.value), selected: _categoryId == e.key, onSelected: (_) => setState(() => _categoryId = e.key))))
    ])),
    Expanded(child: GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisExtent: 112, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: _products.where((p) => _categoryId == null || (p['category'] is Map && p['category']['id'].toString() == _categoryId)).length,
      itemBuilder: (context, index) {
        final filtered = _products.where((p) => _categoryId == null || (p['category'] is Map && p['category']['id'].toString() == _categoryId)).toList();
        final p = filtered[index];
        final variants = (p['variants'] as List? ?? []);
        final variant = variants.isEmpty ? null : variants.firstWhere((v) => (v as Map)['isDefault'] == true, orElse: () => variants.first) as Map;
        final price = variant == null ? '—' : (variant['basePrice']?.toString() ?? '—');
        return Card(child: InkWell(onTap: () => _add(p), child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(p['name'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('PKR ' + price), const Icon(Icons.add_circle_outline)])
        ]))));
      })),
  ]);

  Widget _cartPanel() => Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Current order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    Expanded(child: _cart.isEmpty ? const Center(child: Text('Select products to start an order.')) : ListView(children: _cart.entries.map((entry) {
      final i = entry.value;
      return ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(i['name'].toString()),
        subtitle: Text('PKR ' + (i['price'] as double).toStringAsFixed(2)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(onPressed: () => setState(() { final q = i['qty'] as int; if (q <= 1) { _cart.remove(entry.key); } else { i['qty'] = q - 1; } }), icon: const Icon(Icons.remove_circle_outline)),
          Text(i['qty'].toString()),
          IconButton(onPressed: () => setState(() => i['qty'] = (i['qty'] as int) + 1), icon: const Icon(Icons.add_circle_outline))
        ]));
    }).toList())),
    DropdownButtonFormField<String>(value: _type, decoration: const InputDecoration(labelText: 'Order type'), items: const [
      DropdownMenuItem(value: 'takeaway', child: Text('Takeaway')),
      DropdownMenuItem(value: 'dine_in', child: Text('Dine-in')),
      DropdownMenuItem(value: 'delivery', child: Text('Delivery'))
    ], onChanged: (v) => setState(() => _type = v ?? 'takeaway')),
    if (_type == 'dine_in') TextField(controller: _table, decoration: const InputDecoration(labelText: 'Table label')),
    if (_type == 'delivery') TextField(controller: _address, decoration: const InputDecoration(labelText: 'Delivery address')),
    TextField(controller: _customer, decoration: const InputDecoration(labelText: 'Customer name (optional)')),
    TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Customer phone (optional)')),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Estimated total'), Text('PKR ' + _total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
    const SizedBox(height: 6),
    FilledButton.icon(onPressed: _saving || _cart.isEmpty ? null : _place,
      icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.point_of_sale),
      label: Text(_saving ? 'Placing order...' : 'Place order'))
  ]));
}
