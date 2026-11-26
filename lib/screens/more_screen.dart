import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../routing/liquid_page_route.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';
import '../widgets/tahanan_kit.dart';
import '../widgets/privacy_notice.dart';
import 'more_kit.dart';
import 'server_address_dialog.dart';
import 'owner/announcements.dart';
import 'change_password_screen.dart';

class MoreScreen extends StatelessWidget {
  final bool isOwner;

  const MoreScreen({super.key, this.isOwner = true});

  @override
  Widget build(BuildContext context) {
    return MoreBody(
      isOwner: isOwner,
      onSwitchHouse: () {
        HapticFeedback.selectionClick();
        context.read<AppState>().clearSelectedHouse();
      },
      onAnnouncements: () => pushLiquidPage(
        context,
        _AnnouncementsPage(isOwner: isOwner),
      ),
      onHelp: () => _showInfoSheet(
        context,
        title: 'Help & FAQ',
        body:
            'Rooms are managed from the Rooms tab. Tenants join with the house key you share here. '
            'Rent status is updated month by month, and concerns can be resolved with a short reply.',
      ),
      onPrivacy: () => showPrivacyNotice(context),
      onTerms: () => _showInfoSheet(
        context,
        title: 'Terms of use',
        body:
            'Use Tahanan only for boarding houses you own or live in. Keep tenant records accurate, '
            'and treat everyone in the house with respect.',
      ),
      onSignOut: () => _confirmSignOut(context),
      onChangePassword: () => pushLiquidPage(
        context,
        const ChangePasswordScreen(),
      ),
      onServerAddress: () => showServerAddressDialog(context),
      onCopyKey: () {
        final key = context.read<AppState>().selected?.joinKey ?? '';
        if (key.isEmpty) return;
        Clipboard.setData(ClipboardData(text: key));
        HapticFeedback.selectionClick();
        showTSnack(context, 'House key copied', icon: AppIcons.keyLine);
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await tConfirm(
      context,
      title: 'Sign out?',
      message: 'You can sign back in at any time with the same Google account.',
      confirm: 'Sign out',
      danger: true,
    );
    if (ok && context.mounted) {
      HapticFeedback.mediumImpact();
      context.read<AppState>().signOut();
    }
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showLiquidSheet<void>(
      context,
      (ctx) => tSheetBody(
        ctx,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                color: kInkMuted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            TButton(
              text: 'Close',
              variant: TButtonVariant.secondary,
              height: 48,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementsPage extends StatelessWidget {
  final bool isOwner;

  const _AnnouncementsPage({required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnouncementsScreen(
        isOwner: isOwner,
        onBack: () => Navigator.of(context).pop(),
      ),
    );
  }
}
