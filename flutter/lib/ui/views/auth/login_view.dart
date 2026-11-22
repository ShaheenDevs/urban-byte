import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/auth_service.dart';
import '../../../services/public_role_service.dart';
import '../dashboard/role_dashboard_placeholder.dart';
import 'login_viewmodel.dart';

class LoginView extends StackedView<LoginViewModel> {
  const LoginView({super.key});
  @override
  Widget builder(
          BuildContext context, LoginViewModel viewModel, Widget? child) =>
      Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.restaurant_menu, size: 56),
                  const SizedBox(height: 16),
                  Text('Urban Byte',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Restaurant operations',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  TextField(
                      controller: viewModel.identifierController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: 'Email or phone',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: viewModel.passwordController,
                      obscureText: true,
                      onSubmitted: (_) => _submit(context, viewModel),
                      decoration: const InputDecoration(
                          labelText: 'Password', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                      onPressed: () => _showRoles(context),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('View Available Roles'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                      onPressed: viewModel.isBusy
                          ? null
                          : () => _submit(context, viewModel),
                      child: viewModel.isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Continue')),
                  if (viewModel.message != null) ...[
                    const SizedBox(height: 12),
                    Text(viewModel.message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              )),
        ))),
      );

  Future<void> _showRoles(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _AvailableRolesDialog(),
    );
  }

  Future<void> _submit(BuildContext context, LoginViewModel viewModel) async {
    final session = await viewModel.login();
    if (!context.mounted || session == null) return;
    final role = session.roles.isEmpty ? 'Staff' : session.roles.first;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RoleDashboardPlaceholder(
          roleName: role, permissions: session.permissions.toSet()),
    ));
  }

  @override
  LoginViewModel viewModelBuilder(BuildContext context) =>
      LoginViewModel(locator<AuthService>());
}

class _AvailableRolesDialog extends StatefulWidget {
  const _AvailableRolesDialog();
  @override
  State<_AvailableRolesDialog> createState() => _AvailableRolesDialogState();
}

class _AvailableRolesDialogState extends State<_AvailableRolesDialog> {
  late Future<List<Map<String, dynamic>>> _roles;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  void _loadRoles() {
    _roles = PublicRoleService().fetchRoles();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Available Staff Roles'),
    content: SizedBox(
      width: 360,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _roles,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Text(snapshot.error.toString()),
              const SizedBox(height: 8),
              TextButton(onPressed: () => setState(_loadRoles), child: const Text('Retry')),
            ]);
          }
          final roles = snapshot.data ?? [];
          if (roles.isEmpty) return const Text('No roles found in database.');
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: roles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final role = roles[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                  title: Text(role['name']?.toString() ?? role['slug']?.toString() ?? 'Role'),
                  subtitle: Text(role['slug']?.toString() ?? ''),
                  trailing: const Icon(Icons.check_circle_outline, color: Colors.green),
                );
              },
            ),
          );
        },
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  );
}
