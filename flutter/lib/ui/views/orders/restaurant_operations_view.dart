import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/inventory_service.dart';
import '../../../services/operations_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/printing_service.dart';
import '../notifications/notification_inbox_sheet.dart';

class RestaurantOperationsView
    extends StackedView<RestaurantOperationsViewModel> {
  const RestaurantOperationsView({super.key, required this.permissions});
  final Set<String> permissions;
  @override
  RestaurantOperationsViewModel viewModelBuilder(BuildContext context) =>
      RestaurantOperationsViewModel(locator<OperationsService>(),
          locator<InventoryService>(), permissions)
        ..load();
  @override
  Widget builder(BuildContext context, RestaurantOperationsViewModel vm,
          Widget? child) =>
      DefaultTabController(
          length: 3,
          child: Scaffold(
              appBar: AppBar(
                  title: const Text('Restaurant operations'),
                  actions: [
                    FutureBuilder<int>(
                      future: locator<OperationsService>()
                          .unreadNotificationCount(),
                      builder: (context, snapshot) => IconButton(
                        tooltip: 'Notifications',
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const NotificationInboxSheet(),
                        ),
                        icon: Badge(
                          isLabelVisible: (snapshot.data ?? 0) > 0,
                          label: Text('${snapshot.data ?? 0}'),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                      ),
                    ),
                  ],
                  bottom: const TabBar(tabs: [
                    Tab(text: 'Orders'),
                    Tab(text: 'Kitchen'),
                    Tab(text: 'New order')
                  ])),
              body: vm.isBusy && !vm.loaded
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [_Orders(vm), _Kitchen(vm), _NewOrder(vm)])));
}

