import 'package:flutter/material.dart';
import '../../../app/app.locator.dart';
import '../../../services/operations_service.dart';
import '../notifications/notification_inbox_sheet.dart';
import '../inventory/inventory_view.dart';
import '../orders/restaurant_operations_view.dart';
import '../ai/ai_agent_view.dart';

/// Role-aware starting workspace. Full navigation modules are added incrementally.
class RoleDashboardPlaceholder extends StatelessWidget {
  const RoleDashboardPlaceholder(
      {super.key, required this.roleName, required this.permissions});
  final String roleName;
  final Set<String> permissions;
  bool get _canOpenInventory => permissions.contains('inventory.view');
  bool get _canOpenAI =>
      permissions.contains('ai.view') ||
      permissions.contains('ai.orders.approve');
  bool get _canOpenOrders =>
      permissions.contains('orders.view_own') ||
      permissions.contains('orders.view_all') ||
      permissions.contains('orders.create') ||
      permissions.contains('kitchen.orders.view');
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('$roleName Dashboard'),
          actions: [
            FutureBuilder<int>(
              future: locator<OperationsService>().unreadNotificationCount(),
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
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Urban Byte', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Welcome to your $roleName workspace.'),
          const SizedBox(height: 20),
          if (_canOpenInventory)
            Card(
                child: ListTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
              title: const Text('Inventory management'),
              subtitle:
                  const Text('Branch stock, catalog and low-stock overview'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InventoryView())),
            )),
          if (_canOpenAI)
            Card(
                child: ListTile(
                    leading: const Icon(Icons.smart_toy_outlined),
                    title: const Text('AI Agent'),
                    subtitle: const Text(
                        'Customer conversations and order approvals'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            AiAgentView(permissions: permissions))))),
          if (_canOpenOrders)
            Card(
                child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('Orders & Kitchen'),
                    subtitle: const Text(
                        'Waiter orders, order monitoring and kitchen queue'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RestaurantOperationsView(
                            permissions: permissions))))),
        ]),
      );
}
