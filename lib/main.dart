import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'core/app_colors.dart';
import 'core/app_motion.dart';
import 'core/app_theme.dart';
import 'core/server_config.dart';
import 'screens/houses.dart';
import 'screens/login.dart';
import 'screens/owner.dart';
import 'screens/splash_screen.dart';
import 'screens/tenant.dart';
import 'state/app_state.dart';
import 'state/theme_controller.dart';
import 'widgets/idle_session_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.load();

  // Reveal-on-scroll should answer the thumb, not a half-second polling tick.
  VisibilityDetectorController.instance.updateInterval =
      const Duration(milliseconds: 80);

  // Helpful when configuring Google OAuth: the browser console prints the
  // exact origin that must be added to "Authorized JavaScript origins".
  if (kIsWeb) {
    debugPrint('Tahanan web origin: ${Uri.base.origin}');
  }

  // Force immersive sticky mode at the app level
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => AppState()..restore()),
      ],
      child: const TahananApp(),
    ),
  );
}

class TahananApp extends StatelessWidget {
  const TahananApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<ThemeController>().isDark;
    AppColors.dark = dark;
    AppTheme.darkActive = dark;

    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor:
              dark ? const Color(0xFF060B08) : AppColors.background,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              dark ? Brightness.light : Brightness.dark,
        ),
      );
    }

    return MaterialApp(
      title: 'Tahanan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      scrollBehavior: const TahananScrollBehavior(),
      builder: (context, child) {
        // Any route rendered without its own Material/DefaultTextStyle still
        // gets the app's body style instead of Flutter's debug yellow
        // "missing style" underline. The palette itself is theme-aware, so no
        // colour filter is used here.
        return DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium ??
              TextStyle(color: AppColors.text),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Root(),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  static const _minimumSplash = Duration(milliseconds: 3600);

  Timer? _bootTimer;
  bool _bootFinished = false;

  @override
  void initState() {
    super.initState();
    _bootTimer = Timer(_minimumSplash, () {
      if (mounted) setState(() => _bootFinished = true);
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    final showSplash = !_bootFinished || s.loading;

    final Widget child;
    if (showSplash) {
      child = SplashScreen(
        key: const ValueKey('splash'),
        restoreOnly: _bootFinished,
      );
    } else if (!s.loggedIn) {
      child = const LoginScreen(key: ValueKey('login'));
    } else if (s.selected == null) {
      child = const HousesScreen(key: ValueKey('houses'));
    } else if (s.owner) {
      child = const OwnerScreen(key: ValueKey('owner'));
    } else {
      child = const TenantScreen(key: ValueKey('tenant'));
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return IdleSessionGuard(
      enabled: s.loggedIn && !showSplash,
      child: KeyedSubtree(
        key: ValueKey('theme-${AppColors.dark}'),
        child: AnimatedSwitcher(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 460),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (widget, animation) {
            if (reduceMotion) return widget;
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                  child: widget,
                ),
              ),
            );
          },
          child: child,
        ),
      ),
    );
  }
}
