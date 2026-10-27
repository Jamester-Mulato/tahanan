import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_motion.dart';

/// A touch surface that answers on the very first frame.
///
/// Design rules (borrowed from Telegram's interaction grammar):
///  * Highlight appears instantly on pointer-down, never a slow ripple wave.
///  * Press scales down immediately, then releases with a short, soft settle.
///  * Nothing waits to decide whether a double-tap is coming.
///  * Ordinary taps never vibrate; haptics are reserved for long-press
///    thresholds and explicit actions.
///  * Everything is transform/opacity only, so it stays on the raster fast
///    path and can be interrupted at any moment.
class PressableSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadiusGeometry? borderRadius;
  final Color highlightColor;
  final double pressedScale;
  final bool enabled;
  final String? semanticsLabel;
  final bool semanticButton;
  final bool hapticOnLongPress;

  const PressableSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.highlightColor = const Color(0x0A000000),
    this.pressedScale = AppMotion.pressScale,
    this.enabled = true,
    this.semanticsLabel,
    this.semanticButton = true,
    this.hapticOnLongPress = true,
  });

  @override
  State<PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends State<PressableSurface> {
  bool _down = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setDown(bool value) {
    if (!mounted || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);

    Widget content = widget.child;

    if (_interactive) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                // Instant on press-down; gentle on release.
                opacity: _down ? 1 : 0,
                duration: reduce || _down ? Duration.zero : AppMotion.fast,
                curve: AppMotion.settle,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.highlightColor,
                    borderRadius:
                        widget.borderRadius ?? BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    content = AnimatedScale(
      scale: _interactive && _down ? widget.pressedScale : 1.0,
      duration: reduce
          ? Duration.zero
          : (_down
              ? const Duration(milliseconds: 90)
              : const Duration(milliseconds: 300)),
      curve: _down ? Curves.easeOutCubic : Curves.easeOutBack,
      child: content,
    );

    if (!_interactive) return content;

    return Semantics(
      button: widget.semanticButton,
      label: widget.semanticsLabel,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap == null
            ? null
            : () {
                _setDown(false);
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _setDown(false);
                if (widget.hapticOnLongPress) {
                  HapticFeedback.selectionClick();
                }
                widget.onLongPress!();
              },
        child: content,
      ),
    );
  }
}

/// Cross-fades and scales between icon glyphs so a control changes meaning
/// instead of swapping pictures. Quick enough to feel like a morph.
class MorphIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Duration duration;

  const MorphIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 22,
    this.duration = AppMotion.fast,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Icon(icon, size: size, color: color);
    }
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: Icon(
        icon,
        key: ValueKey<int>(icon.codePoint),
        size: size,
        color: color,
      ),
    );
  }
}
