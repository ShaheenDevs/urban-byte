import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/auth_service.dart';
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
