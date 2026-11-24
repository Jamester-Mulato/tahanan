import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/design_tokens.dart';
import '../../models/models.dart';
import '../../routing/liquid_page_route.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/heavy_motion.dart';
import '../../widgets/lottie_art.dart';
import '../../widgets/pressable.dart';
import '../../widgets/refresh_overlay.dart';
import '../../widgets/scroll_reveal.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/ui.dart';
import 'report_concern.dart';

/// Tenant landing screen, rebuilt as a day-in-the-house dashboard.
class TenantHomeScreen extends StatelessWidget {
  final void Function(int)? onNavigateTab;

  const TenantHomeScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final user = s.user;
    final h = s.selected;

    TenantModel? me;
    if (user != null) {
      for (final t in s.tenants) {
        if (t.userId == user.id) {
          me = t;
          break;
        }
      }
    }

    final firstName = user?.displayName.split(' ').first ?? 'there';
    final currentMonth = DateFormat('MMMM').format(DateTime.now());
    final payment = (me?.paymentStatus ?? 'paid').toLowerCase();
    final paid = payment == 'paid';
    final partial = payment == 'partial';
    final paymentLabel = paid
        ? 'Paid'
        : partial
            ? 'Partial'
            : 'Unpaid';
    final paymentColor = paid
        ? const Color(0xFFC7F26A)
        : partial
            ? const Color(0xFFFDE68A)
            : const Color(0xFFFCA5A5);

    final latestNotice =
        s.announcements.isNotEmpty ? s.announcements.first : null;
    final latestConcern = s.concerns.isNotEmpty ? s.concerns.first : null;

    final housemates = me == null
        ? <TenantModel>[]
        : s.tenants
            .where((t) => t.id != me!.id && t.roomId == me.roomId)
            .toList();

