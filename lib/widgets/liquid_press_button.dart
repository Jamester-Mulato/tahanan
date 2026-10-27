import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';

// ==========================================================
// LIQUID PRESS BUTTON
// ==========================================================
//
// Ported from FareFair's elastic CTA. The motion budget is intentionally
// small: one scale controller, one sheen controller, both animating
// transform/opacity only. No blur, no shadow lerp per frame.

/// Primary call-to-action with an elastic squash-and-release, a liquid
/// sheen sweep and a radial press bloom.
///
/// Used for the main action of a flow (sign in, create house, continue)
/// while the cheaper [PrimaryButton] remains for secondary actions.
class LiquidPressButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? glowColor;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  /// Fire one sheen sweep on mount — great when a form becomes valid.
  final bool autoSheen;

  /// Optional icon shown before [child].
  final IconData? icon;

  LiquidPressButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor = const Color(0xFF0F7A44),
    this.foregroundColor = Colors.white,
    this.glowColor,
    this.height = 54,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.autoSheen = false,
    this.icon,
  });

  @override
  State<LiquidPressButton> createState() => _LiquidPressButtonState();
}

class _LiquidPressButtonState extends State<LiquidPressButton>
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 320),
  );

  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoSheen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sheen.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _sheen.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.onPressed == null) return;
    HapticFeedback.selectionClick();
    _press.forward();
  }

  void _up() {
    if (widget.onPressed == null) return;
    _press.reverse();
  }

  void _tap() {
    if (widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    _sheen.forward(from: 0);
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Pre-baked press shadow: no per-frame blur/offset lerp. Depth stays
    // static while the press reads through the elastic scale plus an
    // opacity-only bloom, so the raster cache survives the animation.
    const pressedShadow = [
      BoxShadow(
        color: Color(0x1F0B1F14),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
      BoxShadow(
        color: Color(0x0A0B1F14),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ];

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: reduceMotion ? null : (_) => _down(),
        onTapUp: reduceMotion ? null : (_) => _up(),
        onTapCancel: reduceMotion ? null : _up,
        onTap: _tap,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_press.value);
            final scaleX = 1 - 0.030 * t;
            final scaleY = 1 - 0.060 * t;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
              child: Opacity(
                opacity: widget.onPressed == null ? 0.55 : 1,
                child: Container(
                  height: widget.height,
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(widget.backgroundColor, Colors.white, 0.12)!,
                        widget.backgroundColor,
                        Color.lerp(widget.backgroundColor, Colors.black, 0.10)!,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    boxShadow: pressedShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: Stack(
                      children: [
                        // Radial press bloom (opacity-only layer).
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.35 + 0.65 * t,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(-0.2, -0.6),
                                    radius: 1.1,
                                    colors: [
                                      Color(0x33FFFFFF),
                                      Color(0x00FFFFFF),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Sheen sweep.
                        if (!reduceMotion)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _sheen,
                              builder: (context, _) {
                                if (_sheen.value == 0 || _sheen.value == 1) {
                                  return const SizedBox.shrink();
                                }
                                final dx = -1.6 + 3.2 * _sheen.value;
                                return FractionalTranslation(
                                  translation: Offset(dx, 0),
                                  child: Transform.rotate(
                                    angle: math.pi / 7,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withValues(alpha: 0),
                                            Colors.white
                                                .withValues(alpha: 0.22),
                                            Colors.white.withValues(alpha: 0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  color: widget.foregroundColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                              ],
                              DefaultTextStyle.merge(
                                style: TextStyle(
                                  color: widget.foregroundColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                                child: widget.child,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A quieter secondary action: tinted background, hairline edge, same
/// elastic press language but no sheen sweep.
class LiquidQuietButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final Color color;
  final double height;

  LiquidQuietButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.color = const Color(0xFF0F7A44),
    this.height = 48,
  });

  @override
  State<LiquidQuietButton> createState() => _LiquidQuietButtonState();
}

class _LiquidQuietButtonState extends State<LiquidQuietButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: reduceMotion ? null : (_) => _press.forward(),
      onTapUp: reduceMotion ? null : (_) => _press.reverse(),
      onTapCancel: reduceMotion ? null : () => _press.reverse(),
      onTap: widget.onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onPressed!();
            },
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_press.value);
          return Transform.scale(
            scale: 1 - 0.035 * t,
            child: child,
          );
        },
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.color.withValues(alpha: 0.10),
                widget.color.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: widget.color, size: 17),
                const SizedBox(width: 7),
              ],
              DefaultTextStyle.merge(
                style: TextStyle(
                  color: widget.color ?? AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circular icon action with the same elastic language — used in app bars
/// and floating decks.
class LiquidIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? background;
  final double size;
  final String? tooltip;

  LiquidIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.background,
    this.size = AppColors.tapTargetMin,
    this.tooltip,
  });

  @override
  State<LiquidIconButton> createState() => _LiquidIconButtonState();
}

class _LiquidIconButtonState extends State<LiquidIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: widget.onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onPressed!();
            },
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_press.value);
          return Transform.scale(scale: 1 - 0.08 * t, child: child);
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.background ?? AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: AppColors.panelShadow,
          ),
          child: Icon(
            widget.icon,
            color: widget.color ?? AppColors.text,
            size: widget.size * 0.45,
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
