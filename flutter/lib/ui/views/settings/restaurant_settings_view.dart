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
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restaurant settings saved.')));
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Restaurant settings'), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(16), children: [
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
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
