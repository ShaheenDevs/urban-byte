// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// StackedLocatorGenerator
// **************************************************************************

// ignore_for_file: public_member_api_docs, implementation_imports, depend_on_referenced_packages

import 'package:stacked_services/src/navigation/navigation_service.dart';
import 'package:stacked_shared/stacked_shared.dart';

import '../services/auth_service.dart';
import '../services/attendance_shift_service.dart';
import '../services/branch_operations_service.dart';
import '../services/expense_service.dart';
import '../services/financial_report_service.dart';
import '../services/inventory_service.dart';
import '../services/operations_service.dart';
import '../services/staff_service.dart';

final locator = StackedLocator.instance;

Future<void> setupLocator(
    {String? environment, EnvironmentFilter? environmentFilter}) async {
// Register environments
  locator.registerEnvironment(
      environment: environment, environmentFilter: environmentFilter);

// Register dependencies
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => AuthService());
  locator.registerLazySingleton(() => InventoryService());
  locator.registerLazySingleton(() => OperationsService());
  locator.registerLazySingleton(() => StaffService());
  locator.registerLazySingleton(() => ExpenseService());
  locator.registerLazySingleton(() => FinancialReportService());
  locator.registerLazySingleton(() => BranchOperationsService());
  locator.registerLazySingleton(() => AttendanceShiftService());
}
