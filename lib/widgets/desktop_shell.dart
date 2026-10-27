import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/design_tokens.dart';
import '../state/app_state.dart';
import 'app_icons.dart';
import 'pressable.dart';
import 'privacy_notice.dart';
import 'tahanan_kit.dart';
import 'ui.dart';

/// Desktop web only. The Android layout is never affected: every branch here
/// requires `kIsWeb` and a wide viewport.
const double kDesktopBreakpoint = 1000;
const double kDesktopContentMaxWidth = 1200;

bool isDesktopWeb(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Website shell: a normal top navigation, a centred content column, and a
/// footer. The mobile app keeps its bottom navigation.
class DesktopShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<TahananNavItem> items;
  final Widget child;

  const DesktopShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WebsiteHeader(
          currentIndex: currentIndex,
          onTap: onTap,
          items: items,
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kDesktopContentMaxWidth,
              ),
              child: SizedBox.expand(child: child),
            ),
          ),
        ),
        const _WebsiteFooter(),
      ],
    );
  }
}

class _WebsiteHeader extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<TahananNavItem> items;

  const _WebsiteHeader({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    final name = user?.displayName ?? 'Member';
    final initial = name.trim().isEmpty ? 'T' : name.trim()[0].toUpperCase();

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: kHairline)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kDesktopContentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const _Brand(),
                const SizedBox(width: 40),
                for (var i = 0; i < items.length; i++)
                  _WebsiteNavLink(
                    label: items[i].label,
                    selected: i == currentIndex,
                    onTap: () {
                      if (i != currentIndex) onTap(i);
                    },
                  ),
                const Spacer(),
                _AccountChip(name: name, initial: initial),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A4B30), Color(0xFF16A356)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(AppIcons.home, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tahanan',
              style: AppType.h3.copyWith(fontSize: 19, letterSpacing: -0.2),
            ),
            Text(
              'BOARDING HOUSE, IN ORDER',
              style: AppType.eyebrow.copyWith(fontSize: 8, color: kInkMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _WebsiteNavLink extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WebsiteNavLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      pressedScale: 0.99,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppType.bodyStrong.copyWith(
                fontSize: 13,
                color: selected ? kPrimary : kInkSoft,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: AppTime.fast,
              height: 2,
              width: selected ? 18 : 0,
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  final String name;
  final String initial;

  const _AccountChip({required this.name, required this.initial});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) async {
        if (value != 'sign-out') return;
        final ok = await tConfirm(
          context,
          title: 'Sign out?',
          message: 'You can sign back in at any time.',
          confirm: 'Sign out',
          danger: true,
        );
        if (ok && context.mounted) {
          await context.read<AppState>().signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'sign-out',
          child: Row(
            children: [
              Icon(AppIcons.logout, size: 17, color: kInkSoft),
              SizedBox(width: 8),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: kPrimary,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 9),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.bodyStrong.copyWith(fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 4),
            Icon(AppIcons.expand, size: 15, color: kInkSoft),
          ],
        ),
      ),
    );
  }
}

class _WebsiteFooter extends StatelessWidget {
  const _WebsiteFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.86),
        border: Border(top: BorderSide(color: kHairline)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kDesktopContentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '© 2026 Jamester C. Mulato. All rights reserved.',
                  style: tMeta().copyWith(fontSize: 10),
                ),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => showPrivacyNotice(context),
                  child: Text(
                    'Privacy',
                    style: tMeta().copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                  ),
                ),
                Text('·', style: tMeta().copyWith(fontSize: 10)),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showTerms(context),
                  child: Text(
                    'Terms',
                    style: tMeta().copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text('Tahanan 1.0', style: tMeta().copyWith(fontSize: 9.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        title: Text('Terms of use', style: AppType.h3),
        content: Text(
          'Use Tahanan only for boarding houses you own or live in. Keep tenant '
          'records accurate, protect your sign-in codes, and treat everyone in '
          'the house with respect.',
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
