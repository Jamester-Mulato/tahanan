// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'app_icons.dart';
import 'tahanan_kit.dart';

/// Web implementation of the Google reCAPTCHA: an in-app dialog with an
/// embedded Google frame. No popup, no second window, no opener handshake.
Future<String?> showRecaptchaDialog(
  BuildContext context, {
  required String apiBaseUrl,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RecaptchaWebDialog(apiBaseUrl: apiBaseUrl),
  );
}

class _RecaptchaWebDialog extends StatefulWidget {
  final String apiBaseUrl;

  const _RecaptchaWebDialog({required this.apiBaseUrl});

  @override
  State<_RecaptchaWebDialog> createState() => _RecaptchaWebDialogState();
}

class _RecaptchaWebDialogState extends State<_RecaptchaWebDialog> {
  late final String _viewType;
  late final StreamSubscription<html.MessageEvent> _messages;

  @override
  void initState() {
    super.initState();

    _viewType = 'tahanan-recaptcha-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final frame = html.IFrameElement()
        ..src = '${widget.apiBaseUrl}/recaptcha?embed=1'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'clipboard-write';
      frame.setAttribute('title', 'Google reCAPTCHA');
      return frame;
    });

    _messages = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is String && data.trim().length > 20 && mounted) {
        Navigator.of(context).pop(data.trim());
      }
    });
  }

  @override
  void dispose() {
    _messages.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 410,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(AppIcons.shieldLine, size: 18, color: kPrimary),
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
                        SizedBox(height: 1),
                        Text(
                          'Verify once to continue to Tahanan',
                          style: TextStyle(
                            color: kInkMuted,
                            fontSize: 11,
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
            Divider(height: 1, color: kHairline),
            Expanded(
              child: HtmlElementView(viewType: _viewType),
            ),
            Divider(height: 1, color: kHairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
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
