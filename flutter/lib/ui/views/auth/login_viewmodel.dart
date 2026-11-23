import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../models/auth_session.dart';
import '../../../services/auth_service.dart';

class LoginViewModel extends BaseViewModel {
  LoginViewModel(this._authService);
  final AuthService _authService;
  final identifierController = TextEditingController();
  final passwordController =
      TextEditingController();
  String? message;

  Future<AuthSession?> login() async {
    final identifier = identifierController.text.trim();
    final password = passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      message = 'Email/phone aur password enter karein.';
      notifyListeners();
      return null;
    }
    setBusy(true);
    message = null;
    notifyListeners();
    try {
      return await _authService.login(
          identifier: identifier, password: password);
    } on AuthException catch (error) {
      message = error.message;
    } catch (e) {
      log(e.toString());
      message =
          'Server se connection nahi ho saka. API URL aur network check karein.';
    } finally {
      setBusy(false);
      notifyListeners();
    }
    return null;
  }

  @override
  void dispose() {
    identifierController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
