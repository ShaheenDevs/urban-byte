import 'package:flutter/material.dart';
import '../../../app/app.locator.dart';
import '../../../services/operations_service.dart';
import '../notifications/notification_inbox_sheet.dart';
import '../inventory/inventory_view.dart';
import '../orders/restaurant_operations_view.dart';
import '../ai/ai_agent_view.dart';
import '../printing/printing_view.dart';
import '../delivery/delivery_view.dart';
import '../staff/staff_view.dart';
import '../pos/pos_view.dart';
import '../payments/payment_verification_view.dart';
import '../cash_shift/cash_shift_view.dart';
import '../reports/financial_reports_view.dart';
import '../branch_operations/branch_operations_view.dart';
import '../attendance_shifts/attendance_shift_view.dart';
import '../stock_transfers/stock_transfer_view.dart';
import '../owner_dashboard/consolidated_owner_dashboard_view.dart';
import '../expenses/expenses_view.dart';
import '../suppliers/suppliers_view.dart';
import '../purchases/purchases_view.dart';
import '../inventory/stock_control_view.dart';
import '../settings/restaurant_settings_view.dart';
import 'dashboard_orders_view.dart';

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
          if (roleName.trim().toLowerCase() == 'admin' && permissions.contains('reports.view'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.dashboard_customize_outlined)),
                title: const Text('Consolidated Owner Dashboard'),
                subtitle: const Text('All branches: sales, profit, expenses, cash and supplier dues'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConsolidatedOwnerDashboardView()),
                ),
              ),
            ),
          if (permissions.contains('dashboard.view'))
            DashboardSummaryPanel(permissions: permissions),
          const SizedBox(height: 20),
          if (permissions.contains('orders.create') ||
              permissions.contains('pos.use'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.point_of_sale)),
                title: const Text('Point of Sale'),
                subtitle:
                    const Text('Create dine-in, takeaway and delivery orders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PosView()),
                ),
              ),
            ),
          if (permissions.contains('payments.verify') ||
              permissions.contains('payments.view'))
            Card(
              child: ListTile(
                leading:
                    const CircleAvatar(child: Icon(Icons.fact_check_outlined)),
                title: const Text('Payment verification'),
                subtitle: const Text(
                    'Review pending payments and verify received funds'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PaymentVerificationView()),
                ),
              ),
            ),
          if (permissions.contains('cash_shifts.open') ||
              permissions.contains('cash_shifts.view'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.point_of_sale_outlined)),
                title: const Text('Cashier shift'),
                subtitle: const Text(
                    'Open shift, cash in/out and close with reconciliation'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CashShiftView()),
                ),
              ),
            ),
          if (permissions.contains('expenses.view') ||
              permissions.contains('expenses.create'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_outlined)),
                title: const Text('Expense management'),
                subtitle:
                    const Text('Record expenses and review approval status'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExpensesView()),
                ),
              ),
            ),
          if (permissions.contains('staff.manage'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.people_alt_outlined)),
                title: const Text('Staff Management'),
                subtitle: const Text('Create employee accounts, assign roles and branches, and manage access'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StaffView()),
                ),
              ),
            ),
          if (permissions.contains('staff.manage'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.fingerprint)),
                title: const Text('Attendance & Employee Shifts'),
                subtitle: const Text('Check-in, attendance history and shift scheduling'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AttendanceShiftView()),
                ),
              ),
            ),
          if (permissions.contains('inventory.view') || permissions.contains('inventory.adjust'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.swap_horizontal_circle_outlined)),
                title: const Text('Inter-Branch Stock Transfers'),
                subtitle: const Text('Request, approve, dispatch and receive stock'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StockTransferView()),
                ),
              ),
            ),
          if (permissions.contains('audit.view') || permissions.contains('inventory.analytics.view'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.account_tree_outlined)),
                title: const Text('Multi-Branch Operations'),
                subtitle: const Text('Purchase analytics, branch costs and audit history'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BranchOperationsView()),
                ),
              ),
            ),
          if (permissions.contains('reports.view'))
            Card(
              child: ListTile(
                leading:
                    const CircleAvatar(child: Icon(Icons.analytics_outlined)),
                title: const Text('Financial reports'),
                subtitle: const Text(
                    'Sales, collections, expenses, cash flow and profit'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const FinancialReportsView()),
                ),
              ),
            ),
          if (permissions.contains('inventory.view'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.local_shipping_outlined)),
                title: const Text('Suppliers'),
                subtitle:
                    const Text('Supplier directory and outstanding ledger'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SuppliersView()),
                ),
              ),
            ),
          if (permissions.contains('inventory.view') ||
              permissions.contains('inventory.manage'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.shopping_cart_checkout_outlined)),
                title: const Text('Purchases & supplier payments'),
                subtitle: const Text(
                    'Create invoices, receive stock and record payments'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PurchasesView()),
                ),
              ),
            ),
          if (permissions.contains('inventory.view') ||
              permissions.contains('inventory.adjust'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.swap_horiz)),
                title: const Text('Stock control & valuation'),
                subtitle: const Text(
                    'Branch transfers, purchase returns and stock value'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StockControlView()),
                ),
              ),
            ),
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
          if (permissions.contains('settings.manage'))
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.tune)),
                title: const Text('Restaurant settings'),
                subtitle: const Text('Tax, discounts and receipt branding'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const RestaurantSettingsView()),
                ),
              ),
            ),
          if (permissions.contains('printers.view') ||
              permissions.contains('printers.manage') ||
              permissions.contains('printing.view'))
            Card(
                child: ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Printer management'),
              subtitle:
                  const Text('Printers, receipt queue and kitchen tickets'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PrintingView(permissions: permissions))),
            )),
          if (permissions.contains('delivery.view_assigned') ||
              permissions.contains('delivery.assignments.view_all'))
            Card(
                child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
              title: const Text('Delivery management'),
              subtitle: const Text(
                  'Assigned orders, delivery status and COD collection'),
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

class DashboardSummaryPanel extends StatefulWidget {
  const DashboardSummaryPanel({super.key, required this.permissions});
  final Set<String> permissions;
  @override
  State<DashboardSummaryPanel> createState() => _DashboardSummaryPanelState();
}

class _DashboardSummaryPanelState extends State<DashboardSummaryPanel> {
  final _api = locator<OperationsService>();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _metrics = {};
  String _period = 'Today';
  late DateTime _start;
  late DateTime _end;
  String? _startTime;
  String? _endTime;
  bool get _canViewHistory =>
      widget.permissions.contains('orders.view_all') ||
      widget.permissions.contains('orders.view_own');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day);
    _end = _start;
    _load();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.dashboardSummary(
        startDate: _date(_start),
        endDate: _date(_end),
        startTime: _startTime,
        endTime: _endTime,
      );
      _metrics = Map<String, dynamic>.from(data['metrics'] as Map? ?? {});
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _selectPeriod(String value) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime start = today;
    DateTime end = today;
    String? startTime;
    String? endTime;
    if (value == 'Week')
      start = today.subtract(Duration(days: today.weekday - 1));
    if (value == 'Month') start = DateTime(today.year, today.month, 1);
    if (value == 'Year') start = DateTime(today.year, 1, 1);
    if (value == 'Custom') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 2),
        initialDateRange: DateTimeRange(start: _start, end: _end),
      );
      if (range == null) return;
      final from = await showTimePicker(
          context: context, initialTime: const TimeOfDay(hour: 0, minute: 0));
      if (from == null) return;
      final to = await showTimePicker(
          context: context, initialTime: const TimeOfDay(hour: 23, minute: 59));
      if (to == null) return;
      start = range.start;
      end = range.end;
      startTime =
          '${from.hour.toString().padLeft(2, '0')}:${from.minute.toString().padLeft(2, '0')}';
      endTime =
          '${to.hour.toString().padLeft(2, '0')}:${to.minute.toString().padLeft(2, '0')}';
    }
    if (start == end && startTime != null && endTime != null) {
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      if (startMinutes >= endMinutes) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('End time must be after start time.')));
        return;
      }
    }
    setState(() {
      _period = value;
      _start = start;
      _end = end;
      _startTime = startTime;
      _endTime = endTime;
    });
    await _load();
  }

  void _history(String title,
      {String? statusGroup,
      String? paymentStatusGroup,
      String? paymentStatus}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DashboardOrdersView(
              title: title,
              statusGroup: statusGroup,
              paymentStatusGroup: paymentStatusGroup,
              paymentStatus: paymentStatus,
              initialStartDate: _date(_start),
              initialEndDate: _date(_end),
              initialStartTime: _startTime,
              initialEndTime: _endTime,
            )));
  }

  @override
  Widget build(BuildContext context) {
    final paid = _metrics['paidRevenueToday']?.toString() ?? '0.00';
    final pending = _metrics['pendingRevenue']?.toString() ?? '0.00';
    final range =
        '${_date(_start)} → ${_date(_end)}${_startTime != null ? ' • $_startTime–$_endTime' : ''}';
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sales & orders overview',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(range, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final item in ['Today', 'Week', 'Month', 'Year', 'Custom'])
            ChoiceChip(
                label: Text(item),
                selected: _period == item,
                onSelected: _loading ? null : (_) => _selectPeriod(item)),
        ]),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Row(children: [
            Expanded(
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ])
        else
          Wrap(spacing: 12, runSpacing: 12, children: [
            _MetricTile(
                label: 'Orders',
                value: '${_metrics['todayOrders'] ?? 0}',
                onTap: _canViewHistory
                    ? () => _history(
                          'Orders',
                        )
                    : null),
            _MetricTile(
                label: 'Open orders',
                value: '${_metrics['openOrders'] ?? 0}',
                onTap: _canViewHistory
                    ? () => _history('Open orders', statusGroup: 'open')
                    : null),
            _MetricTile(
                label: 'Completed',
                value: '${_metrics['completedToday'] ?? 0}',
                onTap: _canViewHistory
                    ? () =>
                        _history('Completed orders', statusGroup: 'completed')
                    : null),
            _MetricTile(
                label: 'Pending payments',
                value: '${_metrics['pendingPayments'] ?? 0}',
                onTap: _canViewHistory
                    ? () => _history('Pending payments',
                        paymentStatusGroup: 'pending')
                    : null),
            _MetricTile(
                label: 'Paid revenue',
                value: 'PKR $paid',
                onTap: _canViewHistory
                    ? () => _history('Paid revenue', paymentStatus: 'paid')
                    : null),
            _MetricTile(
                label: 'Pending total revenue',
                value: 'PKR $pending',
                onTap: _canViewHistory
                    ? () => _history('Pending total revenue',
                        paymentStatusGroup: 'pending')
                    : null),
          ]),
        const SizedBox(height: 6),
        Text('Timezone: Pakistan (UTC+05:00)',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    ));
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 145,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
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
        ),
      );
}
