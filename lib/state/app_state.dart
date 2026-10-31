import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/saved_accounts_store.dart';
import '../services/token_store.dart';

class AppState extends ChangeNotifier {
  final api = ApiClient();
  final _tokenStore = TokenStore();
  final _accountsStore = SavedAccountsStore();
  late final auth = AuthService(api);

  bool _sessionExpired = false;
  bool _demoMode = false;

  AppState() {
    api.onUnauthorized = () => unawaited(_expireSession());
  }

  UserModel? user;

  /// Accounts that already signed in on this device. Only session tokens are
  /// stored (in the platform keystore), never passwords.
  List<SavedAccount> savedAccounts = [];

  List<BoardingHouse> houses = [];
  List<RemovedBoardingHouse> removedHouses = [];
  BoardingHouse? selected;
  DashboardData? dashboard;
  List<RoomModel> rooms = [];
  List<TenantModel> tenants = [];
  List<UnassignedAccount> unassigned = [];
  List<AnnouncementModel> announcements = [];
  List<ConcernModel> concerns = [];

  bool loading = true;
  String? error;

  bool get loggedIn => user != null;
  bool get owner => selected?.role == 'owner';
  bool get tenant => selected?.role == 'tenant';

  Future<void> restore() async {
    await _loadSavedAccounts();

    // Local design-review session: no OAuth, no network. Only exists in a
    // debug build compiled with TAHANAN_DEMO_MODE=true.
    if (kDebugMode && const bool.fromEnvironment('TAHANAN_DEMO_MODE')) {
      _loadDemoSession();
      return;
    }

    // Debug-only seed session so a physical device can open the reference UI
    // without completing Google OAuth. Never compiled into release builds.
    const devToken = String.fromEnvironment('TAHANAN_DEV_TOKEN');
    if (kDebugMode && devToken.isNotEmpty) {
      api.token = devToken;
      try {
        await loadMine();
        _sessionExpired = false;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Dev session restore failed: ${error.runtimeType}');
        }
      } finally {
        loading = false;
        notifyListeners();
      }
      return;
    }

