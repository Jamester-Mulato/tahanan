import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

import '../core/idle_motion_spec.dart';
import '../widgets/idle_motion.dart';
import '../widgets/lottie_art.dart';
import 'key_restore_screen.dart';

Color get _canvas => AppColors.background;
Color get _ink => AppColors.text;
Color get _muted => AppColors.textSecondary;
Color get _green => AppColors.primary;
Color get _lime => AppColors.lime;

/// A quiet, Emergency-Chat-style cold start.
///
/// One mark, one name, one line, and a small idle loader.
class SplashScreen extends StatefulWidget {
  final MotionCatalog? catalog;

  /// Shown when the app is already signed in and is re-fetching: skip the
  /// intro and go straight to the restore progress.
  final bool restoreOnly;

  const SplashScreen({super.key, this.catalog, this.restoreOnly = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Future<MotionCatalog> _catalogFuture;
  Timer? _handoff;
  Timer? _reveal;
  bool _restoring = false;
  bool _restoreVisible = false;

  @override
  void initState() {
    super.initState();
    _catalogFuture = widget.catalog != null
        ? Future.value(widget.catalog!)
        : MotionCatalog.load();

    if (widget.restoreOnly) {
      _restoring = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _restoreVisible = true);
      });
      return;
    }

    _handoff = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      setState(() => _restoring = true);
      _reveal = Timer(const Duration(milliseconds: 230), () {
        if (mounted) setState(() => _restoreVisible = true);
      });
    });
  }

  @override
  void dispose() {
    _handoff?.cancel();
    _reveal?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      body: FutureBuilder<MotionCatalog>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          final catalog = snapshot.data ?? MotionCatalog.fallback();

          // Fade the intro away first, then fade the restore view in. A plain
          // cross-fade made both layouts overlap and look like stray lines.
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                opacity: _restoring ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: IgnorePointer(
                  ignoring: _restoring,
                  child: _Intro(
                    key: const ValueKey('intro'),
                    catalog: catalog,
                  ),
                ),
              ),
              if (_restoring)
                AnimatedOpacity(
                  opacity: _restoreVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: KeyRestoreScreen(
                    key: const ValueKey('restore'),
                    catalog: catalog,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final MotionCatalog catalog;

  const _Intro({super.key, required this.catalog});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _SoftGlow(),
        SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 196,
                  height: 196,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const LottieArt('pulse', size: 196),
                      IdleMotion(
                        motionKey: 'splash.logo',
                        catalog: catalog,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: _green.withValues(alpha: 0.20),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/images/tahanan_logo.png',
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                IdleMotion(
                  motionKey: 'splash.wordmark',
                  catalog: catalog,
                  child: Text(
                    'Tahanan',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                IdleMotion(
                  motionKey: 'splash.tagline',
                  catalog: catalog,
                  child: Text(
                    'Your boarding house, in order.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Center(child: LottieArt('dots', size: 96)),
        ),
      ],
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 0.9,
            colors: [
              _lime.withValues(alpha: 0.16),
              _canvas.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
