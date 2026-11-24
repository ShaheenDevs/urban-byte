import 'package:flutter/material.dart';
import '../../../services/restaurant_settings_service.dart';
import '../../../services/operations_service.dart';
import '../../../services/printing_service.dart';

class RestaurantSettingsView extends StatefulWidget {
  const RestaurantSettingsView({super.key});
  @override
  State<RestaurantSettingsView> createState() => _RestaurantSettingsViewState();
}

class _RestaurantSettingsViewState extends State<RestaurantSettingsView> {
  final _service = RestaurantSettingsService();
  final _operations = OperationsService();
  final _printing = PrintingService();
  final _taxRate = TextEditingController();
  final _maxDiscount = TextEditingController(text: '20');
  final _header = TextEditingController(text: 'URBAN BYTE');
  final _footer =
      TextEditingController(text: 'Thank you for choosing Urban Byte!');
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _orderTypes = [];
  List<Map<String, dynamic>> _kitchenGroups = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _printers = [];
  List<Map<String, dynamic>> _deliveryDrivers = [];
  String? _defaultDeliveryUserId;
  bool _taxEnabled = false,
      _taxInclusive = false,
      _discountEnabled = true,
      _loading = true,
      _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _taxRate.dispose();
    _maxDiscount.dispose();
    _header.dispose();
    _footer.dispose();\n    _deliveryBaseFee.dispose();\n    _deliveryPerKmFee.dispose();\n    _deliveryFreeRadius.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.load();
      try {
        _products = await _operations.menu();
      } catch (_) {
        _products = [];
      }
      try {
        _printers = await _printing.printers();
      } catch (_) {
        _printers = [];
      }
      try {
        _deliveryDrivers = await _operations.deliveryDrivers();
      } catch (_) {
        _deliveryDrivers = [];
      }
      _defaultDeliveryUserId = data['defaultDeliveryUserId']?.toString();\n      _deliveryBaseFee.text = '${data['deliveryBaseFee'] ?? 0}';\n      _deliveryPerKmFee.text = '${data['deliveryPerKmFee'] ?? 0}';\n      _deliveryFreeRadius.text = '${data['deliveryFreeRadiusKm'] ?? 0}';
      _taxEnabled = data['taxEnabled'] == true;
      _taxInclusive = data['taxInclusive'] == true;
      _discountEnabled = data['discountEnabled'] != false;
      _taxRate.text = '${data['taxRate'] ?? 0}';
      _maxDiscount.text = '${data['maxDiscountPercent'] ?? 20}';
      _header.text = '${data['receiptHeader'] ?? 'URBAN BYTE'}';
      _footer.text =
          '${data['receiptFooter'] ?? 'Thank you for choosing Urban Byte!'}';
      _tables = (data['diningTables'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _orderTypes = (data['orderTypes'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _kitchenGroups = (data['kitchenPrintGroups'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.save({
        'taxEnabled': _taxEnabled,
        'taxRate': double.tryParse(_taxRate.text) ?? 0,
        'taxInclusive': _taxInclusive,
        'discountEnabled': _discountEnabled,
        'maxDiscountPercent': double.tryParse(_maxDiscount.text) ?? 20,
        'receiptHeader': _header.text.trim(),
        'receiptFooter': _footer.text.trim(),
        'diningTables': _tables,
        'orderTypes': _orderTypes,
        'kitchenPrintGroups': _kitchenGroups,
        'defaultDeliveryUserId': _defaultDeliveryUserId,\n        'deliveryBaseFee': double.tryParse(_deliveryBaseFee.text) ?? 0,\n        'deliveryPerKmFee': double.tryParse(_deliveryPerKmFee.text) ?? 0,\n        'deliveryFreeRadiusKm': double.tryParse(_deliveryFreeRadius.text) ?? 0,
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restaurant settings saved.')));
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addTable() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Add dining table'),
              content: TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Table name (e.g. Table 01)')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Add'))
              ],
            ));
    if (ok == true && name.text.trim().isNotEmpty)
      setState(() => _tables.add({
            'id': 'table_${DateTime.now().microsecondsSinceEpoch}',
            'name': name.text.trim(),
            'isActive': true
          }));
    // name.dispose();
  }

  Future<void> _addOrderType() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Add order type'),
              content: TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Name (e.g. Drive Through)')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Add'))
              ],
            ));
    if (ok == true && name.text.trim().isNotEmpty) {
      final key = name.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      if (_orderTypes.any((e) => e['key'] == key)) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This order type already exists.')));
      } else {
        setState(() => _orderTypes.add({'key': key, 'name': name.text.trim()}));
      }
    }
    name.dispose();
  }

  Future<void> _editKitchenGroup({Map<String, dynamic>? existing}) async {
    final name =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final categoryIds = (existing?['categoryIds'] as List? ?? [])
        .map((e) => e.toString())
        .toSet();
    final productIds = (existing?['productIds'] as List? ?? [])
        .map((e) => e.toString())
        .toSet();
    final excludedIds = (existing?['excludedProductIds'] as List? ?? [])
        .map((e) => e.toString())
        .toSet();
    final activePrinters = _printers
        .where((p) =>
            p['isActive'] != false &&
            ['kitchen', 'both'].contains(p['purpose']))
        .toList();
    String? printerId = existing?['printerId']?.toString() ??
        (activePrinters.isNotEmpty
            ? activePrinters.first['id'].toString()
            : null);
    final categories = <String, String>{};
    for (final p in _products) {
      final category = p['category'];
      if (category is Map && category['id'] != null)
        categories[category['id'].toString()] = category['name'].toString();
    }
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text(existing == null
                      ? 'Add kitchen print group'
                      : 'Edit kitchen print group'),
                  content: SizedBox(
                      width: 520,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            TextField(
                                controller: name,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: const InputDecoration(
                                    labelText:
                                        'Group name (e.g. Kitchen, Pizza, Drinks)')),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: activePrinters.any(
                                      (p) => p['id'].toString() == printerId)
                                  ? printerId
                                  : null,
                              decoration: const InputDecoration(
                                  labelText: 'Kitchen printer'),
                              items: activePrinters
                                  .map((p) => DropdownMenuItem(
                                      value: p['id'].toString(),
                                      child: Text(
                                          '${p['name']} • ${p['connectionType']}')))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => printerId = v),
                            ),
                            const SizedBox(height: 12),
                            const Text('Print all products in these categories',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ...categories.entries
                                .map((entry) => CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(entry.value),
                                      value: categoryIds.contains(entry.key),
                                      onChanged: (v) => setDialogState(() {
                                        if (v == true) {
                                          categoryIds.add(entry.key);
                                        } else {
                                          categoryIds.remove(entry.key);
                                        }
                                      }),
                                    )),
                            const Divider(),
                            const Text('Individual products to print',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ..._products.map((p) => CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title:
                                      Text(p['name']?.toString() ?? 'Product'),
                                  subtitle: Text(p['category'] is Map
                                      ? (p['category']['name']?.toString() ??
                                          '')
                                      : ''),
                                  value:
                                      productIds.contains(p['id'].toString()),
                                  onChanged: (v) => setDialogState(() {
                                    if (v == true) {
                                      productIds.add(p['id'].toString());
                                    } else {
                                      productIds.remove(p['id'].toString());
                                    }
                                  }),
                                )),
                            const Divider(),
                            const Text(
                                'Ignore these products even if their category is selected',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ..._products.map((p) => CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title:
                                      Text(p['name']?.toString() ?? 'Product'),
                                  value:
                                      excludedIds.contains(p['id'].toString()),
                                  onChanged: (v) => setDialogState(() {
                                    if (v == true) {
                                      excludedIds.add(p['id'].toString());
                                    } else {
                                      excludedIds.remove(p['id'].toString());
                                    }
                                  }),
                                )),
                            if (activePrinters.isEmpty)
                              const Text(
                                  'Add an active printer with Kitchen or Both purpose in Printer Management first.'),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: name.text.trim().isEmpty ||
                                printerId == null ||
                                (categoryIds.isEmpty && productIds.isEmpty)
                            ? null
                            : () => Navigator.pop(dialogContext, true),
                        child: const Text('Save group')),
                  ],
                )));
    if (saved == true) {
      final value = {
        'id': existing?['id']?.toString() ??
            'kitchen_${DateTime.now().microsecondsSinceEpoch}',
        'name': name.text.trim(),
        'printerId': int.tryParse(printerId!),
        'categoryIds': categoryIds.map(int.parse).toList(),
        'productIds': productIds.map(int.parse).toList(),
        'excludedProductIds': excludedIds.map(int.parse).toList(),
        'isActive': true,
      };
      setState(() {
        if (existing == null) {
          _kitchenGroups.add(value);
        } else {
          final index =
              _kitchenGroups.indexWhere((g) => g['id'] == existing['id']);
          if (index >= 0) _kitchenGroups[index] = value;
        }
      });
    }
    name.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Restaurant settings'), actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (_error != null)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)))),
                Text('Dining tables',
                    style: Theme.of(context).textTheme.titleLarge),
                const Text(
                    'Add the tables available for dine-in. Occupied tables are blocked while an active order exists.'),
                ..._tables.map((t) => ListTile(
                      leading: const Icon(Icons.table_restaurant),
                      title: Text('${t['name']}'),
                      subtitle: Text(t['isActive'] == false
                          ? 'Inactive'
                          : 'Available for dine-in'),
                      trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _saving
                              ? null
                              : () => setState(() => _tables
                                  .removeWhere((x) => x['id'] == t['id']))),
                    )),
                OutlinedButton.icon(
                    onPressed: _saving ? null : _addTable,
                    icon: const Icon(Icons.add),
                    label: const Text('Add table')),
                const Divider(height: 32),
                Text('Default delivery rider',
                    style: Theme.of(context).textTheme.titleLarge),
                const Text('This rider is preselected in POS for delivery orders. Waiters can choose another rider when creating an order.'),
                DropdownButtonFormField<String?>(
                  value: _deliveryDrivers.any((d) => d['id'].toString() == _defaultDeliveryUserId)
                      ? _defaultDeliveryUserId
                      : null,
                  decoration: const InputDecoration(labelText: 'Default delivery staff'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('No default rider')),
                    ..._deliveryDrivers.map((driver) => DropdownMenuItem<String?>(
                      value: driver['id'].toString(),
                      child: Text('${driver['name'] ?? 'Delivery staff'}${driver['phone'] == null ? '' : ' • ${driver['phone']}'}'),
                    )),
                  ],
                  onChanged: _saving ? null : (value) => setState(() => _defaultDeliveryUserId = value),
                ),
                if (_deliveryDrivers.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline),
                    title: Text('No active Delivery staff found.'),
                    subtitle: Text('Create an employee in Staff Management, assign the Delivery role and a branch, then return here.'),
                  ),
                const Divider(height: 32),
                Text('Order types',
                    style: Theme.of(context).textTheme.titleLarge),
                const Text(
                    'Add or remove order types. At least one Takeaway type must remain.'),
                ..._orderTypes.map((t) => ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text('${t['name']}'),
                      subtitle: Text('${t['key']}'),
                      trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _saving || t['key'] == 'takeaway'
                              ? null
                              : () => setState(() => _orderTypes
                                  .removeWhere((x) => x['key'] == t['key']))),
                    )),
                OutlinedButton.icon(
                    onPressed: _saving ? null : _addOrderType,
                    icon: const Icon(Icons.add),
                    label: const Text('Add order type')),
                const Divider(height: 32),
                Text('Kitchen print groups',
                    style: Theme.of(context).textTheme.titleLarge),
                const Text(
                    'Choose which menu categories and products print on each kitchen slip. Excluded products are ignored even when their category is selected. Kitchen slips print when an order is placed.'),
                ..._kitchenGroups.map((g) {
                  final selectedPrinter = _printers
                      .where((p) =>
                          p['id'].toString() == g['printerId']?.toString())
                      .toList();
                  final categories = (g['categoryIds'] as List? ?? []).length;
                  final products = (g['productIds'] as List? ?? []).length;
                  final ignored =
                      (g['excludedProductIds'] as List? ?? []).length;
                  return Card(
                      child: ListTile(
                    leading: const Icon(Icons.kitchen_outlined),
                    title: Text(g['name']?.toString() ?? 'Kitchen group'),
                    subtitle: Text(
                        '${selectedPrinter.isEmpty ? 'Printer not selected' : selectedPrinter.first['name']} • $categories categories • $products products • $ignored ignored'),
                    trailing: Wrap(children: [
                      IconButton(
                          onPressed: _saving
                              ? null
                              : () => _editKitchenGroup(existing: g),
                          icon: const Icon(Icons.edit_outlined)),
                      IconButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _kitchenGroups
                                  .removeWhere((x) => x['id'] == g['id'])),
                          icon: const Icon(Icons.delete_outline)),
                    ]),
                  ));
                }),
                OutlinedButton.icon(
                    onPressed: _saving ? null : () => _editKitchenGroup(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add kitchen print group')),
                const Divider(height: 32),
                Text('Tax configuration',
                    style: Theme.of(context).textTheme.titleLarge),
                SwitchListTile(
                    title: const Text('Enable tax'),
                    value: _taxEnabled,
                    onChanged: (v) => setState(() => _taxEnabled = v)),
                TextField(
                    controller: _taxRate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Tax rate (%)')),
                SwitchListTile(
                    title: const Text('Tax inclusive pricing'),
                    subtitle:
                        const Text('Tax is included in displayed menu prices.'),
                    value: _taxInclusive,
                    onChanged: (v) => setState(() => _taxInclusive = v)),
                const Divider(height: 32),
                Text('Discount configuration',
                    style: Theme.of(context).textTheme.titleLarge),
                SwitchListTile(
                    title: const Text('Allow order discounts'),
                    value: _discountEnabled,
                    onChanged: (v) => setState(() => _discountEnabled = v)),
                TextField(
                    controller: _maxDiscount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Maximum discount (%)')),
                const Divider(height: 32),
                Text('Receipt branding',
                    style: Theme.of(context).textTheme.titleLarge),
                TextField(
                    controller: _header,
                    decoration:
                        const InputDecoration(labelText: 'Receipt header')),
                TextField(
                    controller: _footer,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Receipt footer')),
                const SizedBox(height: 24),
                FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save settings')),
              ]),
      );
}
