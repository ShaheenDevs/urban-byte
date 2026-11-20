import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'login_viewmodel.dart';
class LoginView extends StackedView<LoginViewModel> {
  const LoginView({super.key});
  @override
  Widget builder(BuildContext context, LoginViewModel viewModel, Widget? child) => Scaffold(
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: Padding(
      padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.restaurant_menu, size: 56), const SizedBox(height: 16),
        Text('Urban Byte', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8), const Text('Restaurant operations', textAlign: TextAlign.center),
        const SizedBox(height: 28), const TextField(decoration: InputDecoration(labelText: 'Email or phone', border: OutlineInputBorder())),
        const SizedBox(height: 12), const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
        const SizedBox(height: 16), FilledButton(onPressed: viewModel.isBusy ? null : viewModel.prepareLogin, child: const Text('Continue')),
        if (viewModel.message != null) ...[const SizedBox(height: 12), Text(viewModel.message!, textAlign: TextAlign.center)],
      ]),
    ))),
  );
  @override
  LoginViewModel viewModelBuilder(BuildContext context) => LoginViewModel();
}
