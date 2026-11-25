import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tahanan/core/idle_motion_spec.dart';
import 'package:tahanan/screens/key_restore_screen.dart';
import 'package:tahanan/screens/splash_screen.dart';

void main() {
  testWidgets('splash intro hands off to the key restore screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(catalog: MotionCatalog.fallback()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tahanan'), findsWidgets);
    expect(find.text('Your boarding house, in order.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Restoring your keys'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('key restore reaches the completed state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KeyRestoreScreen(
          catalog: MotionCatalog.fallback(),
          duration: const Duration(milliseconds: 600),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Restoring your keys'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Keys restored'), findsOneWidget);
    expect(find.text('Opening your boarding house…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
