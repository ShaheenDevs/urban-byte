import 'package:stacked/stacked.dart';
import '../services/auth_service.dart';
final locator = StackedLocator.instance;
Future<void> setupLocator() async {
  locator.registerLazySingleton(() => AuthService());
}