class RestaurantOperationsViewModel extends BaseViewModel {
  RestaurantOperationsViewModel(this.api, this.inventory, this.permissions);
  final OperationsService api;
  final InventoryService inventory;
  final Set<String> permissions;
  bool loaded = false;
  String? loadError;
  List<Map<String, dynamic>> orders = [], tickets = [], products = [];
  List<dynamic> branches = [];
  String branchId = '';
  bool get canCreate => permissions.contains('orders.create');
  bool get canUpdate => permissions.contains('orders.status.update');
  bool get canKitchen => permissions.contains('kitchen.orders.view');
  Future<void> load() async {
    setBusy(true);
    loadError = null;
    try {
      if (permissions.contains('branches.view')) {
        branches = await inventory.branches();
        if (branches.isNotEmpty &&
            !branches.any((b) => '${b.id}' == branchId)) {
          branchId = '${branches.first.id}';
        }
      }
      final tasks = <Future<dynamic>>[];
      final keys = <String>[];
      if (permissions.contains('orders.view_all') ||
          permissions.contains('orders.view_own')) {
        keys.add('orders');
        tasks.add(api.orders(branchId: branchId.isEmpty ? null : branchId));
      }
      if (canKitchen) {
        keys.add('tickets');
        tasks.add(
            api.kitchenQueue(branchId: branchId.isEmpty ? null : branchId));
      }
      if (permissions.contains('menu.view') || canCreate) {
        keys.add('products');
        tasks.add(api.menu());
      }
      final results = await Future.wait(tasks);
      for (var i = 0; i < keys.length; i++) {
        switch (keys[i]) {
          case 'orders':
            orders = List<Map<String, dynamic>>.from(results[i] as List);
          case 'tickets':
            tickets = List<Map<String, dynamic>>.from(results[i] as List);
          case 'products':
            products = List<Map<String, dynamic>>.from(results[i] as List);
        }
      }
      loaded = true;
    } catch (e) {
      loadError = e.toString();
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> selectBranch(String? value) async {
    if (value == null || value == branchId) return;
    branchId = value;
    await load();
  }

  Future<void> changeStatus(String id, String status) async {
    await _run(() => api.updateOrder(id, status));
  }

  Future<void> kitchen(String id, String action) async {
    await _run(() => api.kitchenAction(id, action));
  }

  Future<void> create(String type, List<Map<String, dynamic>> lines,
      {String? table, String? name, String? phone, String? address}) async {
    await _run(() async {
      await api.createOrder(
          branchId: branchId,
          orderType: type,
          items: lines,
          tableLabel: table,
          customerName: name,
          customerPhone: phone,
          deliveryAddress: address);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setBusy(true);
    loadError = null;
    try {
      await action();
      await load();
    } catch (e) {
      loadError = e.toString();
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }
}

class _Orders extends StatelessWidget {
  const _Orders(this.vm);
  final RestaurantOperationsViewModel vm;
  Future<void> _printPaidBill(
      BuildContext context, Map<String, dynamic> order) async {
    try {
      final printing = PrintingService();
      final printers =
          await printing.printers(branchId: order['branchId']?.toString());
      final bluetooth = printers
          .where((p) =>
              p['connectionType'] == 'bluetooth' &&
              p['isActive'] != false &&
              (p['purpose'] == 'receipt' || p['purpose'] == 'both'))
          .toList();
      if (bluetooth.isEmpty) {
        await printing.enqueueReceipt(order['id'].toString());
        return;
      }
      final lines = <String>[
        'URBAN BYTE',
        'CUSTOMER BILL',
        'Order: ${order['orderNumber'] ?? order['id']}',
        'Date: ${DateTime.now().toLocal()}',
        '--------------------------------',
        ...((order['items'] as List? ?? []).map((item) =>
            '${item['quantity']} x ${item['productName']} ${item['variantName'] ?? ''}  PKR ${item['lineTotal'] ?? ''}')),
        '--------------------------------',
        'Subtotal: PKR ${order['subtotal'] ?? ''}',
        'Discount: PKR ${order['discountAmount'] ?? 0}',
        'Tax: PKR ${order['taxAmount'] ?? 0}',
        'TOTAL: PKR ${order['grandTotal'] ?? ''}',
        'Payment: PAID',
        '',
        'Thank you for visiting Urban Byte!',
        '',
        '',
      ];
      await printing.printBluetoothText(
          bluetooth.first['deviceIdentifier'].toString(), lines.join('\n'));
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Paid bill printed.')));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Payment saved, but bill printing failed: $e')));
    }
  }

  Future<void> _collectPayment(BuildContext context, Map<String, dynamic> order,
      double due, RestaurantOperationsViewModel vm) async {
    final amount = TextEditingController(text: due.toStringAsFixed(2));
    final reference = TextEditingController();
    String method = 'cash';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text(
                      'Receive payment • ${order['orderNumber'] ?? order['id']}'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Remaining: PKR ${due.toStringAsFixed(2)}'),
                    DropdownButtonFormField<String>(
                        value: method,
                        decoration:
                            const InputDecoration(labelText: 'Payment method'),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'card', child: Text('Card')),
                          DropdownMenuItem(
                              value: 'easypaisa', child: Text('Easypaisa')),
                          DropdownMenuItem(
                              value: 'jazzcash', child: Text('JazzCash')),
                          DropdownMenuItem(
                              value: 'bank_transfer',
                              child: Text('Bank transfer')),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => method = v ?? 'cash')),
                    TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Amount received (PKR)')),
                    if (method != 'cash')
                      TextField(
                          controller: reference,
                          decoration: const InputDecoration(
                              labelText: 'Transaction reference')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Confirm received')),
                  ],
                )));
    if (confirmed != true) {
      amount.dispose();
      reference.dispose();
      return;
    }
    final value = double.tryParse(amount.text.trim());
    if (value == null || value <= 0 || value > due) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enter an amount within the remaining balance.')));
      amount.dispose();
      reference.dispose();
      return;
    }
    try {
      final payment = await PaymentService().record(
          orderId: '${order['id']}',
          amount: value,
          method: method,
          reference: reference.text,
          markReceived: method != 'cod');
      final paidBefore = (order['payments'] as List? ?? [])
          .where((p) => p['status'] == 'verified')
          .fold<double>(0,
              (sum, p) => sum + (double.tryParse('${p['amount'] ?? 0}') ?? 0));
      final total = double.tryParse('${order['grandTotal'] ?? 0}') ?? 0;
      final fullyPaid =
          payment['status'] == 'verified' && paidBefore + value >= total;
      await vm.load();
      if (fullyPaid) await _printPaidBill(context, order);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment received and updated.')));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
    amount.dispose();
    reference.dispose();
  }

  @override
  Widget build(BuildContext context) => !vm.permissions
              .contains('orders.view_all') &&
          !vm.permissions.contains('orders.view_own')
      ? const Center(child: Text('You do not have permission to view orders.'))
      : RefreshIndicator(
          onRefresh: vm.load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (vm.loadError != null)
              Text(vm.loadError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (vm.orders.isEmpty) const Text('No orders found.'),
            ...vm.orders.map((o) {
              final id = '${o['id']}';
              final status = '${o['status'] ?? 'placed'}';
              final items = (o['items'] as List? ?? []);
              return Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${o['orderNumber'] ?? 'Order #$id'}',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                '${o['orderType']} • ${o['tableLabel'] ?? o['customerName'] ?? ''}'),
                            Builder(builder: (context) {
                              final total =
                                  double.tryParse('${o['grandTotal'] ?? 0}') ??
                                      0;
                              final payments = (o['payments'] as List? ?? []);
                              final paid = payments
                                  .where((p) => p['status'] == 'verified')
                                  .fold<double>(
                                      0,
                                      (sum, p) =>
                                          sum +
                                          (double.tryParse(
                                                  '${p['amount'] ?? 0}') ??
                                              0));
                              final pending = payments
                                  .where((p) => p['status'] == 'pending')
                                  .fold<double>(
                                      0,
                                      (sum, p) =>
                                          sum +
                                          (double.tryParse(
                                                  '${p['amount'] ?? 0}') ??
                                              0));
                              final remaining =
                                  (total - paid).clamp(0, total).toDouble();
                              final due = (remaining - pending)
                                  .clamp(0, total)
                                  .toDouble();
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Order status: $status • Payment status: ${o['paymentStatus'] ?? 'unpaid'}'),
                                    Text(
                                        'Order total: PKR ${total.toStringAsFixed(2)}'),
                                    Text(
                                        'Verified paid: PKR ${paid.toStringAsFixed(2)} • Awaiting verification: PKR ${pending.toStringAsFixed(2)}'),
                                    Text(
                                        'Remaining balance: PKR ${remaining.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    if (due > 0 &&
                                        vm.permissions
                                            .contains('payments.record'))
                                      Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: vm.isBusy
                                                ? null
                                                : () => _collectPayment(
                                                    context, o, due, vm),
                                            icon: const Icon(
                                                Icons.payments_outlined),
                                            label: const Text(
                                                'Receive payment now'),
                                          )),
                                  ]);
                            }),
                            Text(items
                                .map((i) =>
                                    '${i['quantity']} × ${i['productName']}')
                                .join(', ')),
                            if (vm.canUpdate &&
                                (status == 'ready' ||
                                    status == 'out_for_delivery') &&
                                o['paymentStatus'] == 'paid')
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: vm.isBusy
                                      ? null
                                      : () async {
                                          await vm.changeStatus(
                                              id, 'completed');
                                          if (vm.loadError == null &&
                                              context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Order marked completed.')));
                                          }
                                        },
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Complete order'),
                                ),
                              ),
                            if (vm.canUpdate && status == 'placed')
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                      onPressed: vm.isBusy
                                          ? null
                                          : () =>
                                              vm.changeStatus(id, 'confirmed'),
                                      child: const Text('Confirm order')))
                          ])));
            })
          ]));
}

