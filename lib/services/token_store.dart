import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the access token in the platform's secure keystore.
///
/// - Android: RSA-OAEP wrapped key + AES-GCM encrypted storage.
/// - iOS/macOS: Keychain, readable only after the device has been unlocked
///   once on this device.
/// - Windows/Linux/Web: platform-backed secure storage where available.
///
/// Older builds stored the token in SharedPreferences in plain text. Those
/// tokens are migrated to secure storage and the insecure copy is removed.
class TokenStore {
  static const _secureKey = 'tahanan_access_token';
  static const _legacyKey = 'tahanan_token';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> read() async {
    try {
      final token = await _storage.read(key: _secureKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (error) {
      // Never log the token itself.
      debugPrint('TokenStore: secure read unavailable (${error.runtimeType})');
    }

    return _migrateLegacyToken();
  }

  Future<void> write(String token) async {
    try {
      await _storage.write(key: _secureKey, value: token);
      await _removeLegacyToken();
    } catch (error) {
      debugPrint('TokenStore: secure write unavailable (${error.runtimeType})');
      if (kReleaseMode) {
        // Fail closed: do not silently downgrade to plain-text storage in
        // release builds.
        throw StateError(
          'Secure storage is unavailable on this device. Please update your '
          'device or use a supported platform.',
        );
      }
      // Debug-only fallback so local development keeps working when the
      // platform keystore is not available (for example plain-HTTP web).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_legacyKey, token);
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _secureKey);
    } catch (error) {
      debugPrint('TokenStore: secure delete failed (${error.runtimeType})');
    }
    await _removeLegacyToken();
  }

  Future<String?> _migrateLegacyToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_legacyKey);
      if (legacy == null || legacy.isEmpty) return null;

      try {
        await _storage.write(key: _secureKey, value: legacy);
      } catch (_) {
        // Keep the legacy copy for debug builds if secure storage is absent.
        if (kReleaseMode) {
          await prefs.remove(_legacyKey);
          return null;
        }
      }
      await prefs.remove(_legacyKey);
      return legacy;
    } catch (error) {
      debugPrint('TokenStore: migration failed (${error.runtimeType})');
      return null;
    }
  }

  Future<void> _removeLegacyToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_legacyKey)) {
        await prefs.remove(_legacyKey);
      }
    } catch (_) {
      // Ignore cleanup failures.
    }
  }
}
