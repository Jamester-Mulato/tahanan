import 'package:flutter/material.dart';

import '../core/app_colors.dart';

import '../core/idle_motion_spec.dart';
import '../widgets/app_icons.dart';
import '../widgets/idle_motion.dart';
import '../widgets/lottie_art.dart';

Color get _canvas => AppColors.background;
Color get _ink => AppColors.text;
Color get _muted => AppColors.textSecondary;
Color get _green => AppColors.primary;
Color get _lime => AppColors.lime;

/// The simple "Restoring your keys" hand-off.
///
/// A key mark, one status line, and a thin progress bar.
class KeyRestoreScreen extends StatefulWidget {
  final MotionCatalog? catalog;
  final Duration duration;

  const KeyRestoreScreen({
    super.key,
    this.catalog,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<KeyRestoreScreen> createState() => _KeyRestoreScreenState();
}

class _KeyRestoreScreenState extends State<KeyRestoreScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  late final MotionCatalog _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalog ?? MotionCatalog.fallback();
    _progress = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {});
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  bool get _complete => _progress.isCompleted;

  String get _status {
    if (_complete) return 'Opening your boarding house…';
    if (_progress.value < 0.34) return 'Checking your session';
    if (_progress.value < 0.76) return 'Bringing back your keys';
    return 'Securing the connection';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SoftGlow(),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 172,
                    height: 172,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!_complete) const LottieArt('pulse', size: 172),
                        if (_complete)
                          const LottieArt('check', size: 132)
                        else
                          IdleMotion(
                            motionKey: 'restore.key.emblem',
                            catalog: _catalog,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 320),
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F7EF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFCBEBD8),
                                ),
                              ),
                              child: Icon(
                                AppIcons.keyLine,
                                size: 32,
                                color: _green,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: Text(
                      _complete ? 'Keys restored' : 'Restoring your keys',
                      key: ValueKey(_complete),
                      style: TextStyle(
                        color: _ink,
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) {
                      // One label only. Cross-fading two status strings on top
                      // of each other looked like stray underlines.
                      return Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 210,
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: _complete
                              ? LinearProgressIndicator(
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFFDDF0E5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _green,
                                  ),
                                )
                              : LinearProgressIndicator(
                                  value: _progress.value,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFFDDF0E5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _green,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) {
                      return Text(
                        '${(_progress.value * 100).round()}%',
                        style: TextStyle(
                          color: _green.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 42,
            child: Text(
              'SECURED WITH SCRYPT · POSTGRESQL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted.withValues(alpha: 0.55),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
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
              _lime.withValues(alpha: 0.14),
              _canvas.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
