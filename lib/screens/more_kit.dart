import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../core/design_tokens.dart';
import '../core/server_config.dart';
import '../state/app_state.dart';
import '../state/theme_controller.dart';
import '../widgets/app_icons.dart';
import '../widgets/lottie_art.dart';
import '../widgets/premium/premium_kit.dart';
import '../widgets/pressable.dart';
import '../widgets/scroll_reveal.dart';
import '../widgets/tahanan_kit.dart';
import 'owner/home/home_kit.dart';
import '../core/app_colors.dart';

// ==========================================================
// MORE / ACCOUNT REFERENCE KIT
// ==========================================================

class MoreBody extends StatelessWidget {
  final bool isOwner;
  final VoidCallback onSwitchHouse;
  final VoidCallback onAnnouncements;
  final VoidCallback onHelp;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onSignOut;
  final VoidCallback onCopyKey;
  final VoidCallback onChangePassword;

  /// Per-account security trail, available to every owner and tenant.
  final VoidCallback? onSecurityActivity;

  /// Admin-only. Opens the server-address dialog for this device.
  final VoidCallback? onServerAddress;

  const MoreBody({
    super.key,
    required this.isOwner,
    required this.onSwitchHouse,
    required this.onAnnouncements,
    required this.onHelp,
    required this.onPrivacy,
    required this.onTerms,
    required this.onSignOut,
    required this.onCopyKey,
    required this.onChangePassword,
    this.onSecurityActivity,
    this.onServerAddress,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final user = s.user;
    final house = s.selected;
    final displayName = user?.displayName ?? 'Tahanan member';
    final room = isOwner ? null : _tenantRoom(s);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final initial = displayName.trim().isEmpty
        ? 'T'
        : displayName.trim().substring(0, 1).toUpperCase();

    final workspaceSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          eyebrow: 'Workspace',
          title: 'This boarding house',
        ),
        _SettingsGroup(
          children: [
            SettingsTile(
              icon: AppIcons.megaphoneLine,
              title: 'Announcements',
              subtitle: isOwner
                  ? 'Post and manage house notices'
                  : 'Read the latest notices',
              onTap: onAnnouncements,
            ),
            SettingsTile(
              icon: AppIcons.swapLine,
              title: 'Switch boarding house',
              subtitle: 'Move to another property you belong to',
              onTap: onSwitchHouse,
            ),
            SettingsTile(
              icon: AppIcons.keyLine,
              title: 'House access key',
              subtitle: 'Share the key with a new tenant',
              onTap: onCopyKey,
            ),
            SettingsTile(
              icon: AppIcons.lockLine,
              title: 'Change password',
              subtitle: 'Update your password and sign out other sessions',
              onTap: onChangePassword,
            ),
          ],
        ),
      ],
    );

    final accountSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          eyebrow: 'Account',
          title: 'Profile & privacy',
        ),
        _SettingsGroup(
          children: [
            SettingsTile(
              icon: AppIcons.helpLine,
              title: 'Help & FAQ',
              subtitle: 'How rooms, tenants, and rent work',
              onTap: onHelp,
            ),
            SettingsTile(
              icon: AppIcons.shieldLine,
              title: 'Privacy',
              subtitle: 'What Tahanan stores and why',
              onTap: onPrivacy,
            ),
            SettingsTile(
              icon: AppIcons.articleLine,
              title: 'Terms of use',
              subtitle: 'The rules of the house',
              onTap: onTerms,
            ),
          ],
        ),
      ],
    );

    return AuroraBackdrop(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep the settings column readable instead of stretching it
          // across the whole window.
          final extraSide = kIsWeb && constraints.maxWidth > 860
              ? (constraints.maxWidth - 760) / 2
              : 0.0;
          return ListView(
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              HomeStyle.gutter + extraSide,
              MediaQuery.paddingOf(context).top + 14,
              HomeStyle.gutter + extraSide,
              132,
            ),
            children: revealAll([
              MoreHeader(
                name: displayName,
                email: user?.email ?? 'Signed in with Google',
                initial: initial,
                isOwner: isOwner,
              ),
              const SizedBox(height: 14),
              if (house != null)
                HouseHero(
                  house: house,
                  room: room,
                  onSwitch: onSwitchHouse,
                  onCopyKey: onCopyKey,
                )
              else
                _Panel(
                  child: Column(
                    children: [
                      const HomeEmpty(
                        icon: AppIcons.homeLine,
                        title: 'No house selected',
                        message:
                            'Switch to a boarding house to see its details.',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TButton(
                          text: 'Choose a house',
                          icon: AppIcons.swapLine,
                          height: 46,
                          onPressed: onSwitchHouse,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              workspaceSection,
              const SizedBox(height: 18),
              accountSection,
              const SizedBox(height: 18),
              const SectionHeading(
                eyebrow: 'Preferences',
                title: 'How the app behaves',
              ),
              _PreferencesCard(reduceMotion: reduceMotion),
              const SizedBox(height: 18),
              const SectionHeading(
                eyebrow: 'Session',
                title: 'Security',
              ),
              if (onSecurityActivity != null) ...[
                _SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.shieldLine,
                      title: 'Security activity',
                      subtitle: 'Sign-ins and attempts on your account',
                      onTap: onSecurityActivity!,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (user?.isAdmin == true && onServerAddress != null) ...[
                _SettingsGroup(
                  children: [
                    if (onServerAddress != null)
                      SettingsTile(
                        icon: AppIcons.link,
                        title: 'Server address',
                        subtitle: ServerConfig.baseUrl,
                        onTap: onServerAddress!,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LottieArt('shield', size: 44),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Signed in on this device',
                                style: TextStyle(
                                  color: HomeStyle.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Your session is stored in the platform keystore.',
                                style: TextStyle(
                                  color: HomeStyle.inkFaint,
                                  fontSize: 10,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TButton(
                        text: 'Sign out',
                        icon: AppIcons.logout,
                        variant: TButtonVariant.danger,
                        height: 46,
                        onPressed: onSignOut,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _AboutCard(),
              const SizedBox(height: 18),
              const _MoreFooter(),
            ], slide: 0.06),
          );
        },
      ),
    );
  }

  String? _tenantRoom(AppState s) {
    final email = s.user?.email;
    final id = s.user?.id;
    for (final t in s.tenants) {
      if ((id != null && t.userId == id) ||
          (email != null && t.accountEmail == email)) {
        return t.roomNumber;
      }
    }
    return null;
  }
}

// ==========================================================
// HEADER
// ==========================================================

class MoreHeader extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  final bool isOwner;

  const MoreHeader({
    super.key,
    required this.name,
    required this.email,
    required this.initial,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomeStyle.forest, HomeStyle.emerald],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F7A44),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    HomeStyle.lime.withValues(alpha: 0.25),
                    HomeStyle.lime.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: TAmbient(
              art: 'aurora',
              opacity: 0.5,
              size: 400,
              alignment: Alignment.bottomRight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: double.infinity,
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
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      initial,
                      style: AppType.h2.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ACCOUNT & WORKSPACE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HomeStyle.lime.withValues(alpha: 0.9),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  HomeTag(
                    text: isOwner ? 'Owner' : 'Tenant',
                    color: HomeStyle.forest,
                    background: HomeStyle.lime,
                    dot: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// HOUSE HERO
// ==========================================================

class HouseHero extends StatelessWidget {
  final BoardingHouse house;
  final String? room;
  final VoidCallback onSwitch;
  final VoidCallback onCopyKey;

  const HouseHero({
    super.key,
    required this.house,
    required this.room,
    required this.onSwitch,
    required this.onCopyKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06301D), Color(0xFF0A4B30), Color(0xFF0F7A44)],
            stops: [0, 0.58, 1],
          ),
          borderRadius: BorderRadius.circular(HomeStyle.heroRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E06301D),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _MoreAura())),
            ),
            const Positioned.fill(
              child: TAmbient(
                art: 'flow',
                opacity: 0.35,
                size: 340,
                alignment: Alignment.bottomRight,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      AppIcons.homeLine,
                      size: 22,
                      color: HomeStyle.lime,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    house.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (house.domain.isNotEmpty) '@${house.domain}',
                      if (room != null) 'Room $room',
                      house.role,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC9E2D5),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.keyLine,
                          size: 15,
                          color: HomeStyle.lime,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            house.joinKey.isEmpty
                                ? 'No key yet'
                                : house.joinKey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        PressableSurface(
                          onTap: onCopyKey,
                          borderRadius: BorderRadius.circular(8),
                          pressedScale: 0.94,
                          highlightColor: Colors.black.withValues(alpha: 0.08),
                          semanticsLabel: 'Copy house key',
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              AppIcons.copy,
                              size: 15,
                              color: HomeStyle.lime,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroButton(
                          icon: AppIcons.swapLine,
                          label: 'Switch house',
                          onTap: onSwitch,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeroButton(
                          icon: AppIcons.key,
                          label: 'Copy key',
                          onTap: onCopyKey,
                        ),
                      ),
                    ],
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

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      pressedScale: 0.97,
      highlightColor: Colors.white.withValues(alpha: 0.08),
      semanticsLabel: label,
      child: Container(
        width: double.infinity,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreAura extends CustomPainter {
  const _MoreAura();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);
    final center = Offset(size.width * 0.94, -size.height * 0.08);
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(center, 38.0 * i, ring);
    }

    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    final path = Path()
      ..moveTo(0, size.height * 0.82)
      ..lineTo(size.width * 0.60, 0)
      ..lineTo(size.width * 0.84, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, sheen);
  }

  @override
  bool shouldRepaint(covariant _MoreAura old) => false;
}

// ==========================================================
// SETTINGS
// ==========================================================

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surface2],
        ),
        borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
        border: Border.all(
            color: AppColors.dark
                ? AppColors.border.withValues(alpha: 0.75)
                : (AppColors.dark
                    ? AppColors.border.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9))),
        boxShadow: HomeStyle.lift,
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 58,
                color: HomeStyle.hairline,
              ),
          ],
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      pressedScale: 0.99,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HomeStyle.forest, HomeStyle.emerald],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: HomeStyle.emerald.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeStyle.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeStyle.inkFaint,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.chevron,
              size: 18,
              color: HomeStyle.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// PREFERENCES
