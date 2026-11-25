import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// Session policy fetched from the backend at startup.
///
/// The admin site can change it at runtime; the values here are refreshed
/// every time the app (or web page) loads, so no rebuild is required.
class SessionConfig {
  static Duration idle = const Duration(minutes: 6);
  static Duration warning = const Duration(minutes: 1);

  static Future<void> load() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/api/config'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data is! Map) return;

      final idleSeconds = (data['idleTimeoutSeconds'] as num?)?.toInt();
      final warningSeconds = (data['warningSeconds'] as num?)?.toInt();

      if (idleSeconds != null && idleSeconds >= 5) {
        idle = Duration(seconds: idleSeconds);
      }
      if (warningSeconds != null && warningSeconds >= 0) {
        warning = Duration(seconds: warningSeconds);
      }
      if (warning > idle) warning = idle;
    } catch (_) {
      // Keep the defaults when the server is unreachable.
    }
  }
}
