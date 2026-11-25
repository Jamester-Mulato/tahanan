import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tahanan/core/app_theme.dart';
import 'package:tahanan/models/models.dart';
import 'package:tahanan/screens/houses.dart';
import 'package:tahanan/state/app_state.dart';

void main() {
  testWidgets('house picker paints its content', (tester) async {
    final state = AppState()..loading = false;
    state.user = const UserModel(
      id: 'u1',
      email: 'marisol@example.com',
      displayName: 'Marisol Reyes',
    );
    state.houses = const [
      BoardingHouse(
        id: 'h1',
        name: 'Green Haven Boarding House',
        domain: 'green-haven',
        joinKey: 'GHBV-8X7K-2P9M',
        role: 'owner',
        ownerName: 'Marisol Reyes',
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const HousesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    expect(find.text('My boarding houses'), findsOneWidget);
    expect(find.text('Green Haven Boarding House'), findsOneWidget);
    expect(find.text('Portfolio mix'), findsOneWidget);
  });
}
