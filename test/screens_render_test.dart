import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tahanan/core/app_theme.dart';
import 'package:tahanan/models/models.dart';
import 'package:tahanan/screens/create_boarding_house.dart';
import 'package:tahanan/screens/forgot_password_screen.dart';
import 'package:tahanan/screens/change_password_screen.dart';
import 'package:tahanan/screens/login.dart';
import 'package:tahanan/screens/more_screen.dart';
import 'package:tahanan/screens/owner.dart';
import 'package:tahanan/screens/owner/announcements.dart';
import 'package:tahanan/screens/owner/associate_tenant.dart';
import 'package:tahanan/screens/owner/concerns.dart';
import 'package:tahanan/screens/owner/room_detail.dart';
import 'package:tahanan/screens/owner/rooms.dart';
import 'package:tahanan/screens/owner/tenants.dart';
import 'package:tahanan/screens/tenant.dart';
import 'package:tahanan/screens/tenant/report_concern.dart';
import 'package:tahanan/services/saved_accounts_store.dart';
import 'package:tahanan/state/app_state.dart';
import 'package:tahanan/widgets/ui.dart';

AppState _state({bool owner = true}) {
  final state = AppState()..loading = false;
  state.user = const UserModel(
    id: 'u1',
    email: 'marisol@example.com',
    displayName: 'Marisol Reyes',
  );
  state.houses = [
    BoardingHouse(
      id: 'h1',
      name: 'Green Haven Boarding House',
      domain: 'green-haven',
      joinKey: 'GHBV-8X7K-2P9M',
      role: owner ? 'owner' : 'tenant',
      ownerName: 'Marisol Reyes',
      ownerEmail: 'marisol@example.com',
    ),
  ];
  state.selected = state.houses.first;
  state.dashboard = const DashboardData(
    name: 'Green Haven Boarding House',
    domain: 'green-haven',
    joinKey: 'GHBV-8X7K-2P9M',
    rooms: 6,
    tenants: 14,
    openSlots: 4,
    concerns: 2,
    unassigned: 1,
  );
  state.rooms = const [
    RoomModel(
      id: 'r1',
      roomNumber: '203',
      capacity: 3,
      occupied: 3,
      available: 0,
      occupancyStatus: 'full',
    ),
    RoomModel(
      id: 'r2',
      roomNumber: '204',
      capacity: 3,
      occupied: 2,
      available: 1,
      occupancyStatus: 'available',
    ),
  ];
  state.tenants = const [
    TenantModel(
      id: 't1',
      fullName: 'Alyssa Cruz',
      roomNumber: '203',
      roomId: 'r1',
      userId: 'u1',
      accountEmail: 'marisol@example.com',
      paymentStatus: 'paid',
    ),
    TenantModel(
      id: 't2',
      fullName: 'Paolo Garcia',
      roomNumber: '204',
      roomId: 'r2',
      paymentStatus: 'partial',
    ),
  ];
  state.unassigned = [
    UnassignedAccount(
      userId: 'u2',
      email: 'new@example.com',
      displayName: 'New Member',
    ),
  ];
  state.concerns = [
    ConcernModel(
      id: 'c1',
      subject: 'Leaking faucet in the shared bathroom',
      details: 'Dripping since last night.',
      category: 'maintenance',
      status: ConcernModel.statusPending,
      tenantName: 'Alyssa Cruz',
      roomNumber: '203',
      createdAt: DateTime(2026, 11, 3, 9, 41),
      ownerResponse: 'Plumber scheduled.',
    ),
  ];
  state.announcements = [
    AnnouncementModel(
      id: 'a1',
      title: 'Water interruption on Saturday',
      message: 'Please store water ahead of time.',
      publishedAt: DateTime(2026, 11, 3, 9, 41),
    ),
  ];
  return state;
}

