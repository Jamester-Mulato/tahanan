import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/design_tokens.dart';
import '../models/models.dart';
import '../routing/liquid_page_route.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';
import '../widgets/lottie_art.dart';
import '../widgets/pressable.dart';
import '../widgets/scroll_reveal.dart';
import '../widgets/heavy_motion.dart';
import '../widgets/refresh_overlay.dart';
import '../widgets/tahanan_kit.dart';
import '../widgets/ui.dart';
import 'create_boarding_house.dart';
import 'admin/security_dashboard.dart';

class HousesScreen extends StatelessWidget {
  const HousesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final user = s.user;
    final firstName = user?.displayName.split(' ').first ?? 'there';
    final ownerCount =
        s.houses.where((h) => h.role.toLowerCase() == 'owner').length;
    final tenantCount = s.houses.length - ownerCount;
    final topInset = MediaQuery.paddingOf(context).top + 16;

    return Scaffold(
      body: TahananBackground(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = kIsWeb && constraints.maxWidth >= 1000;
                final side = kIsWeb && constraints.maxWidth > 1200
                    ? (constraints.maxWidth - 1100) / 2
                    : 0.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  child: RefreshIndicator(
                    color: kPrimary,
                    backgroundColor: AppColors.surface,
                    onRefresh: s.loadMine,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                              kGutter, topInset, kGutter, 0),
                          sliver: SliverToBoxAdapter(
                            child: ScrollReveal(
                              index: 0,
                              child: _HousesHero(
                                firstName: firstName,
                                total: s.houses.length,
                                ownerCount: ownerCount,
                                tenantCount: tenantCount,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                              kGutter, 14, kGutter, 0),
                          sliver: SliverToBoxAdapter(
                            child: ScrollReveal(
                              index: 1,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _QuickAction(
                                      icon: AppIcons.addLine,
                                      title: 'Create house',
                                      subtitle: 'Start a new property',
                                      onTap: () => pushLiquidPage(
                                        context,
                                        const CreateBoardingHouseScreen(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _QuickAction(
                                      icon: AppIcons.keyLine,
                                      title: 'Join with key',
                                      subtitle: 'Enter an owner key',
                                      onTap: () => _showJoinSheet(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (s.houses.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                                kGutter, 14, kGutter, 0),
                            sliver: SliverToBoxAdapter(
                              child: ScrollReveal(
                                index: 2,
                                child: _PortfolioCard(
                                  total: s.houses.length,
                                  ownerCount: ownerCount,
                                  tenantCount: tenantCount,
                                ),
                              ),
                            ),
                          ),
                        if (s.houses.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                                kGutter, 22, kGutter, 10),
                            sliver: SliverToBoxAdapter(
                              child: ScrollReveal(
                                index: 3,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'PROPERTIES',
                                            style: tEyebrow().copyWith(
                                              color: kPrimary,
                                              fontSize: 9.5,
                                              letterSpacing: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Your boarding houses',
                                            style: tSectionTitle().copyWith(
                                              fontSize: 20,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${s.houses.length} total',
                                      style: tMeta(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (s.removedHouses.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                                kGutter, 14, kGutter, 0),
                            sliver: SliverList.builder(
                              itemCount: s.removedHouses.length,
                              itemBuilder: (context, i) {
                                final rm = s.removedHouses[i];
                                return RepaintBoundary(
                                  key:
                                      ValueKey('removed-${rm.boardingHouseId}'),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ScrollReveal(
                                      index: 4 + i,
                                      child: HoverTilt(
                                        child: _RemovedHouseCard(
                                          house: rm,
                                          onDismiss: () => s.dismissRemoval(
                                              rm.boardingHouseId),
                                          onRejoin: () =>
                                              _showJoinSheet(context),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (s.houses.isEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                                kGutter, 14, kGutter, 0),
                            sliver: SliverToBoxAdapter(
                              child: ScrollReveal(
                                index: 4,
                                child: TCard(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      const LottieArt('empty', size: 150),
                                      const SizedBox(height: 6),
                                      Text(
                                        'No boarding houses yet',
                                        textAlign: TextAlign.center,
                                        style: tSectionTitle()
                                            .copyWith(fontSize: 18),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Create a property or join one with a house key. '
                                        'Everything stays under your account.',
                                        textAlign: TextAlign.center,
                                        style: tMeta(),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: Magnetic(
                                          child: TButton(
                                            text: 'Create boarding house',
                                            icon: AppIcons.forward,
                                            onPressed: () => pushLiquidPage(
                                              context,
                                              const CreateBoardingHouseScreen(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                                kGutter, 0, kGutter, 0),
                            sliver: wide
                                ? SliverGrid.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisExtent: 212,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: s.houses.length,
                                    itemBuilder: (context, i) {
                                      final h = s.houses[i];
                                      return RepaintBoundary(
                                        key: ValueKey('house-${h.id}'),
                                        child: ScrollReveal(
                                          index: 4 + i,
                                          child: HoverTilt(
                                            child:
                                                _HouseCard(house: h, index: i),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : SliverList.builder(
                                    itemCount: s.houses.length,
                                    itemBuilder: (context, i) {
                                      final h = s.houses[i];
                                      return RepaintBoundary(
                                        key: ValueKey('house-${h.id}'),
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: ScrollReveal(
                                            index: 4 + i,
                                            child: HoverTilt(
                                              child: _HouseCard(
                                                  house: h, index: i),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                              kGutter, 16, kGutter, 30),
                          sliver: SliverToBoxAdapter(
                            child: ScrollReveal(
                              index: 8,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (s.user?.isAdmin == true)
                                      TextButton.icon(
                                        onPressed: () => pushLiquidPage(
                                          context,
                                          const AdminSecurityScreen(),
                                        ),
                                        icon: Icon(
                                          AppIcons.shieldLine,
                                          color: kPrimary,
                                          size: 17,
                                        ),
                                        label: Text(
                                          'Security monitoring',
                                          style: TextStyle(
                                            color: kPrimary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    TextButton.icon(
                                      onPressed: () => s.signOut(),
                                      icon: Icon(
                                        AppIcons.logout,
                                        color: kInkSoft,
                                        size: 17,
                                      ),
                                      label: Text(
                                        'Sign out',
                                        style: TextStyle(
                                          color: kInkSoft,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            RefreshOverlay(visible: s.loading),
          ],
        ),
      ),
    );
  }

  void _showJoinSheet(BuildContext context) {
    final keyCtrl = TextEditingController();
    bool joining = false;
    String? error;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppTheme.scrim(AppColors.text.withValues(alpha: 0.38)),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // The sheet keeps its natural height; the keyboard only lifts it,
            // so the last line still sits just above the keyboard.
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x2B0B1F14),
                      blurRadius: 34,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    22,
                    20,
                    24 + MediaQuery.paddingOf(sheetContext).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Join with key',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 24,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.9,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ask your owner for the house key, then enter it here.',
                        style: tMeta(),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: keyCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'House key',
                          hintText: 'GHBV-8X7K-2P9M',
                          prefixIcon: Icon(
                            AppIcons.keyLine,
                            color: kInkMuted,
                            size: 19,
                          ),
                        ),
                        onChanged: (_) {
                          if (error != null) {
                            setSheetState(() => error = null);
                          }
                        },
                        onSubmitted: (_) {
                          if (!joining) {
                            // The button below owns submission; this keeps
                            // the keyboard action feeling immediate.
                          }
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        ShakeOnError(
                          trigger: error,
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: kDanger,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Magnetic(
                        child: TButton(
                          text: 'Join house',
                          loading: joining,
                          onPressed: joining
                              ? null
                              : () async {
                                  final key = keyCtrl.text.trim();
                                  if (key.isEmpty) {
                                    setSheetState(
                                      () =>
                                          error = 'Enter the house key first.',
                                    );
                                    return;
                                  }
                                  setSheetState(() {
                                    joining = true;
                                    error = null;
                                  });
                                  try {
                                    await context
                                        .read<AppState>()
                                        .joinHouse(key);
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    if (context.mounted) {
                                      showTSnack(
                                        context,
                                        'Joined boarding house successfully',
                                      );
                                    }
                                  } catch (_) {
                                    setSheetState(() {
                                      joining = false;
                                      error = 'That key does not look right. '
                                          'Check it and try again.';
                                    });
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The key is usually shared by the owner in the '
                        'boarding house profile.',
                        textAlign: TextAlign.center,
                        style: tMeta(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(keyCtrl.dispose);
  }
}

class _HousesHero extends StatelessWidget {
  final String firstName;
  final int total;
  final int ownerCount;
  final int tenantCount;

  const _HousesHero({
    required this.firstName,
    required this.total,
    required this.ownerCount,
    required this.tenantCount,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Container(
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
            right: -50,
            top: -70,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kLime.withValues(alpha: 0.26),
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
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.4,
                    ),
                  ),
                  child: Text(
                    firstName.isEmpty
                        ? 'T'
                        : firstName.substring(0, 1).toUpperCase(),
                    style: AppType.h2.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  greeting.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFC7F26A),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppType.h1.copyWith(
                    color: Colors.white,
                    fontSize: 27,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kLime,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$total ${total == 1 ? 'house' : 'houses'}',
                    style: const TextStyle(
                      color: Color(0xFF0A3D26),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pick a boarding house and keep the day in order.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD7EADF),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      _HeroMetric(value: '$total', label: 'Houses'),
                      _HeroRule(),
                      _HeroMetric(value: '$ownerCount', label: 'As owner'),
                      _HeroRule(),
                      _HeroMetric(value: '$tenantCount', label: 'As tenant'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String value;
  final String label;

  const _HeroMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB9D7C8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroRule extends StatelessWidget {
  const _HeroRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
            const Positioned.fill(
              child: TAmbient(
                art: 'drift',
                opacity: 0.13,
                size: 360,
                alignment: Alignment.topRight,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0B4D2F), Color(0xFF16A356)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimary.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppType.h3.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: tMeta().copyWith(fontSize: 10.5),
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

class _PortfolioCard extends StatelessWidget {
  final int total;
  final int ownerCount;
  final int tenantCount;

  const _PortfolioCard({
    required this.total,
    required this.ownerCount,
    required this.tenantCount,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : ownerCount / total;
    return TCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PORTFOLIO MIX',
                      style: tEyebrow().copyWith(
                        color: kPrimary,
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'How you belong',
                      style: tSectionTitle().copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
              Text('${(ratio * 100).round()}% owner', style: tMeta()),
            ],
          ),
          const SizedBox(height: 12),
          TProgress(value: ratio),
          const SizedBox(height: 12),
          Row(
            children: [
              _LegendDot(color: kPrimary, label: 'Owner · $ownerCount'),
              const SizedBox(width: 14),
              _LegendDot(
                  color: const Color(0xFF38BDF8),
                  label: 'Tenant · $tenantCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: tMeta().copyWith(fontSize: 10.5)),
      ],
    );
  }
}

class _HouseCard extends StatelessWidget {
  final BoardingHouse house;
  final int index;

  const _HouseCard({required this.house, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final isOwner = house.role.toLowerCase() == 'owner';
    final user = context.read<AppState>().user;
    final ownerName = isOwner
        ? (user?.displayName.isNotEmpty == true ? user!.displayName : 'You')
        : (house.ownerName.isNotEmpty ? house.ownerName : 'Landlord');
    final domain = house.domain.isNotEmpty ? '@${house.domain}' : '';

    return TCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.read<AppState>().selectHouse(house),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            margin: const EdgeInsets.only(bottom: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: isOwner
                    ? const [Color(0xFF0B4D2F), Color(0xFF16A356)]
                    : const [Color(0xFF0369A1), Color(0xFF38BDF8)],
              ),
            ),
          ),
          Row(
            children: [
              Drift(
                amplitude: 1.6,
                child: TIconSquare(icon: AppIcons.homeLine),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      house.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tCardTitle(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      domain.isEmpty ? ownerName : '$ownerName · $domain',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tMeta(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TPill(
                text: isOwner ? 'Owner' : 'Tenant',
                tone: isOwner ? TPillTone.ok : TPillTone.info,
              ),
            ],
          ),
          if (house.joinKey.isNotEmpty)
            TKeyStrip(
              keyText: house.joinKey,
              onCopy: () {
                HapticFeedback.selectionClick();
                Clipboard.setData(ClipboardData(text: house.joinKey));
                showTSnack(
                  context,
                  'House key copied',
                  icon: AppIcons.keyLine,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RemovedHouseCard extends StatelessWidget {
  final RemovedBoardingHouse house;
  final VoidCallback onDismiss;
  final VoidCallback onRejoin;

  const _RemovedHouseCard({
    required this.house,
    required this.onDismiss,
    required this.onRejoin,
  });

  @override
  Widget build(BuildContext context) {
    return TCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.alert, color: kDanger, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Removed from ${house.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kDanger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your landlord removed you from this boarding house. '
            'You can rejoin with the house key.',
            style: tMeta(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onRejoin,
                child: const Text('Rejoin'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
