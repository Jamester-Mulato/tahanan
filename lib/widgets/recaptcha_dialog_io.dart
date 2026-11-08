import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_colors.dart';
import 'app_icons.dart';
import 'tahanan_kit.dart';

/// Opens the real Google reCAPTCHA v2 checkbox in a WebView and returns the
/// token, or null when the user cancels.
Future<String?> showRecaptchaDialog(
  BuildContext context, {
  required String apiBaseUrl,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (_) => _RecaptchaDialog(apiBaseUrl: apiBaseUrl),
  );
}

class _RecaptchaDialog extends StatefulWidget {
  final String apiBaseUrl;

  const _RecaptchaDialog({required this.apiBaseUrl});

  @override
  State<_RecaptchaDialog> createState() => _RecaptchaDialogState();
}

class _RecaptchaDialogState extends State<_RecaptchaDialog> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3FBF6))
      ..addJavaScriptChannel(
        'RecaptchaBridge',
        onMessageReceived: (message) {
          final token = message.message.trim();
          if (token.isNotEmpty && mounted) {
            Navigator.of(context).pop(token);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('${widget.apiBaseUrl}/recaptcha'));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      insetAnimationDuration: Duration.zero,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 8),
              child: Row(
                children: [
                  Icon(
                    AppIcons.shieldLine,
                    size: 18,
                    color: kPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google reCAPTCHA',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Verify once to continue to Tahanan',
                          style: TextStyle(
                            color: kInkMuted,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(AppIcons.close, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: WebViewWidget(controller: _controller)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Protected by Google reCAPTCHA',
                      style: TextStyle(
                        color: kInkMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
