// This is a basic Flutter widget test for SafeGuard.
//
// The previous version of this file referenced a `MyApp` class that
// does not exist in this project. The application's actual root
// widget is `SafeGuardApp`, defined in lib/main.dart.

import 'package:flutter_test/flutter_test.dart';

import 'package:safeguard/main.dart';

void main() {
  testWidgets('SafeGuardApp builds without throwing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SafeGuardApp());

    // A minimal smoke test: just confirm the app builds and renders
    // a MaterialApp without throwing an exception.
    expect(find.byType(SafeGuardApp), findsOneWidget);
  });
}