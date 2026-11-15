import 'package:flutter/material.dart';
import '../routing/liquid_page_route.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';
import '../widgets/desktop_shell.dart';
import '../widgets/motion.dart';
import '../widgets/refresh_overlay.dart';
import '../widgets/tahanan_kit.dart';
import '../widgets/ui.dart';
import 'more_screen.dart';
import 'owner/announcements.dart';
import 'tenant/report_concern.dart';
import 'tenant/tenant_home.dart';
import '../core/app_colors.dart';

class TenantScreen extends StatefulWidget {
  const TenantScreen({super.key});

  @override
  State<TenantScreen> createState() => _TenantScreenState();
}

class _TenantScreenState extends State<TenantScreen> {
  int _currentIndex = 0;

  static const _items = [
    TahananNavItem(
      icon: AppIcons.homeLine,
      activeIcon: AppIcons.home,
      label: 'Home',
    ),
    TahananNavItem(
      icon: AppIcons.megaphoneLine,
      activeIcon: AppIcons.announcement,
      label: 'Notices',
    ),
    TahananNavItem(
      icon: AppIcons.chatLine,
      activeIcon: AppIcons.concern,
      label: 'Concerns',
    ),
    TahananNavItem(
      icon: AppIcons.moreHorizontal,
      label: 'More',
    ),
  ];

  // Hoisted so tab switches never rebuild the tab pages themselves; the
  // IndexedStack inside AnimatedTabStage preserves each tab's state.
  late final List<Widget> _screens = [
    TenantHomeScreen(onNavigateTab: _onTabSelect),
    const AnnouncementsScreen(isOwner: false),
    const _TenantConcernsTab(),
    const MoreScreen(isOwner: false),
  ];

  void _onTabSelect(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final stage = Stack(
      children: [
        AnimatedTabStage(
          index: _currentIndex,
          children: _screens,
        ),
        RefreshOverlay(
          visible: context.watch<AppState>().loading,
        ),
      ],
    );

    if (isDesktopWeb(context)) {
      return Scaffold(
        body: TahananBackground(
          child: DesktopShell(
            currentIndex: _currentIndex,
            onTap: _onTabSelect,
            items: _items,
            child: stage,
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: TahananBackground(child: stage),
      bottomNavigationBar: TahananBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelect,
        items: _items,
      ),
    );
  }
}

class _TenantConcernsTab extends StatelessWidget {
  const _TenantConcernsTab();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final concerns = s.concerns;
    final open = concerns
        .where((c) => c.status.toLowerCase() != ConcernModel.statusResolved)
        .length;
    final resolved = concerns.length - open;

    return TahananBackground(
      child: RefreshIndicator(
        color: kPrimary,
        backgroundColor: AppColors.surface,
        onRefresh: s.refreshHouse,
        child: ListView(
          padding: tScreenPadding(context),
          children: [
            TLightHeader(
              icon: AppIcons.chatLine,
              eyebrow: 'My reports',
              title: 'Concerns',
              subtitle: 'Track what you have reported.',
              stats: [
                TStatData('${concerns.length}', 'Reports'),
                TStatData('$open', 'Open'),
                TStatData('$resolved', 'Resolved'),
              ],
            ),
            const SizedBox(height: 14),
            TButton(
              text: 'Report a concern',
              icon: AppIcons.forward,
              onPressed: () => pushLiquidPage(
                context,
                const ReportConcernScreen(),
              ),
            ),
            const SizedBox(height: 14),
            if (concerns.isEmpty)
              TCard(
                child: TEmpty(
                  icon: AppIcons.checkLine,
                  title: 'No concerns reported',
                  message:
                      'Need a repair or have an issue? Report it to your landlord.',
                ),
              )
            else
              ...concerns.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TConcernCard(
                    subject: c.subject,
                    meta: 'Room ${c.roomNumber ?? '—'} · ${tWhen(c.createdAt)}',
                    icon: _tenantCategoryIcon(c.category),
                    statusText:
                        c.status.toLowerCase() == ConcernModel.statusResolved
                            ? 'Resolved'
                            : 'Pending',
                    statusTone:
                        c.status.toLowerCase() == ConcernModel.statusResolved
                            ? TPillTone.ok
                            : TPillTone.pending,
                    rating: c.rating,
                    onTap: () => TenantConcernDetailSheet.show(context, c),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

IconData _tenantCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'utility':
      return AppIcons.boltLine;
    case 'cleanliness':
      return AppIcons.cleaningLine;
    case 'security':
      return AppIcons.shieldLine;
    case 'noise':
      return AppIcons.volumeLine;
    case 'other':
      return AppIcons.moreHorizontal;
    default:
      return AppIcons.buildLine;
  }
}