class _Kitchen extends StatefulWidget {
  const _Kitchen(this.vm);
  final RestaurantOperationsViewModel vm;
  @override
  State<_Kitchen> createState() => _KitchenState();
}

class _KitchenState extends State<_Kitchen> {
  Timer? _refreshTimer;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !widget.vm.isBusy && widget.vm.canKitchen) {
        widget.vm.load();
      }
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  String _elapsed(dynamic placedAt) {
    final started = DateTime.tryParse('${placedAt ?? ''}')?.toLocal();
    if (started == null) return 'Time unavailable';
    final duration = DateTime.now().difference(started);
    final minutes = duration.inMinutes;
    return minutes < 60
        ? '${minutes}m ${duration.inSeconds % 60}s'
        : '${duration.inHours}h ${minutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return !vm.canKitchen
        ? const Center(
            child: Text('You do not have permission to view kitchen tickets.'))
        : RefreshIndicator(
            onRefresh: vm.load,
            child: ListView(padding: const EdgeInsets.all(12), children: [
              if (vm.branches.isNotEmpty)
                DropdownButtonFormField<String>(
                    value: vm.branchId,
                    decoration:
                        const InputDecoration(labelText: 'Kitchen branch'),
                    items: vm.branches
                        .map((b) => DropdownMenuItem<String>(
                            value: '${b.id}', child: Text(b.name)))
                        .toList(),
                    onChanged: vm.isBusy ? null : vm.selectBranch),
              if (vm.loadError != null) Text(vm.loadError!),
              if (vm.tickets.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: Text(
                            'Kitchen queue is empty. New confirmed orders will appear here.'))),
              ...vm.tickets.map((t) {
                final id = '${t['id']}';
                final status = '${t['status']}';
                final order = t['order'] as Map? ?? const {};
                final items = t['items'] as List? ?? [];
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t['ticketNumber'] ?? 'Ticket #$id'}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                  'Order ${order['orderNumber'] ?? ''} • ${order['tableLabel'] ?? order['orderType'] ?? ''}'),
                              if (order['customerName'] != null)
                                Text('Customer: ${order['customerName']}'),
                              if (order['notes'] != null &&
                                  '${order['notes']}'.isNotEmpty)
                                Text('Order notes: ${order['notes']}'),
                              ...items.map((i) => ListTile(
                                  dense: true,
                                  title: Text(
                                      '${i['quantity']} × ${i['productName']} ${i['variantName'] ?? ''}'),
                                  subtitle: Text('${i['notes'] ?? ''}'))),
                              if (status == 'pending')
                                FilledButton(
                                    onPressed: vm.isBusy
                                        ? null
                                        : () => vm.kitchen(id, 'prepare'),
                                    child: const Text('Start preparing'))
                              else if (status == 'preparing')
                                FilledButton(
                                    onPressed: vm.isBusy
                                        ? null
                                        : () => vm.kitchen(id, 'ready'),
                                    child: const Text('Mark ready'))
                            ])));
              })
            ]));
  }
}

