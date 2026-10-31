import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic>? details;

  ApiException(this.status, this.message, [this.details]);

  bool get isUnauthorized => status == 401;
  bool get isNetworkError => status == 0;

  /// Seconds the server asked the client to wait (lockout, IP block, cooldown).
  int? get retryAfter {
    final value = details?['retryAfter'];
    if (value is num) return value.toInt();
    final match = RegExp(r'(\d+)\s*second').firstMatch(message);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  @override
  String toString() => message;
}

/// Small JSON-over-HTTP client with a deliberately narrow surface:
///
/// * Only talks to [AppConfig.apiBaseUrl].
/// * Requires HTTPS for release builds (except loopback development hosts).
/// * Never logs tokens, request bodies or response bodies.
/// * Caps response size and converts every failure into a safe message.
class ApiClient {
  ApiClient({this.onUnauthorized});

  // A free Render instance can take up to a minute to wake from sleep, so the
  // first request after idle needs a longer budget than a local server.
  static const Duration _timeout = Duration(seconds: 75);
  static const int _maxResponseBytes = 5 * 1024 * 1024;
  static const int _maxMessageLength = 240;

  final http.Client _client = http.Client();

  /// Called once when the backend rejects the stored access token.
  VoidCallback? onUnauthorized;

  /// While true, a 401 does not tear down the session. Used during the
  /// sign-in handshake, where the token is set but the first request may race.
  bool suppressUnauthorized = false;

  String? token;

  void dispose() {
    _client.close();
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    if (auth && (token == null || token!.isEmpty)) {
      throw ApiException(
        401,
        'Your session has expired. Please sign in again.',
      );
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    _assertTransportIsSecure(uri);

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      if (auth && token != null) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(_timeout);
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(_timeout);
          break;
        case 'DELETE':
          response =
              await _client.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          throw ArgumentError.value(
              method, 'method', 'Unsupported HTTP method');
      }
    } on TimeoutException {
      throw ApiException(
        0,
        'The server is waking up. Please tap again in a moment.',
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('API $method $path failed: ${error.runtimeType}');
      }
      throw ApiException(
        0,
        'Cannot reach the server right now. Check your connection and try again.',
      );
    }

    if (kDebugMode) {
      // Never log headers, bodies or tokens.
      debugPrint('API $method $path -> ${response.statusCode}');
    }

    final text = _readBody(response);
    final decoded = _tryDecode(text);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && auth && !suppressUnauthorized) {
        onUnauthorized?.call();
      }
      throw ApiException(
        response.statusCode,
        _safeErrorMessage(response.statusCode, decoded),
        decoded is Map && decoded['details'] is Map
            ? Map<String, dynamic>.from(decoded['details'] as Map)
            : null,
      );
    }

    if (decoded == _invalidJson) {
      throw ApiException(
        response.statusCode,
        'The server returned an invalid response. Please try again.',
      );
    }

    return decoded;
  }

  String _readBody(http.Response response) {
    if (response.bodyBytes.length > _maxResponseBytes) {
      throw ApiException(
        response.statusCode,
        'The server response was too large to process.',
      );
    }
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      return '';
    }
  }

  static const Object _invalidJson = Object();

  Object? _tryDecode(String text) {
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return _invalidJson;
    }
  }

  String _safeErrorMessage(int status, Object? decoded) {
    if (decoded is Map) {
      final message = decoded['message'] ?? decoded['error'];
      if (message is String) {
        final cleaned = _sanitize(message);
        if (cleaned.isNotEmpty) return cleaned;
      }
    }

    switch (status) {
      case 400:
        return 'Some of the details look invalid. Please review and try again.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to do that.';
      case 404:
        return 'We could not find what you were looking for.';
      case 409:
        return 'That action conflicts with the current data. Please refresh.';
      case 413:
        return 'That upload is too large. Please choose a smaller file.';
      case 429:
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        if (status >= 500) {
          return 'The server had a problem. Please try again shortly.';
        }
        return 'Request failed ($status). Please try again.';
    }
  }

  String _sanitize(String message) {
    final singleLine = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.isEmpty) return '';
    if (singleLine.length > _maxMessageLength) {
      return '${singleLine.substring(0, _maxMessageLength)}…';
    }
    return singleLine;
  }

  void _assertTransportIsSecure(Uri uri) {
    if (kReleaseMode && uri.scheme != 'https' && !_isLoopback(uri.host)) {
      throw ApiException(
        0,
        'Insecure connection blocked. Tahanan requires HTTPS in release builds.',
      );
    }
  }

  bool _isLoopback(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2';
  }
}