    try {
      final token = await _tokenStore.read();
      if (token != null && token.isNotEmpty) {
        api.token = token;
        await loadMine();
        _sessionExpired = false;

        // Capture sessions that existed before the saved-accounts feature so
        // they appear in the account list too.
        final current = user;
        if (current != null) {
          await _rememberAccount(
            id: current.id,
            email: current.email,
            displayName: current.displayName,
            token: token,
            touch: false,
          );
        }
      }
    } catch (error) {
      if (error is ApiException && error.isUnauthorized) {
        await _expireSession();
      } else if (kDebugMode) {
        debugPrint('Session restore failed: ${error.runtimeType}');
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Step one: username, password and human check. No session yet.
  Future<LoginChallenge> startPasswordLogin({
    required String username,
    required String password,
    String? captchaId,
    String? captchaAnswer,
    String? recaptchaToken,
  }) async {
    _sessionExpired = false;
    late LoginChallenge challenge;
    await _busy(() async {
      challenge = await auth.signIn(
        username: username,
        password: password,
        captchaId: captchaId,
        captchaAnswer: captchaAnswer,
        recaptchaToken: recaptchaToken,
      );
    }, globalLoader: false);
    return challenge;
  }

  /// Step two: the emailed 6-digit code creates the session.
  Future<void> verifyLoginOtp({
    required String challengeId,
    required String code,
    String? password,
    bool rememberMe = false,
  }) async {
    await _busy(() async {
      final r = await auth.verifyLoginOtp(
        challengeId: challengeId,
        code: code,
        rememberMe: rememberMe,
      );
      await _completeSignIn(r, password: password, rememberMe: rememberMe);
    }, globalLoader: false);
  }

  Future<bool> usernameAvailable(String username) =>
      auth.usernameAvailable(username);

  Future<LoginChallenge> resendLoginOtp(String challengeId) =>
      auth.resendLoginOtp(challengeId);

  Future<LoginChallenge> registerAccount(Map<String, dynamic> payload) =>
      auth.registerAccount(payload);

  Future<void> verifyRegistrationOtp({
    required String challengeId,
    required String code,
  }) async {
    await _busy(() async {
      final r = await auth.verifyRegistrationOtp(
        challengeId: challengeId,
        code: code,
      );
      await _completeSignIn(r);
    }, globalLoader: false);
  }

  Future<LoginChallenge> resendRegistrationOtp(String challengeId) =>
      auth.resendRegistrationOtp(challengeId);

  Future<List<Map<String, String>>> forgotQuestions(
    String username, {
    String? captchaId,
    String? captchaAnswer,
    String? recaptchaToken,
  }) =>
      auth.forgotQuestions(
        username,
        captchaId: captchaId,
        captchaAnswer: captchaAnswer,
        recaptchaToken: recaptchaToken,
      );

  Future<LoginChallenge> forgotAnswer({
    required String username,
    required String question,
    required String answer,
    required String reanswer,
  }) =>
      auth.forgotAnswer(
        username: username,
        question: question,
        answer: answer,
        reanswer: reanswer,
      );

  Future<String> verifyResetOtp({
    required String challengeId,
    required String code,
  }) =>
      auth.verifyResetOtp(challengeId: challengeId, code: code);

  Future<LoginChallenge> resendResetOtp(String challengeId) =>
      auth.resendResetOtp(challengeId);

  Future<CaptchaChallenge> fetchCaptcha() => auth.fetchCaptcha();

  Future<RecaptchaConfig> fetchRecaptchaConfig() => auth.fetchRecaptchaConfig();

  Future<Map<String, dynamic>> fetchAdminSecurity({
    String from = '',
    String to = '',
    String event = '',
    String username = '',
    String ip = '',
    bool logView = false,
  }) async {
    final params = <String, String>{
      if (!logView) 'log': '0',
      if (from.isNotEmpty) 'from': from,
      if (to.isNotEmpty) 'to': to,
      if (event.isNotEmpty) 'event': event,
      if (username.isNotEmpty) 'username': username,
      if (ip.isNotEmpty) 'ip': ip,
    };
    final query =
        params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final result = await api.request(
      'GET',
      '/api/admin/security$query',
      auth: true,
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Sign-up: name, email, username, password and human check.
  Future<void> signUpWithPassword({
    required String displayName,
    required String email,
    required String username,
    required String password,
    required bool privacyConsent,
    String? captchaId,
    String? captchaAnswer,
    String? recaptchaToken,
    bool rememberMe = false,
  }) async {
    _sessionExpired = false;
    await _busy(() async {
      final r = await auth.signUp(
        displayName: displayName,
        email: email,
        username: username,
        password: password,
        privacyConsent: privacyConsent,
        captchaId: captchaId,
        captchaAnswer: captchaAnswer,
        recaptchaToken: recaptchaToken,
        rememberMe: rememberMe,
      );
      await _completeSignIn(r, password: password, rememberMe: rememberMe);
    });
  }

  Future<void> requestPasswordReset(String email) =>
      auth.requestPasswordReset(email);

  Future<void> resetPassword({
    required String code,
    required String password,
  }) =>
      auth.resetPassword(code: code, password: password);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _busy(() async {
      await auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await signOut();
    });
  }

  Future<void> _completeSignIn(
    Map<String, dynamic> r, {
    String? password,
    bool rememberMe = false,
  }) async {
    user = UserModel.fromJson(r['user']);
    final token = r['accessToken'] as String;

    // The API client must hold the new token before any follow-up request.
    api.token = token;
    // Do not let a racing 401 tear the session down while we finish sign-in.
    api.suppressUnauthorized = true;

    // Persisting the token must never block a successful sign-in; the session
    // is already valid in memory for this run.
    try {
      await _tokenStore.write(token);
    } catch (error) {
      debugPrint('TokenStore: write failed (${error.runtimeType})');
    }

    final current = user;
    if (current != null) {
      try {
        await _rememberAccount(
          id: current.id,
          email: current.email,
          username: current.username,
          displayName: current.displayName,
          token: token,
          password: rememberMe ? password : null,
          rememberToken: r['rememberToken'] as String?,
          rememberUntil: r['rememberUntil'] as String?,
          clearCredentials: !rememberMe,
        );
      } catch (error) {
        debugPrint('Saved accounts: update failed (${error.runtimeType})');
      }
    }

    try {
      await loadMine();
    } catch (error) {
      debugPrint('Post sign-in load failed (${error.runtimeType})');
    } finally {
      api.suppressUnauthorized = false;
    }
  }

  /// Adds or updates the account in the on-device list. Credentials are kept
  /// only when `rememberMe` supplied them; otherwise the previous 7-day
  /// credential is cleared.
  Future<void> _rememberAccount({
    required String id,
    required String email,
    String? username,
    required String displayName,
    required String token,
    String? password,
    String? rememberToken,
    String? rememberUntil,
    bool clearCredentials = false,
    bool touch = true,
  }) async {
    final index = savedAccounts.indexWhere(
      (account) =>
          account.id == id ||
          account.email.toLowerCase() == email.toLowerCase(),
    );
    final previous = index >= 0 ? savedAccounts[index] : null;

    final account = SavedAccount(
      id: id,
      email: email,
      username: username ?? previous?.username,
      displayName: displayName,
      token: token,
      password: password ?? (clearCredentials ? null : previous?.password),
      rememberToken:
          rememberToken ?? (clearCredentials ? null : previous?.rememberToken),
      rememberUntil: rememberUntil != null
          ? DateTime.tryParse(rememberUntil)
          : (clearCredentials ? null : previous?.rememberUntil),
      lastUsedAt: touch ? DateTime.now() : previous?.lastUsedAt,
    );

    if (index >= 0) savedAccounts.removeAt(index);
    savedAccounts.insert(0, account);
    await _persistSavedAccounts();
    notifyListeners();
  }

  Future<void> removeSavedAccount(String id) async {
    savedAccounts.removeWhere((account) => account.id == id);
    await _persistSavedAccounts();
    notifyListeners();
  }

  Future<void> _loadSavedAccounts() async {
    try {
      savedAccounts = await _accountsStore.read();
    } catch (_) {
      savedAccounts = [];
    }
  }

  Future<void> _persistSavedAccounts() async {
    try {
      await _accountsStore.write(savedAccounts);
    } catch (_) {
      // The active session still works even if the list cannot be saved.
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
    await _tokenStore.clear();
    _resetSessionData();
    error = null;
    notifyListeners();
  }

  /// Triggered when the API rejects the access token. Clears local state so
  /// the app falls back to the sign-in screen and the user knows why.
  Future<void> _expireSession() async {
    if (_sessionExpired) return;
    _sessionExpired = true;
    api.token = null;
    await _tokenStore.clear();
    _resetSessionData();
    error = 'Your session has expired. Please sign in again.';
    loading = false;
    notifyListeners();
  }

  void _resetSessionData() {
    user = null;
    houses = [];
    removedHouses = [];
    selected = null;
    dashboard = null;
    rooms = [];
    tenants = [];
    unassigned = [];
    announcements = [];
    concerns = [];
  }

  Future<void> loadMine() async {
    if (_demoMode) return;
    final d = await api.request('GET', '/api/me');
    user = UserModel.fromJson(d['user']);
    houses = (d['boardingHouses'] as List)
        .map((x) => BoardingHouse.fromJson(x))
        .toList();

    if (d['removedBoardingHouses'] is List) {
      removedHouses = (d['removedBoardingHouses'] as List)
          .map((x) => RemovedBoardingHouse.fromJson(x))
          .toList();
    } else {
      removedHouses = [];
    }

    if (selected != null) {
      // Refresh current selected house if still valid
      final found = houses.where((h) => h.id == selected!.id).toList();
      if (found.isNotEmpty) {
        selected = found.first;
        await refreshHouse();
      } else {
        selected = null;
      }
    }
    notifyListeners();
  }

  Future<void> dismissRemoval(String houseId) async {
    try {
      await api.request('POST', '/api/me/dismiss-removal/$houseId');
      removedHouses.removeWhere((h) => h.boardingHouseId == houseId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> selectHouse(BoardingHouse h) async {
    selected = h;
    notifyListeners();
    await refreshHouse();
  }

  void clearSelectedHouse() {
    selected = null;
    dashboard = null;
    rooms = [];
    tenants = [];
    unassigned = [];
    announcements = [];
    concerns = [];
    notifyListeners();
  }

  Future<void> refreshHouse() async {
    final h = selected;
    if (h == null || _demoMode) return;
    await _busy(() async {
      final r = await Future.wait([
        api.request('GET', '/api/dashboard/${h.id}'),
        api.request('GET', '/api/rooms/${h.id}'),
        api.request('GET', '/api/tenants/${h.id}'),
        api.request('GET', '/api/announcements/${h.id}'),
        api.request('GET', '/api/concerns/${h.id}')
      ]);

      dashboard = DashboardData.fromJson(r[0]);
      rooms =
          (r[1]['rooms'] as List).map((x) => RoomModel.fromJson(x)).toList();
      tenants = (r[2]['tenants'] as List)
          .map((x) => TenantModel.fromJson(x))
          .toList();
      announcements = (r[3]['announcements'] as List)
          .map((x) => AnnouncementModel.fromJson(x))
          .toList();
      announcements.sort((a, b) => (b.publishedAt ?? DateTime(0))
          .compareTo(a.publishedAt ?? DateTime(0)));

      concerns = (r[4]['concerns'] as List)
          .map((x) => ConcernModel.fromJson(x))
          .toList();
      concerns.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

      if (owner) {
        final u = await api.request('GET', '/api/tenants/${h.id}/unassigned');
        unassigned = (u['accounts'] as List)
            .map((x) => UnassignedAccount.fromJson(x))
            .toList();
      } else {
        unassigned = [];
      }
    });
  }

  Future<BoardingHouse?> createHouse(
    String name,
    List<Map<String, dynamic>> roomsData,
  ) async {
    BoardingHouse? created;
    await _busy(() async {
      final res = await api.request('POST', '/api/boarding-houses', body: {
        'name': name,
        'rooms': roomsData,
        'academicYear': {
          'name': '2026-2027',
          'startsOn': '2026-06-01',
          'endsOn': '2027-06-01'
        }
      });
      created = BoardingHouse(
        id: res['id'],
        name: res['name'],
        domain: res['domain'] ?? '',
        joinKey: res['joinKey'] ?? '',
        role: 'owner',
      );
      await loadMine();
    });
    return created;
  }

  Future<void> joinHouse(String key) async {
    await _busy(() async {
      await api.request('POST', '/api/boarding-houses/join', body: {
        'keyOrDomain': key,
      });
      await loadMine();
    });
  }

  Future<void> addRoom(String roomNumber, int capacity) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('POST', '/api/rooms/${h.id}', body: {
        'roomNumber': roomNumber,
        'capacity': capacity,
      });
      await refreshHouse();
    });
  }

  Future<void> updateRoomCapacity(String roomId, int newCapacity) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('PATCH', '/api/rooms/${h.id}/$roomId', body: {
        'capacity': newCapacity,
      });
      await refreshHouse();
    });
  }

  Future<void> renameRoom(String roomId, String newRoomNumber) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('PATCH', '/api/rooms/${h.id}/$roomId', body: {
        'roomNumber': newRoomNumber,
      });
      await refreshHouse();
    });
  }

  Future<void> archiveRoom(String roomId) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('DELETE', '/api/rooms/${h.id}/$roomId');
      await refreshHouse();
    });
  }

  Future<TenantModel> createTenantRecord(
    String fullName,
    String? email,
    String? phone,
  ) async {
    final h = selected;
    if (h == null) throw StateError('No boarding house selected');
    late TenantModel created;
    await _busy(() async {
      final res = await api.request('POST', '/api/tenants/${h.id}', body: {
        'fullName': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      created = TenantModel.fromJson(res);
      await refreshHouse();
    });
    return created;
  }

  Future<void> associateTenant(
    String tenantId,
    String userId,
    String? roomId,
  ) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('POST', '/api/tenants/${h.id}/associations', body: {
        'tenantId': tenantId,
        'userId': userId,
        if (roomId != null && roomId.isNotEmpty) 'roomId': roomId,
      });
      await refreshHouse();
    });
  }

  Future<void> updateTenantStatus(String tenantId, String status) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('PUT', '/api/status/${h.id}/tenants/$tenantId', body: {
        'status': status,
      });
      await refreshHouse();
    });
  }

  Future<void> updateTenantMonthStatus(
    String tenantId,
    String monthStart,
    String status,
  ) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('PUT', '/api/status/${h.id}/tenants/$tenantId', body: {
        'monthStart': monthStart,
        'status': status,
      });
      await refreshHouse();
    });
  }

  Future<List<TenantMonthlyStatusModel>> getTenantStatuses(
      String tenantId) async {
    final h = selected;
    if (h == null) return [];
    final res =
        await api.request('GET', '/api/status/${h.id}/tenants/$tenantId');
    if (res != null && res['statuses'] is List) {
      return (res['statuses'] as List)
          .map((s) => TenantMonthlyStatusModel.fromJson(s))
          .toList();
    }
    return [];
  }

  Future<void> createAnnouncement(String title, String message) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('POST', '/api/announcements/${h.id}', body: {
        'title': title,
        'message': message,
      });
      await refreshHouse();
    });
  }

  Future<void> updateAnnouncement(
      String id, String title, String message) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('PATCH', '/api/announcements/${h.id}/$id', body: {
        'title': title,
        'message': message,
      });
      await refreshHouse();
    });
  }

  Future<void> deleteAnnouncement(String id) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('DELETE', '/api/announcements/${h.id}/$id');
      await refreshHouse();
    });
  }

  Future<void> createConcern(
    String category,
    String subject,
    String details, {
    List<Map<String, dynamic>>? attachments,
  }) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('POST', '/api/concerns/${h.id}', body: {
        'category': category,
        'subject': subject,
        'details': details,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments,
      });
      await refreshHouse();
    });
  }

  Future<void> updateConcern(
    String id,
    String status, {
    String? response,
  }) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('PATCH', '/api/concerns/${h.id}/$id', body: {
        'status': status,
        if (response != null && response.isNotEmpty) 'ownerResponse': response,
      });
      await refreshHouse();
    });
  }

  Future<void> updateConcernRating(String concernId, int rating) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api
          .request('PATCH', '/api/concerns/${h.id}/$concernId/rating', body: {
        'rating': rating,
      });
      await refreshHouse();
    });
  }

  Future<void> removeAccount(String userId) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('DELETE', '/api/tenants/${h.id}/members/$userId');
      await refreshHouse();
    });
  }

  Future<void> removeTenant(String tenantId) async {
    final h = selected;
    if (h == null) return;
    await _busy(() async {
      await api.request('DELETE', '/api/tenants/${h.id}/tenants/$tenantId');
      await refreshHouse();
    });
  }

  // ==========================================================
  // DEBUG DEMO SESSION
  // ==========================================================

  void _loadDemoSession() {
    _demoMode = true;
    _sessionExpired = false;
    error = null;

    user = const UserModel(
      id: 'demo-owner',
      email: 'maria@example.test',
      displayName: 'Maria Santos',
    );

    const house = BoardingHouse(
      id: 'demo-house',
      name: 'Green Haven Boarding House',
      domain: 'greenhaven',
      joinKey: 'GHBV-8X7K-2P9M',
      role: 'owner',
      ownerName: 'Maria Santos',
      ownerEmail: 'maria@example.test',
    );
    houses = [house];
    removedHouses = [];
    selected = house;

    dashboard = const DashboardData(
      name: 'Green Haven Boarding House',
      domain: 'greenhaven',
      joinKey: 'GHBV-8X7K-2P9M',
      rooms: 5,
      tenants: 5,
      openSlots: 13,
      concerns: 1,
      unassigned: 1,
    );

    rooms = const [
      RoomModel(
        id: 'demo-room-101',
        roomNumber: '101',
        capacity: 4,
        occupied: 2,
        available: 2,
        occupancyStatus: 'available',
      ),
      RoomModel(
        id: 'demo-room-102',
        roomNumber: '102',
        capacity: 4,
        occupied: 1,
        available: 3,
        occupancyStatus: 'available',
      ),
      RoomModel(
        id: 'demo-room-103',
        roomNumber: '103',
        capacity: 2,
        occupied: 2,
        available: 0,
        occupancyStatus: 'full',
      ),
      RoomModel(
        id: 'demo-room-104',
        roomNumber: '104',
        capacity: 4,
        occupied: 0,
        available: 4,
        occupancyStatus: 'available',
      ),
      RoomModel(
        id: 'demo-room-105',
        roomNumber: '105',
        capacity: 4,
        occupied: 0,
        available: 4,
        occupancyStatus: 'available',
      ),
    ];

    tenants = const [
      TenantModel(
        id: 'demo-tenant-1',
        fullName: 'Juan Dela Cruz',
        email: 'juan.delacruz@example.test',
        accountEmail: 'juan@example.test',
        roomNumber: '103',
        roomId: 'demo-room-103',
        userId: 'demo-user-1',
        paymentStatus: 'paid',
      ),
      TenantModel(
        id: 'demo-tenant-2',
        fullName: 'Maria Lopez',
        email: 'maria.lopez@example.test',
        accountEmail: 'maria@example.test',
        roomNumber: '103',
        roomId: 'demo-room-103',
        userId: 'demo-user-2',
        paymentStatus: 'partial',
      ),
      TenantModel(
        id: 'demo-tenant-3',
        fullName: 'Pedro Reyes',
        email: 'pedro.reyes@example.test',
        accountEmail: 'pedro@example.test',
        roomNumber: '101',
        roomId: 'demo-room-101',
        userId: 'demo-user-3',
        paymentStatus: 'paid',
      ),
      TenantModel(
        id: 'demo-tenant-4',
        fullName: 'Ana Garcia',
        email: 'ana.garcia@example.test',
        accountEmail: 'ana@example.test',
        roomNumber: '101',
        roomId: 'demo-room-101',
        userId: 'demo-user-4',
        paymentStatus: 'unpaid',
      ),
      TenantModel(
        id: 'demo-tenant-5',
        fullName: 'Mike Cruz',
        email: 'mike.cruz@example.test',
        accountEmail: 'mike@example.test',
        roomNumber: '102',
        roomId: 'demo-room-102',
        userId: 'demo-user-5',
        paymentStatus: 'paid',
      ),
    ];

    final now = DateTime.now();
    announcements = [
      AnnouncementModel(
        id: 'demo-notice-1',
        title: 'Water Interruption Notice',
        message:
            'There will be a water interruption on May 25 from 9:00 AM to 12:00 PM. Please store water in advance.',
        publishedAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      AnnouncementModel(
        id: 'demo-notice-2',
        title: 'Reminder: Cleanliness Drive',
        message:
            'Please keep our common areas clean. Inspection this coming Saturday.',
        publishedAt: now.subtract(const Duration(days: 3, hours: 6)),
      ),
    ];

    concerns = [
      ConcernModel(
        id: 'demo-concern-1',
        subject: 'Leaky faucet in the kitchen',
        details:
            'The faucet in the kitchen is leaking continuously. Please have it checked.',
        category: 'maintenance',
        status: ConcernModel.statusPending,
        tenantName: 'Juan Dela Cruz',
        roomNumber: '103',
        createdAt: now.subtract(const Duration(minutes: 43)),
      ),
    ];

    unassigned = [
      UnassignedAccount(
        userId: 'demo-unassigned-1',
        email: 'newneighbor@example.test',
        displayName: 'New Neighbor',
        joinedAt: now.subtract(const Duration(days: 2)),
      ),
    ];

    loading = false;
    notifyListeners();
  }

  Future<void> _busy(
    Future<void> Function() op, {
    bool globalLoader = true,
  }) async {
    if (globalLoader) {
      loading = true;
      notifyListeners();
    }
    error = null;
    try {
      await op();
    } catch (e) {
      if (e is ApiException) {
        error = e.message;
      } else {
        error = 'Something went wrong. Please try again.';
        if (kDebugMode) debugPrint('Unexpected app error: ${e.runtimeType}');
      }
      rethrow;
    } finally {
      if (globalLoader) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}
