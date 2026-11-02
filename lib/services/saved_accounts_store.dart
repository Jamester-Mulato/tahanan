import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One account remembered on this device.
///
/// Only the session token is stored, never the password. A token can be
/// revoked or can expire, in which case the account is removed from the list
/// and the user signs in again with their password.
class SavedAccount {
  final String id;
  final String email;
  final String? username;
  final String displayName;
  final String token;

  /// Present only while the 7-day "remember me" window is active.
  final String? password;
  final String? rememberToken;
  final DateTime? rememberUntil;
  final DateTime? lastUsedAt;

  const SavedAccount({
    required this.id,
    required this.email,
    this.username,
    required this.displayName,
    required this.token,
    this.password,
    this.rememberToken,
    this.rememberUntil,
    this.lastUsedAt,
  });

  /// What the user types in the log-in field.
  String get loginName =>
      (username != null && username!.isNotEmpty) ? username! : email;

  bool get remembersMe =>
      rememberToken != null &&
      rememberToken!.isNotEmpty &&
      rememberUntil != null &&
      rememberUntil!.isAfter(DateTime.now());

  bool get canAutofill => password != null && password!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        if (username != null) 'username': username,
        'displayName': displayName,
        'token': token,
        if (password != null) 'password': password,
        if (rememberToken != null) 'rememberToken': rememberToken,
        if (rememberUntil != null)
          'rememberUntil': rememberUntil!.toIso8601String(),
        if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
      };

  static SavedAccount? fromJson(Object? value) {
    if (value is! Map) return null;

    final id = value['id'];
    final email = value['email'];
    final displayName = value['displayName'];
    final token = value['token'];

    if (id is! String ||
        email is! String ||
        displayName is! String ||
        token is! String) {
      return null;
    }
    if (id.isEmpty || email.isEmpty || token.isEmpty) return null;

    final password = value['password'];
    final rememberToken = value['rememberToken'];
    final rememberUntil = value['rememberUntil'];
    final lastUsedAt = value['lastUsedAt'];
    final username = value['username'];

    return SavedAccount(
      id: id,
      email: email,
      username: username is String && username.isNotEmpty ? username : null,
      displayName: displayName,
      token: token,
      password: password is String && password.isNotEmpty ? password : null,
      rememberToken: rememberToken is String && rememberToken.isNotEmpty
          ? rememberToken
          : null,
      rememberUntil:
          rememberUntil is String ? DateTime.tryParse(rememberUntil) : null,
      lastUsedAt: lastUsedAt is String ? DateTime.tryParse(lastUsedAt) : null,
    );
  }
}

/// Persists the list of remembered accounts in the platform keystore.
class SavedAccountsStore {
  static const _secureKey = 'tahanan_saved_accounts_v1';
  static const _debugKey = 'tahanan_saved_accounts_v1_debug';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<List<SavedAccount>> read() async {
    String? raw;

    try {
      raw = await _storage.read(key: _secureKey);
    } catch (error) {
      debugPrint(
        'SavedAccountsStore: secure read unavailable (${error.runtimeType})',
      );
    }

    if (raw == null || raw.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_debugKey);
      } catch (_) {
        raw = null;
      }
    }

    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final accounts = <SavedAccount>[];
      for (final item in decoded) {
        final account = SavedAccount.fromJson(item);
        if (account != null) accounts.add(account);
      }
      return accounts;
    } catch (error) {
      debugPrint(
        'SavedAccountsStore: invalid data ignored (${error.runtimeType})',
      );
      return const [];
    }
  }

  Future<void> write(List<SavedAccount> accounts) async {
    final raw = jsonEncode(accounts.map((a) => a.toJson()).toList());

    try {
      await _storage.write(key: _secureKey, value: raw);
      return;
    } catch (error) {
      debugPrint(
        'SavedAccountsStore: secure write unavailable (${error.runtimeType})',
      );
    }

    if (kReleaseMode) {
      // Fail closed: do not put session tokens in plain-text preferences.
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_debugKey, raw);
    } catch (_) {
      // Nothing else to do; the session itself still works.
    }
  }
}
