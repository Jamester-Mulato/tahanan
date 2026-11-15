import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';
import '../widgets/desktop_shell.dart';
import '../widgets/motion.dart';
import '../widgets/refresh_overlay.dart';
import '../widgets/ui.dart';
import 'more_screen.dart';
import 'owner/concerns.dart';
import 'owner/owner_home.dart';
import 'owner/rooms.dart';
import 'owner/tenants.dart';

class OwnerScreen extends StatefulWidget {
  const OwnerScreen({super.key});

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  int _currentIndex = 0;

  static const _items = [
    TahananNavItem(
      icon: AppIcons.homeLine,
      activeIcon: AppIcons.home,
      label: 'Home',
    ),
    TahananNavItem(
      icon: AppIcons.roomLine,
      activeIcon: AppIcons.room,
      label: 'Rooms',
    ),
    TahananNavItem(
      icon: AppIcons.groupLine,
      activeIcon: AppIcons.tenant,
      label: 'Tenants',
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
    OwnerHomeScreen(onNavigateTab: _onTabSelect),
    const RoomsScreen(),
    TenantsScreen(onNavigateTab: _onTabSelect),
    ConcernsScreen(onNavigateTab: _onTabSelect),
    const MoreScreen(isOwner: true),
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