class _NewOrder extends StatefulWidget {
  const _NewOrder(this.vm);
  final RestaurantOperationsViewModel vm;
  @override
  State<_NewOrder> createState() => _NewOrderState();
}

class _NewOrderState extends State<_NewOrder> {
  String type = 'takeaway';
  String? variantId;
  final table = TextEditingController(),
      name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController();
  final Map<String, int> cart = {};
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    table.dispose();
    name.dispose();
    phone.dispose();
    address.dispose();
    search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get variants {
    final out = <Map<String, dynamic>>[];
    for (final p in widget.vm.products) {
      final vs = p['variants'] as List? ?? p['productVariants'] as List? ?? [];
      for (final v in vs) {
        out.add({
          ...Map<String, dynamic>.from(v as Map),
          '_productName': p['name'] ?? 'Product'
        });
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final available = variants
        .where((v) =>
            ('${v['_productName']} ${v['name'] ?? v['variantName'] ?? ''}')
                .toLowerCase()
                .contains(search.text.toLowerCase()))
        .toList();
    final allVariants = variants;
    final total = allVariants.fold<double>(
        0,
        (sum, v) =>
            sum +
            ((cart['${v['id']}'] ?? 0) *
                (double.tryParse('${v['salePrice'] ?? v['basePrice'] ?? 0}') ??
                    0)));
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (!vm.canCreate)
        const Text('Your account does not have order creation permission.')
      else if (vm.branches.isEmpty)
        const Text('No active branch is available.')
      else ...[
        DropdownButtonFormField<String>(
            value: vm.branchId,
            decoration: const InputDecoration(labelText: 'Branch'),
            items: vm.branches
                .map((b) =>
                    DropdownMenuItem(value: '${b.id}', child: Text(b.name)))
                .toList(),
            onChanged: (v) => setState(() => vm.branchId = v ?? vm.branchId)),
        DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'Order type'),
            items: const [
              DropdownMenuItem(value: 'takeaway', child: Text('Takeaway')),
              DropdownMenuItem(value: 'dine_in', child: Text('Dine in')),
              DropdownMenuItem(value: 'delivery', child: Text('Delivery'))
            ],
            onChanged: (v) => setState(() => type = v ?? 'takeaway')),
        if (type == 'dine_in')
          TextField(
              controller: table,
              decoration: const InputDecoration(labelText: 'Table label')),
        if (type == 'delivery')
          TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Delivery address')),
        TextField(
            controller: name,
            decoration:
                const InputDecoration(labelText: 'Customer name (optional)')),
        TextField(
            controller: phone,
            decoration:
                const InputDecoration(labelText: 'Customer phone (optional)')),
        const SizedBox(height: 12),
        Text('Menu products', style: Theme.of(context).textTheme.titleMedium),
        TextField(
            controller: search,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), labelText: 'Search products')),
        if (available.isEmpty)
          const Text('No active product variants returned by the menu API.'),
        ...available.map((v) {
          final id = '${v['id']}';
          final count = cart[id] ?? 0;
          return Card(
              child: ListTile(
                  title: Text(
                      '${v['_productName']} • ${v['name'] ?? v['variantName'] ?? 'Variant'}'),
                  subtitle:
                      Text('PKR ${v['basePrice'] ?? v['salePrice'] ?? ''}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        onPressed: count == 0
                            ? null
                            : () => setState(() => cart[id] = count - 1),
                        icon: const Icon(Icons.remove)),
                    Text('$count'),
                    IconButton(
                        onPressed: () => setState(() => cart[id] = count + 1),
                        icon: const Icon(Icons.add))
                  ])));
        }),
        const SizedBox(height: 12),
        Card(
            child: ListTile(
                title: const Text('Cart total'),
                trailing: Text('PKR ${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge))),
        FilledButton(
            onPressed: vm.isBusy ||
                    cart.values.every((q) => q == 0) ||
                    (type == 'dine_in' && table.text.trim().isEmpty) ||
                    (type == 'delivery' && address.text.trim().isEmpty)
                ? null
                : () => vm.create(
                    type,
                    cart.entries
                        .where((e) => e.value > 0)
                        .map((e) => {
                              'variantId': int.parse(e.key),
                              'quantity': e.value
                            })
                        .toList(),
                    table: table.text.trim(),
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                    address: address.text.trim()),
            child: const Text('Place order'))
      ],
      if (vm.loadError != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(vm.loadError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)))
    ]);
  }
}
