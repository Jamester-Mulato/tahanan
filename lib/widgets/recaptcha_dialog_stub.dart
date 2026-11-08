import 'package:flutter/material.dart';

/// Fallback for platforms without a WebView. The server-side challenge is
/// used when reCAPTCHA cannot be presented.
Future<String?> showRecaptchaDialog(
  BuildContext context, {
  required String apiBaseUrl,
}) async {
  return null;
}
