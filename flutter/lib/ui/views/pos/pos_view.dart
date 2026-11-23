import 'package:flutter/material.dart';
import 'package:urban_byte/models/inventory_item.dart';
import '../../../app/app.locator.dart';
import '../../../services/inventory_service.dart';
import '../../../services/operations_service.dart';
import '../../../services/printing_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/restaurant_settings_service.dart';

class PosView extends StatefulWidget {
  const PosView({super.key});
  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final _ops = locator<OperationsService>();
  final _inventory = locator<InventoryService>();
  final _printing = PrintingService();
  final _payments = PaymentService();
  final _settingsService = RestaurantSettingsService();
  final _cart = <String, Map<String, dynamic>>{};
  String? _tableId;
  final _customer = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _discount = TextEditingController(text: '0');
  List<RestaurantBranch> _branches = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _orderTypes = [];
  String? _branchId;
  String? _categoryId;
  String _type = 'takeaway';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customer.dispose();
    _phone.dispose();
    _address.dispose();
    _discount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await _inventory.branches();
      if (branches.isEmpty) throw Exception('No active branch found.');
      final branchId = _branchId ?? branches.first.id;
      final results = await Future.wait<dynamic>(
          [_ops.menu(branchId: branchId), _settingsService.load()]);
      final products = results[0] as List<Map<String, dynamic>>;
      final settings = results[1] as Map<String, dynamic>;
      final tables = (settings['diningTables'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((t) =>
              t['isActive'] != false &&
              (t['branchId'] == null || t['branchId'].toString() == branchId))
          .toList();
      final orderTypes = (settings['orderTypes'] as List? ??
              const [
                {'key': 'dine_in', 'name': 'Dine In'},
                {'key': 'takeaway', 'name': 'Takeaway'},
                {'key': 'delivery', 'name': 'Delivery'}
              ])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _branchId = branchId;
        _products = products
            .where((p) => p['isActive'] != false && p['isAvailable'] != false)
            .toList();
        _tables = tables;
        _orderTypes = orderTypes;
        if (!_orderTypes.any((t) => t['key'] == _type))
          _type = _orderTypes.isNotEmpty
              ? _orderTypes.first['key'].toString()
              : 'takeaway';
        if (_tableId != null &&
            !_tables.any((t) => t['id'].toString() == _tableId))
          _tableId = null;
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

  double get _total => _cart.values.fold(
      0.0,
      (sum, item) =>
          sum +
          (double.tryParse(item['price'].toString()) ?? 0) *
              (item['qty'] as int));

  void _add(Map<String, dynamic> product) {
    final variants = (product['variants'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .where((v) => v['isActive'] != false)
        .toList();
    if (variants.isEmpty) {
      _message('No active price variant for this product.');
      return;
    }
    final variant = variants.firstWhere((v) => v['isDefault'] == true,
        orElse: () => variants.first);
    final prices = (variant['branchPrices'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    final matchingPrices =
        prices.where((p) => p['branchId']?.toString() == _branchId).toList();
    final branchPrice = matchingPrices.isEmpty ? null : matchingPrices.first;
    if (branchPrice != null && branchPrice['isAvailable'] == false) {
      _message('Product unavailable at this branch.');
      return;
    }
    final price = double.tryParse(
            (branchPrice?['salePrice'] ?? variant['basePrice']).toString()) ??
        0;
    final id = variant['id'].toString();
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!['qty'] = (_cart[id]!['qty'] as int) + 1;
      } else {
        _cart[id] = {
          'variantId': id,
          'name':
              product['name'].toString() + ' · ' + variant['name'].toString(),
          'price': price,
          'qty': 1
        };
      }
    });
  }

  Future<void> _place() async {
    if (_cart.isEmpty || _branchId == null) return;
    if (_type == 'dine_in' && (_tableId == null || _tableId!.isEmpty)) {
      _message('Select a configured dining table.');
      return;
    }
    if (_type == 'delivery' && _address.text.trim().isEmpty) {
      _message('Enter delivery address.');
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _ops.createOrder(
        branchId: _branchId!,
        orderType: _type,
        tableLabel: _type == 'dine_in'
            ? (_tables
                .firstWhere((t) => t['id'].toString() == _tableId)['name']
                ?.toString())
            : null,
        deliveryAddress: _type == 'delivery' ? _address.text.trim() : null,
        customerName:
            _customer.text.trim().isEmpty ? null : _customer.text.trim(),
        customerPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        discountAmount: double.tryParse(_discount.text.trim()) ?? 0,
        items: _cart.values
            .map((i) => {
                  'variantId': int.parse(i['variantId'].toString()),
                  'quantity': i['qty']
                })
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _saving = false;
      });
      final orderId = result['id']?.toString();
      final orderNumber = result['orderNumber']?.toString() ?? orderId ?? '';
      final total = double.tryParse(
              (result['grandTotal'] ?? result['total'] ?? _total).toString()) ??
          _total;
      if (orderId != null) {
        await _printBluetoothKitchenTickets(result);
        final printReceipt = await _checkoutDialog(orderId, orderNumber, total);
        if (printReceipt) {
          result['paymentStatus'] = 'paid';
          await _printBluetoothReceipt(result);
        }
      } else {
        _message('Order created: $orderNumber');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _message(e.toString());
      }
    }
  }

  Future<bool> _checkoutDialog(
      String orderId, String orderNumber, double total) async {
    var printReceipt = false;
    final amount = TextEditingController(text: total.toStringAsFixed(2));
    final reference = TextEditingController();
    String method = 'cash';
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Checkout · $orderNumber'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Order total: PKR ${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'easypaisa', child: Text('Easypaisa')),
                DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(
                    value: 'bank_transfer', child: Text('Bank transfer')),
                DropdownMenuItem(value: 'cod', child: Text('Cash on delivery')),
              ],
              onChanged: saving
                  ? null
                  : (v) => setDialogState(() => method = v ?? 'cash'),
            ),
            if (method != 'cod') TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Amount received (PKR)')),
            if (method != 'cash' && method != 'cod')
              TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                      labelText: 'Transaction reference (optional)')),
            const SizedBox(height: 8),
            Text(
                method == 'cod'
                    ? 'Cash on delivery: skip payment now and receive it later from the Orders tab.'
                    : 'Confirm only after the customer has actually paid.',
                style: const TextStyle(fontSize: 12)),
          ])),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Save order / pay later')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (method == 'cod') {
                        setDialogState(() => saving = true);
                        try {
                          await _payments.setCashOnDelivery(orderId: orderId);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (mounted) _message('Cash on delivery saved. Assign a delivery rider from Delivery Management.');
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(e.toString())));
                          }
                        }
                        return;
                      }
                      final paid = double.tryParse(amount.text.trim());
                      if (paid == null || paid <= 0 || paid > total) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Enter a valid amount not exceeding the order total.')));
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final payment = await _payments.record(
                            orderId: orderId,
                            amount: paid,
                            method: method,
                            reference: reference.text,
                            markReceived: method != 'cod');
                        final verified = payment['status'] == 'verified';
                        printReceipt = verified && paid >= total;
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          _message(verified
                              ? 'Cash payment verified and recorded.'
                              : 'Payment recorded as pending. An authorized user must verify it.');
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (dialogContext.mounted)
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(e.toString())));
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(method == 'cod' ? 'Confirm COD order' : 'Confirm received'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    reference.dispose();
    return printReceipt;
  }

  Future<void> _printBluetoothKitchenTickets(Map<String, dynamic> order) async {
    if (order['kitchenPrintError'] != null && mounted)
      _message(order['kitchenPrintError'].toString());
    final tickets = (order['kitchenPrints'] as List? ?? []);
    for (final ticket in tickets) {
      try {
        final mac = ticket['printerMac']?.toString() ?? '';
        final text = ticket['renderedText']?.toString() ?? '';
        if (mac.isEmpty || text.isEmpty) continue;
        await _printing.printBluetoothText(mac, text);
      } catch (e) {
        if (mounted) _message('Order saved, but kitchen slip failed: $e');
      }
    }
  }

  Future<void> _printBluetoothReceipt(Map<String, dynamic> order) async {
    try {
      final printers = await _printing.printers(branchId: _branchId);
      final candidates = printers
          .where((p) =>
              p['connectionType'] == 'bluetooth' &&
              p['isActive'] != false &&
              (p['purpose'] == 'receipt' || p['purpose'] == 'both'))
          .toList();
      if (candidates.isEmpty) {
        final orderId = order['id']?.toString();
        if (orderId != null) await _printing.enqueueReceipt(orderId);
        return;
      }
      final printer = candidates.first;
      final items = (order['items'] as List? ?? []);
      final lines = <String>[
        'URBAN BYTE',
        'ORDER RECEIPT',
        'Order: ${order['orderNumber'] ?? order['id'] ?? ''}',
        if (order['tableLabel'] != null) 'Table: ${order['tableLabel']}',
        'Date: ${DateTime.now().toLocal()}',
        '--------------------------------',
        ...items.map((item) =>
            '${item['quantity']} x ${item['productName']} ${item['variantName'] ?? ''}  PKR ${item['lineTotal'] ?? ''}'),
        '--------------------------------',
        'Subtotal: PKR ${order['subtotal'] ?? ''}',
        'Discount: PKR ${order['discountAmount'] ?? 0}',
        'Tax: PKR ${order['taxAmount'] ?? 0}',
        'Service charge: PKR ${order['serviceChargeAmount'] ?? 0}',
        'TOTAL: PKR ${order['grandTotal'] ?? ''}',
        'Payment: ${order['paymentStatus'] ?? 'unpaid'}',
        '',
        'Thank you for visiting Urban Byte!',
        '',
        '',
      ];
      await _printing.printBluetoothText(
          printer['deviceIdentifier'].toString(), lines.join('\n'));
      if (mounted) _message('Receipt printed on mobile Bluetooth printer.');
    } catch (e) {
      if (mounted) _message('Order saved, but Bluetooth receipt failed: $e');
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final categories = <String, String>{};
    for (final p in _products) {
      final c = p['category'];
      if (c is Map && c['id'] != null)
        categories[c['id'].toString()] = c['name'].toString();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Urban Byte POS'), actions: [
        IconButton(
            onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry'))
                      ])))
              : LayoutBuilder(builder: (context, size) {
                  final menu = _menu(categories);
                  final cart = _cartPanel();
                  return size.maxWidth >= 850
                      ? Row(children: [
                          Expanded(flex: 3, child: menu),
                          const VerticalDivider(width: 1),
                          Expanded(flex: 2, child: cart)
                        ])
                      : Column(children: [
                          Expanded(child: menu),
                          const Divider(height: 1),
                          SizedBox(height: 310, child: cart)
                        ]);
                }),
    );
  }

  Widget _menu(Map<String, String> categories) => Column(children: [
        Padding(
            padding: const EdgeInsets.all(10),
            child: DropdownButtonFormField<String>(
              value: _branchId,
              decoration: const InputDecoration(
                  labelText: 'Branch', border: OutlineInputBorder()),
              items: _branches
                  .map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _branchId = v;
                    _cart.clear();
                  });
                  _load();
                }
              },
            )),
        SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              ChoiceChip(
                  label: const Text('All'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null)),
              ...categories.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                      label: Text(e.value),
                      selected: _categoryId == e.key,
                      onSelected: (_) => setState(() => _categoryId = e.key))))
            ])),
        Expanded(
            child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8),
                itemCount: _products
                    .where((p) =>
                        _categoryId == null ||
                        (p['category'] is Map &&
                            p['category']['id'].toString() == _categoryId))
                    .length,
                itemBuilder: (context, index) {
                  final filtered = _products
                      .where((p) =>
                          _categoryId == null ||
                          (p['category'] is Map &&
                              p['category']['id'].toString() == _categoryId))
                      .toList();
                  final p = filtered[index];
                  final variants = (p['variants'] as List? ?? []);
                  final variant = variants.isEmpty
                      ? null
                      : variants.firstWhere(
                          (v) => (v as Map)['isDefault'] == true,
                          orElse: () => variants.first) as Map;
                  final branchPrices = variant == null
                      ? <Map<String, dynamic>>[]
                      : (variant['branchPrices'] as List? ?? [])
                          .map((value) =>
                              Map<String, dynamic>.from(value as Map))
                          .toList();
                  final selectedBranchPrices = branchPrices
                      .where(
                          (value) => value['branchId']?.toString() == _branchId)
                      .toList();
                  final price = variant == null
                      ? '—'
                      : (selectedBranchPrices.isNotEmpty
                          ? selectedBranchPrices.first['salePrice']
                                  ?.toString() ??
                              variant['basePrice']?.toString() ??
                              '—'
                          : variant['basePrice']?.toString() ?? '—');
                  return Card(
                      child: InkWell(
                          onTap: () => _add(p),
                          child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(p['name'].toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('PKR ' + price),
                                          const Icon(Icons.add_circle_outline)
                                        ])
                                  ]))));
                })),
      ]);

  Widget _cartPanel() => Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Current order',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text('Select products to start an order.'))
                : ListView(
                    children: _cart.entries.map((entry) {
                    final i = entry.value;
                    return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(i['name'].toString()),
                        subtitle: Text(
                            'PKR ' + (i['price'] as double).toStringAsFixed(2)),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              onPressed: () => setState(() {
                                    final q = i['qty'] as int;
                                    if (q <= 1) {
                                      _cart.remove(entry.key);
                                    } else {
                                      i['qty'] = q - 1;
                                    }
                                  }),
                              icon: const Icon(Icons.remove_circle_outline)),
                          Text(i['qty'].toString()),
                          IconButton(
                              onPressed: () => setState(
                                  () => i['qty'] = (i['qty'] as int) + 1),
                              icon: const Icon(Icons.add_circle_outline))
                        ]));
                  }).toList())),
        DropdownButtonFormField<String>(
            value: _orderTypes.any((t) => t['key'] == _type) ? _type : null,
            decoration: const InputDecoration(labelText: 'Order type'),
            items: _orderTypes
                .map((t) => DropdownMenuItem<String>(
                    value: t['key'].toString(),
                    child: Text(t['name'].toString())))
                .toList(),
            onChanged: (v) => setState(() {
                  _type = v ?? _type;
                  if (_type != 'dine_in') _tableId = null;
                })),
        if (_type == 'dine_in')
          DropdownButtonFormField<String>(
              value: _tables.any((t) => t['id'].toString() == _tableId)
                  ? _tableId
                  : null,
              decoration:
                  const InputDecoration(labelText: 'Select dining table'),
              items: _tables
                  .map((t) => DropdownMenuItem<String>(
                      value: t['id'].toString(),
                      child: Text(t['name'].toString())))
                  .toList(),
              onChanged: (v) => setState(() => _tableId = v)),
        if (_type == 'dine_in' && _tables.isEmpty)
          const Text(
              'No active dining tables. Add tables in Restaurant Settings first.'),
        if (_type == 'delivery')
          TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Delivery address')),
        TextField(
            controller: _customer,
            decoration:
                const InputDecoration(labelText: 'Customer name (optional)')),
        TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration:
                const InputDecoration(labelText: 'Customer phone (optional)')),
        TextField(
            controller: _discount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Discount amount (PKR)')),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Subtotal preview (before tax/discount)'),
          Text('PKR ' + _total.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
        ]),
        const SizedBox(height: 6),
        FilledButton.icon(
            onPressed: _saving || _cart.isEmpty ? null : _place,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.point_of_sale),
            label: Text(_saving ? 'Confirming order...' : 'Confirm order'))
      ]));
}
