// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// StackedNavigatorGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:flutter/material.dart' as _i7;
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart' as _i1;
import 'package:stacked_services/stacked_services.dart' as _i8;
import 'package:urban_byte/ui/views/auth/login_view.dart' as _i2;
import 'package:urban_byte/ui/views/expenses/expense_view.dart' as _i5;
import 'package:urban_byte/ui/views/printing/printing_view.dart' as _i3;
import 'package:urban_byte/ui/views/reports/financial_report_view.dart' as _i6;
import 'package:urban_byte/ui/views/staff/staff_view.dart' as _i4;

class Routes {
  static const loginView = '/login-view';

  static const printingView = '/printing-view';

  static const staffView = '/staff-view';

  static const expenseView = '/expense-view';

  static const financialReportView = '/financial-report-view';

  static const all = <String>{
    loginView,
    printingView,
    staffView,
    expenseView,
    financialReportView,
  };
}

class StackedRouter extends _i1.RouterBase {
  final _routes = <_i1.RouteDef>[
    _i1.RouteDef(
      Routes.loginView,
      page: _i2.LoginView,
    ),
    _i1.RouteDef(
      Routes.printingView,
      page: _i3.PrintingView,
    ),
    _i1.RouteDef(
      Routes.staffView,
      page: _i4.StaffView,
    ),
    _i1.RouteDef(
      Routes.expenseView,
      page: _i5.ExpenseView,
    ),
    _i1.RouteDef(
      Routes.financialReportView,
      page: _i6.FinancialReportView,
    ),
  ];

  final _pagesMap = <Type, _i1.StackedRouteFactory>{
    _i2.LoginView: (data) {
      final args = data.getArgs<LoginViewArguments>(
        orElse: () => const LoginViewArguments(),
      );
      return _i7.MaterialPageRoute<dynamic>(
        builder: (context) => _i2.LoginView(key: args.key),
        settings: data,
      );
    },
    _i3.PrintingView: (data) {
      final args = data.getArgs<PrintingViewArguments>(nullOk: false);
      return _i7.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i3.PrintingView(key: args.key, permissions: args.permissions),
        settings: data,
      );
    },
    _i4.StaffView: (data) {
      final args = data.getArgs<StaffViewArguments>(
        orElse: () => const StaffViewArguments(),
      );
      return _i7.MaterialPageRoute<dynamic>(
        builder: (context) => _i4.StaffView(key: args.key),
        settings: data,
      );
    },
    _i5.ExpenseView: (data) {
      final args = data.getArgs<ExpenseViewArguments>(
        orElse: () => const ExpenseViewArguments(),
      );
      return _i7.MaterialPageRoute<dynamic>(
        builder: (context) => _i5.ExpenseView(key: args.key),
        settings: data,
      );
    },
    _i6.FinancialReportView: (data) {
      final args = data.getArgs<FinancialReportViewArguments>(
        orElse: () => const FinancialReportViewArguments(),
      );
      return _i7.MaterialPageRoute<dynamic>(
        builder: (context) => _i6.FinancialReportView(key: args.key),
        settings: data,
      );
    },
  };

  @override
  List<_i1.RouteDef> get routes => _routes;

  @override
  Map<Type, _i1.StackedRouteFactory> get pagesMap => _pagesMap;
}

class LoginViewArguments {
  const LoginViewArguments({this.key});

  final _i7.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant LoginViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class PrintingViewArguments {
  const PrintingViewArguments({
    this.key,
    required this.permissions,
  });

  final _i7.Key? key;

  final Set<String> permissions;

  @override
  String toString() {
    return '{"key": "$key", "permissions": "$permissions"}';
  }

  @override
  bool operator ==(covariant PrintingViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.permissions == permissions;
  }

  @override
  int get hashCode {
    return key.hashCode ^ permissions.hashCode;
  }
}

class StaffViewArguments {
  const StaffViewArguments({this.key});

  final _i7.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant StaffViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class ExpenseViewArguments {
  const ExpenseViewArguments({this.key});

  final _i7.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant ExpenseViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class FinancialReportViewArguments {
  const FinancialReportViewArguments({this.key});

  final _i7.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant FinancialReportViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

extension NavigatorStateExtension on _i8.NavigationService {
  Future<dynamic> navigateToLoginView({
    _i7.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(Routes.loginView,
        arguments: LoginViewArguments(key: key),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }

  Future<dynamic> navigateToPrintingView({
    _i7.Key? key,
    required Set<String> permissions,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(Routes.printingView,
        arguments: PrintingViewArguments(key: key, permissions: permissions),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }

  Future<dynamic> navigateToStaffView({
    _i7.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(Routes.staffView,
        arguments: StaffViewArguments(key: key),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }

  Future<dynamic> navigateToExpenseView({
    _i7.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(Routes.expenseView,
        arguments: ExpenseViewArguments(key: key),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }

  Future<dynamic> navigateToFinancialReportView({
    _i7.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(Routes.financialReportView,
        arguments: FinancialReportViewArguments(key: key),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }

  Future<dynamic> replaceWithLoginView({
    _i7.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(Routes.loginView,
        arguments: LoginViewArguments(key: key),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }

  Future<dynamic> replaceWithPrintingView({
    _i7.Key? key,
    required Set<String> permissions,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(Routes.printingView,
        arguments: PrintingViewArguments(key: key, permissions: permissions),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }

  Future<dynamic> replaceWithStaffView({
    _i7.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(Routes.staffView,
        arguments: StaffViewArguments(key: key),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }

  Future<dynamic> replaceWithExpenseView({
    _i7.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(Routes.expenseView,
        arguments: ExpenseViewArguments(key: key),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }

  Future<dynamic> replaceWithFinancialReportView({
    _i7.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(Routes.financialReportView,
        arguments: FinancialReportViewArguments(key: key),
        id: routerId,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
        transition: transition);
  }
}