    return TahananBackground(
      child: Stack(
        children: [
          RefreshIndicator(
            color: kPrimary,
            backgroundColor: AppColors.surface,
            onRefresh: s.refreshHouse,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: tScreenPadding(context).copyWith(bottom: 130),
              children: [
                ScrollReveal(
                  index: 0,
                  child: _TenantHero(
                    month: currentMonth,
                    firstName: firstName,
                    houseName: h?.name ?? 'Boarding house',
                    roomNumber: me?.roomNumber,
                    paymentLabel: paymentLabel,
                    paymentColor: paymentColor,
                  ),
                ),
                const SizedBox(height: 14),
                ScrollReveal(
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: _HomeAction(
                          icon: AppIcons.chatLine,
                          title: 'Report',
                          subtitle: 'A concern at home',
                          onTap: () => pushLiquidPage(
                            context,
                            const ReportConcernScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HomeAction(
                          icon: AppIcons.megaphoneLine,
                          title: 'Notices',
                          subtitle: 'From your owner',
                          onTap: () => onNavigateTab?.call(1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ScrollReveal(
                  index: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: _HomeAction(
                          icon: AppIcons.keyLine,
                          title: 'Payments',
                          subtitle: 'This month',
                          onTap: me == null
                              ? null
                              : () => TenantCalendarSheet.show(
                                    context,
                                    me!,
                                    isOwner: false,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HomeAction(
                          icon: AppIcons.articleLine,
                          title: 'My reports',
                          subtitle: 'Status and replies',
                          onTap: () => onNavigateTab?.call(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (latestNotice != null) ...[
                  ScrollReveal(
                    index: 3,
                    child: const _SectionLabel(
                      eyebrow: 'News from the house',
                      title: 'Latest notice',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ScrollReveal(
                    index: 4,
                    child: _NoticeCard(
                      title: latestNotice.title,
                      time: tWhen(latestNotice.publishedAt),
                      onTap: () => onNavigateTab?.call(1),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (latestConcern != null) ...[
                  ScrollReveal(
                    index: 5,
                    child: const _SectionLabel(
                      eyebrow: 'Your reports',
                      title: 'Most recent concern',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ScrollReveal(
                    index: 6,
                    child: TConcernCard(
                      subject: latestConcern.subject,
                      meta:
                          'Room ${latestConcern.roomNumber ?? '—'} · ${tWhen(latestConcern.createdAt)}',
                      icon: AppIcons.buildLine,
                      statusText: latestConcern.status.toLowerCase() ==
                              ConcernModel.statusResolved
                          ? 'Resolved'
                          : 'Pending',
                      statusTone: latestConcern.status.toLowerCase() ==
                              ConcernModel.statusResolved
                          ? TPillTone.ok
                          : TPillTone.pending,
                      rating: latestConcern.rating,
                      onTap: () => TenantConcernDetailSheet.show(
                        context,
                        latestConcern,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                ScrollReveal(
                  index: 7,
                  child: _SectionLabel(
                    eyebrow: 'Room ${me?.roomNumber ?? '—'}',
                    title: 'Your housemates',
                  ),
                ),
                const SizedBox(height: 8),
                ScrollReveal(
                  index: 8,
                  child: _HousematesCard(housemates: housemates),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '© 2026 Jamester C. Mulato. All rights reserved.',
                    style: AppType.caption.copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          RefreshOverlay(visible: s.loading),
        ],
      ),
    );
  }
}

// ==============================================================
// HERO
// ==============================================================

class _TenantHero extends StatelessWidget {
  final String month;
  final String firstName;
  final String houseName;
  final String? roomNumber;
  final String paymentLabel;
  final Color paymentColor;

  const _TenantHero({
    required this.month,
    required this.firstName,
    required this.houseName,
    required this.roomNumber,
    required this.paymentLabel,
    required this.paymentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlideIn(
      duration: const Duration(milliseconds: 560),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF052E1C), Color(0xFF0A4B30), Color(0xFF0F7A44)],
            stops: [0.0, 0.55, 1.0],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x330F7A44),
              blurRadius: 34,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -46,
              top: -64,
              child: IgnorePointer(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        kLime.withValues(alpha: 0.25),
                        kLime.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: TAmbient(
                art: 'aurora',
                opacity: 0.5,
                size: 440,
                alignment: Alignment.bottomRight,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          month.toUpperCase(),
                          style: AppType.eyebrow.copyWith(
                            color: const Color(0xFFC7F26A),
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const LottieArt('pulse', size: 28),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hi, $firstName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.h1.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      houseName,
                      if (roomNumber != null) 'Room $roomNumber',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(
                      color: const Color(0xFFD7EADF),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Icon(
                            paymentLabel == 'Paid'
                                ? Icons.check_rounded
                                : Icons.schedule_rounded,
                            size: 20,
                            color: paymentColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'RENT THIS MONTH',
                          textAlign: TextAlign.center,
                          style: AppType.eyebrow.copyWith(
                            color: const Color(0xFFB9D7C8),
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          paymentLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: paymentColor,
                            fontFamily: AppType.displayFamily,
                            fontSize: 29,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Payment status for this month',
                          textAlign: TextAlign.center,
                          style: tMeta(color: const Color(0xFFC9E2D5)).copyWith(
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
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

// ==============================================================
// QUICK ACTIONS
// ==============================================================

class _HomeAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      pressedScale: 0.98,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: title,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface, AppColors.surface2],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: (AppColors.dark
                  ? AppColors.border.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9))),
          boxShadow: AppColors.panelShadow,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: TAmbient(
                art: 'drift',
                opacity: 0.14,
                size: 380,
                alignment: Alignment.topRight,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0B4D2F), Color(0xFF16A356)],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, size: 18, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppType.bodyStrong.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================
// SECTIONS
// ==============================================================

class _SectionLabel extends StatelessWidget {
  final String eyebrow;
  final String title;

  const _SectionLabel({required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: AppType.eyebrow.copyWith(fontSize: 9.5, letterSpacing: 1.3),
        ),
        const SizedBox(height: 3),
        Text(title, style: AppType.h3.copyWith(fontSize: 18)),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String time;
  final VoidCallback onTap;

  const _NoticeCard({
    required this.title,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.campaign_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyStrong.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(time, style: AppType.caption),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 17,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _HousematesCard extends StatelessWidget {
  final List<TenantModel> housemates;

  const _HousematesCard({required this.housemates});

  @override
  Widget build(BuildContext context) {
    return TCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (housemates.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.night_shelter_outlined,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You have this room to yourself.',
                    style: AppType.caption,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                for (var i = 0; i < housemates.take(6).length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TAvatar(name: housemates[i].fullName),
                  ),
                if (housemates.length > 6)
                  TPill(
                    text: '+${housemates.length - 6}',
                    tone: TPillTone.neutral,
                  ),
                const Spacer(),
                Text(
                  '${housemates.length + 1} in this room',
                  style: AppType.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
