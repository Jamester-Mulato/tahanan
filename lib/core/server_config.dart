import 'package:shared_preferences/shared_preferences.dart';

/// Where the app looks for the Tahanan backend.
///
/// The build can ship a default (`--dart-define=TAHANAN_API_URL=...`), and the
/// value can be changed at runtime from the app so a tunnel or a new host does
/// not require rebuilding the APK. The choice is stored per device.
class ServerConfig {
  static const _key = 'tahanan.api_base_url';

  /// Compile-time default. The release build sets this to the public HTTPS
  /// address; without it, local development uses the loopback backend.
  static const String fallbackUrl = String.fromEnvironment(
    'TAHANAN_API_URL',
    defaultValue: 'http://localhost:8080',
  );

  static String? _saved;

  static String get baseUrl =>
      (_saved != null && _saved!.isNotEmpty) ? _saved! : fallbackUrl;

  static String get defaultUrl => fallbackUrl;

  static bool get isOverridden => _saved != null && _saved!.isNotEmpty;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      if (value != null && value.trim().isNotEmpty) {
        _saved = _normalize(value);
      }
    } catch (_) {
      // A broken preferences store must not stop the app from starting.
    }
  }

  static Future<void> save(String url) async {
    final value = _normalize(url);
    _saved = value.isEmpty ? null : value;
    final prefs = await SharedPreferences.getInstance();
    if (_saved == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, _saved!);
    }
  }

  static Future<void> reset() => save('');

  /// HTTPS everywhere, except a loopback/emulator address used in development.
  static String? validate(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter a server URL.';
    final uri = Uri.tryParse(v);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a full URL, for example https://example.com';
    }
    if (uri.scheme == 'https') return null;
    if (uri.scheme == 'http' && _isLoopback(uri.host)) return null;
    return 'Use https:// unless the server is on this device.';
  }

  static bool _isLoopback(String host) =>
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '10.0.2.2' ||
      host == '::1';

  static String _normalize(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');
}
