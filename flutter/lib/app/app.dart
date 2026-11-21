import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';
import '../services/auth_service.dart';
import '../services/expense_service.dart';
import '../services/financial_report_service.dart';
import '../services/inventory_service.dart';
import '../services/operations_service.dart';
import '../services/staff_service.dart';
import '../ui/views/auth/login_view.dart';
import '../ui/views/expenses/expense_view.dart';
import '../ui/views/reports/financial_report_view.dart';
import '../ui/views/printing/printing_view.dart';
import '../ui/views/staff/staff_view.dart';

@StackedApp(
  routes: [
    MaterialRoute(page: LoginView),
    MaterialRoute(page: PrintingView),
    MaterialRoute(page: StaffView),
    MaterialRoute(page: ExpenseView),
    MaterialRoute(page: FinancialReportView),
  ],
  dependencies: [
    LazySingleton(classType: NavigationService),
    LazySingleton(classType: AuthService),
    LazySingleton(classType: InventoryService),
    LazySingleton(classType: OperationsService),
    LazySingleton(classType: StaffService),
    LazySingleton(classType: ExpenseService),
    LazySingleton(classType: FinancialReportService),
  ],
)
class App {}