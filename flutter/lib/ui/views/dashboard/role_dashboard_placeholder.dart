import 'package:flutter/material.dart';
import '../inventory/inventory_view.dart';

/// Role-aware starting workspace. Full navigation modules are added incrementally.
class RoleDashboardPlaceholder extends StatelessWidget {
  const RoleDashboardPlaceholder({super.key, required this.roleName});
  final String roleName;
  bool get _canOpenInventory => const {'admin','supervisor'}.contains(roleName.toLowerCase());
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
      const Card(child: ListTile(leading: Icon(Icons.receipt_long), title: Text('Orders'), subtitle: Text('Order workspace is coming in the next milestone.'))),
      const Card(child: ListTile(leading: Icon(Icons.restaurant), title: Text('Kitchen'), subtitle: Text('Kitchen display workspace is coming in the next milestone.'))),
    ]),
  );
}