// ==========================================================

class _PreferencesCard extends StatelessWidget {
  final bool reduceMotion;

  const _PreferencesCard({required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          _PreferenceRow(
            icon: AppIcons.sparkle,
            title: 'Motion',
            value: reduceMotion ? 'Reduced' : 'Full',
            tone: reduceMotion ? HomeStyle.inkSoft : HomeStyle.emerald,
          ),
          Divider(height: 18, color: HomeStyle.hairline),
          _ThemePreference(
            mode: context.watch<ThemeController>().mode,
            onChanged: context.read<ThemeController>().setMode,
          ),
          Divider(height: 18, color: HomeStyle.hairline),
          _PreferenceRow(
            icon: AppIcons.shieldLine,
            title: 'Session storage',
            value: 'Keystore',
            tone: HomeStyle.emerald,
          ),
        ],
      ),
    );
  }
}

class _ThemePreference extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemePreference({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: HomeStyle.mint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.brightness_6_outlined,
            size: 15,
            color: HomeStyle.emerald,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Theme',
            style: TextStyle(
              color: HomeStyle.inkSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _ThemeChip(
          label: 'Light',
          selected: mode == ThemeMode.light,
          onTap: () => onChanged(ThemeMode.light),
        ),
        const SizedBox(width: 6),
        _ThemeChip(
          label: 'Dark',
          selected: mode == ThemeMode.dark,
          onTap: () => onChanged(ThemeMode.dark),
        ),
        const SizedBox(width: 6),
        _ThemeChip(
          label: 'System',
          selected: mode == ThemeMode.system,
          onTap: () => onChanged(ThemeMode.system),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      pressedScale: 0.97,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      child: AnimatedContainer(
        duration: AppTime.fast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? HomeStyle.mintDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? HomeStyle.emerald : HomeStyle.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? HomeStyle.emerald : HomeStyle.inkFaint,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color tone;

  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: HomeStyle.mint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: HomeStyle.emerald),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: HomeStyle.inkSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: tone,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ==========================================================
// ABOUT / FOOTER / PANEL
// ==========================================================

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: HomeStyle.mint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  AppIcons.homeLine,
                  size: 17,
                  color: HomeStyle.emerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tahanan',
                      style: TextStyle(
                        color: HomeStyle.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Your boarding house, in order.',
                      style: TextStyle(
                        color: HomeStyle.inkFaint,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              HomeTag(
                text: 'v1.0.0',
                color: HomeStyle.inkSoft,
                background: HomeStyle.mint,
                dot: false,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'A quiet command center for rooms, tenants, rent, notices, and the small things that keep a house running.',
            style: TextStyle(
              color: HomeStyle.inkSoft,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surface2],
        ),
        borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
        border: Border.all(
            color: AppColors.dark
                ? AppColors.border.withValues(alpha: 0.75)
                : (AppColors.dark
                    ? AppColors.border.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9))),
        boxShadow: HomeStyle.lift,
      ),
      child: child,
    );
  }
}

class _MoreFooter extends StatelessWidget {
  const _MoreFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(AppIcons.homeLine, size: 18, color: HomeStyle.inkFaint),
        SizedBox(height: 6),
        Text(
          'Tahanan · made for the house you manage',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HomeStyle.inkFaint,
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
