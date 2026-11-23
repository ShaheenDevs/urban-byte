import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_byte/main.dart';

void main() {
  testWidgets('App checks first-time setup then opens the login screen',
      (WidgetTester tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/health/setup'));
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'Setup status loaded.',
          'data': {
            'ready': true,
            'checks': {
              'restaurant': true,
              'branch': true,
              'ownerAccount': true,
              'roles': true,
              'permissions': true,
              'menuCategories': true,
              'menuProducts': true,
              'inventoryIngredients': true,
              'suppliers': true,
            },
            'counts': {'branches': 1, 'products': 10},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(UrbanByteApp(setupClient: client));
    await tester.pumpAndSettle();

    expect(find.text('Initial setup records found'), findsOneWidget);
    expect(find.text('Restaurant profile'), findsOneWidget);
    expect(find.text('Owner account'), findsOneWidget);

    await tester.tap(find.text('Continue to Owner / Staff Login'));
    await tester.pumpAndSettle();

    expect(find.text('Urban Byte'), findsOneWidget);
    expect(find.text('Restaurant operations'), findsOneWidget);

    client.close();
  });
}
