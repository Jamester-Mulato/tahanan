import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahanan/widgets/premium/premium_kit.dart';

void main() {
  testWidgets('PremiumField writes typed text into its controller', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumField(
            controller: controller,
            label: 'Username',
            hint: '7-16 letters and digits',
            icon: Icons.person_outline,
            required: true,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'devicetest');
    await tester.pump();

    expect(controller.text, 'devicetest');
  });

  testWidgets('PremiumField reports its inline error', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumField(
            controller: controller,
            label: 'ID Number',
            hint: 'xxxx-xxxx',
            icon: Icons.person_outline,
            required: true,
            error: 'ID Number must follow the format xxxx-xxxx.',
          ),
        ),
      ),
    );

    expect(
      find.text('ID Number must follow the format xxxx-xxxx.'),
      findsOneWidget,
    );
  });
}
