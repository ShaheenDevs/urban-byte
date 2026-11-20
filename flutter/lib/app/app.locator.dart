import 'package:stacked/stacked.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../services/operations_service.dart';
final locator = StackedLocator.instance;
Future<void> setupLocator() async {
  locator.registerLazySingleton(() => AuthService());
  locator.registerLazySingleton(() => InventoryService());
  locator.registerLazySingleton(() => OperationsService());
}
