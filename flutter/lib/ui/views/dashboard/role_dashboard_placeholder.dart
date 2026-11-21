import 'package:flutter/material.dart';
import '../../../app/app.locator.dart';
import '../../../services/operations_service.dart';
import '../notifications/notification_inbox_sheet.dart';
import '../inventory/inventory_view.dart';
import '../orders/restaurant_operations_view.dart';
import '../ai/ai_agent_view.dart';
import '../printing/printing_view.dart';
import '../delivery/delivery_view.dart';

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
          const SizedBox(height: 16),
          if (permissions.contains('dashboard.view'))
            FutureBuilder<Map<String, dynamic>>(
              future: locator<OperationsService>().dashboardSummary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off),
                      title: const Text('Dashboard data unavailable'),
                      subtitle: Text(snapshot.error.toString()),
                    ),
                  );
                }
                final data = snapshot.data ?? {};
                final metrics = Map<String, dynamic>.from(data['metrics'] as Map? ?? {});
                final money = metrics['paidRevenueToday']?.toString() ?? '0.00';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Today's overview",
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MetricTile(label: 'Orders today', value: '${metrics['todayOrders'] ?? 0}'),
                            _MetricTile(label: 'Open orders', value: '${metrics['openOrders'] ?? 0}'),
                            _MetricTile(label: 'Completed', value: '${metrics['completedToday'] ?? 0}'),
                            _MetricTile(label: 'Pending payments', value: '${metrics['pendingPayments'] ?? 0}'),
                            _MetricTile(label: 'Paid revenue', value: 'PKR $money'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Timezone: ${data['timezone'] ?? 'Asia/Karachi'}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                );
              },
            ),
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
          if (permissions.contains('printers.view') || permissions.contains('printers.manage') || permissions.contains('printing.view'))
            Card(child: ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Printer management'),
              subtitle: const Text('Printers, receipt queue and kitchen tickets'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PrintingView(permissions: permissions))),
            )),
          if (permissions.contains('delivery.view_assigned') || permissions.contains('delivery.assignments.view_all'))
            Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
              title: const Text('Delivery management'),
              subtitle: const Text('Assigned orders, delivery status and COD collection'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DeliveryView(permissions: permissions))),
            )),
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


class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 145,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}
