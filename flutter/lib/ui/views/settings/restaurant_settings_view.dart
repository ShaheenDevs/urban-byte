import 'package:flutter/material.dart';
import '../../../services/restaurant_settings_service.dart';

class RestaurantSettingsView extends StatefulWidget {
  const RestaurantSettingsView({super.key});
  @override
  State<RestaurantSettingsView> createState() => _RestaurantSettingsViewState();
}

class _RestaurantSettingsViewState extends State<RestaurantSettingsView> {
  final _service = RestaurantSettingsService();
  final _taxRate = TextEditingController();
  final _maxDiscount = TextEditingController(text: '20');
  final _header = TextEditingController(text: 'URBAN BYTE');
  final _footer = TextEditingController(text: 'Thank you for choosing Urban Byte!');
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _orderTypes = [];
  bool _taxEnabled = false, _taxInclusive = false, _discountEnabled = true, _loading = true, _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _taxRate.dispose(); _maxDiscount.dispose(); _header.dispose(); _footer.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.load();
      _taxEnabled = data['taxEnabled'] == true;
      _taxInclusive = data['taxInclusive'] == true;
      _discountEnabled = data['discountEnabled'] != false;
      _taxRate.text = '${data['taxRate'] ?? 0}';
      _maxDiscount.text = '${data['maxDiscountPercent'] ?? 20}';
      _header.text = '${data['receiptHeader'] ?? 'URBAN BYTE'}';
      _footer.text = '${data['receiptFooter'] ?? 'Thank you for choosing Urban Byte!'}';
      _tables = (data['diningTables'] as List? ?? []).map((e) => Map<String,dynamic>.from(e as Map)).toList();
      _orderTypes = (data['orderTypes'] as List? ?? []).map((e) => Map<String,dynamic>.from(e as Map)).toList();
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await _service.save({
        'taxEnabled': _taxEnabled, 'taxRate': double.tryParse(_taxRate.text) ?? 0,
        'taxInclusive': _taxInclusive, 'discountEnabled': _discountEnabled,
        'maxDiscountPercent': double.tryParse(_maxDiscount.text) ?? 20,
        'receiptHeader': _header.text.trim(), 'receiptFooter': _footer.text.trim(),
        'diningTables': _tables, 'orderTypes': _orderTypes,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restaurant settings saved.')));
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addTable() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add dining table'),
      content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Table name (e.g. Table 01)')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add'))],
    ));
    if (ok == true && name.text.trim().isNotEmpty) setState(() => _tables.add({
      'id': 'table_${DateTime.now().microsecondsSinceEpoch}', 'name': name.text.trim(), 'isActive': true
    }));
    name.dispose();
  }

  Future<void> _addOrderType() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add order type'),
      content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name (e.g. Drive Through)')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add'))],
    ));
    if (ok == true && name.text.trim().isNotEmpty) {
      final key = name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
      if (_orderTypes.any((e) => e['key'] == key)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This order type already exists.')));
      } else {
        setState(() => _orderTypes.add({'key': key, 'name': name.text.trim()}));
      }
    }
    name.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Restaurant settings'), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(16), children: [
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
        Text('Dining tables', style: Theme.of(context).textTheme.titleLarge),
        const Text('Add the tables available for dine-in. Occupied tables are blocked while an active order exists.'),
        ..._tables.map((t) => ListTile(
          leading: const Icon(Icons.table_restaurant), title: Text('${t['name']}'),
          subtitle: Text(t['isActive'] == false ? 'Inactive' : 'Available for dine-in'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: _saving ? null : () => setState(() => _tables.removeWhere((x) => x['id'] == t['id']))),
        )),
        OutlinedButton.icon(onPressed: _saving ? null : _addTable, icon: const Icon(Icons.add), label: const Text('Add table')),
        const Divider(height: 32),
        Text('Order types', style: Theme.of(context).textTheme.titleLarge),
        const Text('Add or remove order types. At least one Takeaway type must remain.'),
        ..._orderTypes.map((t) => ListTile(
          leading: const Icon(Icons.receipt_long), title: Text('${t['name']}'),
          subtitle: Text('${t['key']}'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: _saving || t['key'] == 'takeaway' ? null : () => setState(() => _orderTypes.removeWhere((x) => x['key'] == t['key']))),
        )),
        OutlinedButton.icon(onPressed: _saving ? null : _addOrderType, icon: const Icon(Icons.add), label: const Text('Add order type')),
        const Divider(height: 32),
        Text('Tax configuration', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(title: const Text('Enable tax'), value: _taxEnabled, onChanged: (v) => setState(() => _taxEnabled = v)),
        TextField(controller: _taxRate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tax rate (%)')),
        SwitchListTile(title: const Text('Tax inclusive pricing'), subtitle: const Text('Tax is included in displayed menu prices.'), value: _taxInclusive, onChanged: (v) => setState(() => _taxInclusive = v)),
        const Divider(height: 32),
        Text('Discount configuration', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(title: const Text('Allow order discounts'), value: _discountEnabled, onChanged: (v) => setState(() => _discountEnabled = v)),
        TextField(controller: _maxDiscount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Maximum discount (%)')),
        const Divider(height: 32),
        Text('Receipt branding', style: Theme.of(context).textTheme.titleLarge),
        TextField(controller: _header, decoration: const InputDecoration(labelText: 'Receipt header')),
        TextField(controller: _footer, maxLines: 2, decoration: const InputDecoration(labelText: 'Receipt footer')),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: Text(_saving ? 'Saving...' : 'Save settings')),
      ]),
  );
}
