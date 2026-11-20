import 'package:flutter/material.dart';
import '../inventory/inventory_view.dart';
import '../orders/restaurant_operations_view.dart';

/// Role-aware starting workspace. Full navigation modules are added incrementally.
class RoleDashboardPlaceholder extends StatelessWidget {
  const RoleDashboardPlaceholder({super.key, required this.roleName, required this.permissions});
  final String roleName;
  final Set<String> permissions;
  bool get _canOpenInventory => permissions.contains('inventory.view');
  bool get _canOpenOrders => permissions.contains('orders.view_own') || permissions.contains('orders.view_all') || permissions.contains('orders.create') || permissions.contains('kitchen.orders.view');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$roleName Dashboard')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Urban Byte', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text('Welcome to your $roleName workspace.'),
      const SizedBox(height: 20),
      if (_canOpenInventory)
        Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
          title: const Text('Inventory management'),
          subtitle: const Text('Branch stock, catalog and low-stock overview'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryView())),
        )),
      if (_canOpenOrders) Card(child: ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Orders & Kitchen'), subtitle: const Text('Waiter orders, order monitoring and kitchen queue'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RestaurantOperationsView(permissions: permissions))))),
    ]),
  );
}
