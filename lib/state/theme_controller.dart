import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted Light / Dark / System preference. The visual dark mode is applied
/// by [TahananApp] as a whole-app display filter, so the light design stays
/// pixel-identical and the phone/web layouts are untouched.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static const _key = 'tahanan.theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeController() {
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isDark {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  Future<void> load() async {
    try {
      // Web preview/testing override: ?theme=dark or ?theme=light.
      if (kIsWeb) {
        final forced = Uri.base.queryParameters['theme'];
        if (forced == 'dark' || forced == 'light') {
          _mode = forced == 'dark' ? ThemeMode.dark : ThemeMode.light;
          notifyListeners();
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      _mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (_) {
      // A broken preference store must never stop the app.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_key, value);
    } catch (_) {
      // Ignore storage failures; the choice still applies this session.
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode == ThemeMode.system) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
