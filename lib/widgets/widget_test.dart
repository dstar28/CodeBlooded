// Minimal smoke test for SafeGuard.
//
// The app's root widget is [SafeGuardApp] (see lib/main.dart) — there is
// no `MyApp` class in this project. This test only confirms the app
// launches and the Home dashboard renders; it is intentionally not a
// full navigation/feature test suite.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safeguard/main.dart';

void main() {
  testWidgets('SafeGuardApp launches and shows the Home dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SafeGuardApp());
    await tester.pumpAndSettle();

    expect(find.text('SAFEGUARD'), findsOneWidget);
  });
}
