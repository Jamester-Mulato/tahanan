import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tahanan/core/app_colors.dart';
import 'package:tahanan/main.dart';
import 'package:tahanan/state/app_state.dart';

void main() {
  testWidgets('app boots into the white-green theme', (tester) async {
    final state = AppState()..loading = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const TahananApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    final context = tester.element(find.byType(Scaffold).first);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      AppColors.background,
    );
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
