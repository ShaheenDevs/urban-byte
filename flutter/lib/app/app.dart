import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../services/operations_service.dart';
import '../ui/views/auth/login_view.dart';
import '../ui/views/printing/printing_view.dart';

@StackedApp(
  routes: [
    MaterialRoute(page: LoginView),
    MaterialRoute(page: PrintingView),
  ],
  dependencies: [
    LazySingleton(classType: NavigationService),
    LazySingleton(classType: AuthService),
    LazySingleton(classType: InventoryService),
    LazySingleton(classType: OperationsService),
  ],
)
class App {}