Future<void> _pump(WidgetTester tester, AppState state, Widget screen) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('login renders', (tester) async {
    await _pump(tester, _state(), const LoginScreen(loadCaptcha: false));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Google account email'), findsOneWidget);
  });

  testWidgets('forgot password screen renders', (tester) async {
    await _pump(tester, _state(), const ForgotPasswordScreen());
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Send reset code'), findsOneWidget);
  });

  testWidgets('change password screen renders', (tester) async {
    await _pump(tester, _state(), const ChangePasswordScreen());
    expect(find.text('Change password'), findsWidgets);
    expect(find.text('Current password'), findsOneWidget);
  });

  testWidgets('saved accounts open from the email field', (tester) async {    final state = _state();
    state.savedAccounts = const [
      SavedAccount(
        id: 'u1',
        email: 'marisol@example.com',
        displayName: 'Marisol Reyes',
        token: 'saved-token',
      ),
      SavedAccount(
        id: 'u2',
        email: 'juan@example.com',
        displayName: 'Juan Dela Cruz',
        token: 'saved-token-2',
      ),
    ];

    await _pump(tester, state, const LoginScreen(loadCaptcha: false));

    expect(find.byTooltip('Saved accounts'), findsOneWidget);

    final shortcut = find.byTooltip('Saved accounts');
    await tester.ensureVisible(shortcut);
    await tester.pumpAndSettle();
    await tester.tap(shortcut);
    await tester.pumpAndSettle();

    expect(find.text('Choose an account'), findsOneWidget);
    expect(find.text('Marisol Reyes'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
  });

  testWidgets('owner rooms renders', (tester) async {
    await _pump(tester, _state(), const RoomsScreen());
    expect(find.text('Your rooms'), findsOneWidget);
  });

  testWidgets('owner tenants renders', (tester) async {
    await _pump(tester, _state(), const TenantsScreen());
    expect(find.text('Tenants'), findsWidgets);
  });

  testWidgets('owner concerns renders', (tester) async {
    await _pump(tester, _state(), const ConcernsScreen());
    expect(find.text('Concerns'), findsOneWidget);
  });

  testWidgets('owner announcements renders', (tester) async {
    await _pump(tester, _state(), const AnnouncementsScreen());
    expect(find.text('Announcements'), findsOneWidget);
  });

  testWidgets('owner more renders', (tester) async {
    await _pump(tester, _state(), const MoreScreen(isOwner: true));
    expect(find.text('Switch boarding house'), findsOneWidget);
  });

  testWidgets('owner shell home renders', (tester) async {
    await _pump(tester, _state(), const OwnerScreen());
    expect(find.text('Live capacity'), findsOneWidget);
    expect(find.text('Room overview'), findsOneWidget);
  });

  testWidgets('room detail renders', (tester) async {
    final state = _state();
    await _pump(tester, state, RoomDetailScreen(room: state.rooms.first));
    expect(find.text('Bed layout'), findsOneWidget);
  });

  testWidgets('associate tenant renders', (tester) async {
    final state = _state();
    await _pump(
      tester,
      state,
      AssociateTenantScreen(unassigned: state.unassigned.first),
    );
    expect(find.text('Assign to room'), findsOneWidget);
  });

  testWidgets('tenant shell renders', (tester) async {
    await _pump(tester, _state(owner: false), const TenantScreen());
    expect(find.text('Hi, Marisol'), findsOneWidget);

    final nav = tester.widget<TahananBottomNav>(find.byType(TahananBottomNav));
    nav.onTap(2);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('MY REPORTS'), findsOneWidget);
  });

  testWidgets('report concern renders', (tester) async {
    await _pump(tester, _state(owner: false), const ReportConcernScreen());
    expect(find.text('What needs attention?'), findsOneWidget);
  });

  testWidgets('create house renders', (tester) async {
    await _pump(tester, _state(), const CreateBoardingHouseScreen());
    expect(find.text('Set up your rooms'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('Customize your rooms'), findsOneWidget);
  });
}
