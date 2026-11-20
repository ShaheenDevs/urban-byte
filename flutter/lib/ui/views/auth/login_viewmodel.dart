import 'package:stacked/stacked.dart';
class LoginViewModel extends BaseViewModel {
  String? message;
  Future<void> prepareLogin() async {
    message = 'Authentication API is not connected yet.';
    notifyListeners();
  }
}
