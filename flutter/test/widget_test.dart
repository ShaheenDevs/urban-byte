// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:urban_byte/main.dart';

void main() {
  testWidgets('App builds login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const UrbanByteApp());

    expect(find.text('Urban Byte'), findsOneWidget);
    expect(find.text('Restaurant operations'), findsOneWidget);
  });
}
