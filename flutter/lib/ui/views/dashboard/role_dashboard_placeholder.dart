import 'package:flutter/material.dart';
/// Placeholder for Admin, Supervisor, Waiter, Kitchen and Delivery dashboards.
class RoleDashboardPlaceholder extends StatelessWidget {
  const RoleDashboardPlaceholder({super.key, required this.roleName});
  final String roleName;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$roleName Dashboard')),
    body: Center(child: Text('$roleName workspace will be implemented in the next milestone.')),
  );
}
