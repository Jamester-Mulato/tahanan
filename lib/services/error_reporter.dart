import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'token_store.dart';

/// Reports uncaught client errors to the backend so an admin can see them in
/// the admin console.
///
/// Design rules:
///  * Never throws, never blocks the UI, never reports itself.
///  * Duplicate messages are dropped for a minute; at most 20 per minute.
///  * The bearer token is attached when available so the report is linked to
///    the signed-in account; reports from the login screen stay anonymous.
class ErrorReporter {
  static final _tokens = TokenStore();
  static final Map<String, DateTime> _recent = {};
  static DateTime _windowStart = DateTime.now();
  static int _windowCount = 0;
  static bool _sending = false;

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exceptionAsString(), details.stack);
    };
  }

  static void report(
    String message,
    StackTrace? stack, {
    String? screen,
    Map<String, dynamic>? extra,
  }) {
    final now = DateTime.now();
    final key = message.length > 160 ? message.substring(0, 160) : message;
    final last = _recent[key];
    if (last != null && now.difference(last).inSeconds < 60) return;
    _recent[key] = now;
    if (_recent.length > 200) {
      _recent.removeWhere((_, time) => now.difference(time).inMinutes > 10);
    }

    if (now.difference(_windowStart).inMinutes >= 1) {
      _windowStart = now;
      _windowCount = 0;
    }
    if (_windowCount >= 20) return;
    _windowCount++;

    unawaited(_send(message, stack, screen, extra));
  }

  static Future<void> _send(
    String message,
    StackTrace? stack,
    String? screen,
    Map<String, dynamic>? extra,
  ) async {
    if (_sending) return;
    _sending = true;
    try {
      final token = await _tokens.read();
      await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/api/client-errors'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'message': message,
              'stack': stack?.toString(),
              'screen': screen,
              'platform': defaultTargetPlatform.name,
              'appVersion': '1.0.0',
              'extra': {
                'release': kReleaseMode,
                ...?extra,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // The reporter must never become a source of errors itself.
    } finally {
      _sending = false;
    }
  }
}
