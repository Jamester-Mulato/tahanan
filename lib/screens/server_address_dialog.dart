import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/design_tokens.dart';
import '../core/server_config.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';

/// Lets an administrator point this device at a different backend (a tunnel, a
/// LAN address, or a deployed server) without rebuilding the APK.
Future<void> showServerAddressDialog(BuildContext context) async {
  final app = context.read<AppState>();
  final controller = TextEditingController(text: ServerConfig.baseUrl);
  String? error;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        Future<void> apply(String value) async {
          final problem = ServerConfig.validate(value);
          if (problem != null) {
            setState(() => error = problem);
            return;
          }
          await ServerConfig.save(value);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
          title: Text('Server address', style: AppType.h3),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The app talks to this backend. Use the HTTPS address of your '
                  'tunnel or deployment. Changing it signs you out so the next '
                  'login goes to the new server.',
                  style: AppType.body.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://example.trycloudflare.com',
                    errorText: error,
                    prefixIcon: const Icon(AppIcons.link, size: 18),
                  ),
                  onSubmitted: (value) => apply(value),
                ),
                const SizedBox(height: 8),
                Text(
                  'Default for this build: ${ServerConfig.defaultUrl}',
                  style: AppType.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ServerConfig.reset();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(
                'Use default',
                style: AppType.bodyStrong.copyWith(color: AppColors.muted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => apply(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );

  controller.dispose();
  if (saved != true || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Server set to ${ServerConfig.baseUrl}'),
      behavior: SnackBarBehavior.floating,
    ),
  );
  await app.signOut();
}
