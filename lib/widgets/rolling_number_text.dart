import 'package:flutter/material.dart';

import '../core/app_colors.dart';

// ==========================================================
// ROLLING NUMBER TEXT
// ==========================================================
//
// A telemetry readout that rolls between values with a slide-and-fade
// cross-fade. Used for bed counts, occupancy percentages and rent totals so
// changing data feels alive instead of snapping.
//
// Implementation notes:
//  * Only opacity + translate are animated.
//  * The outgoing value is kept for the duration of the settle so there is
//    never a blank frame — important on 60Hz mid-range panels.

class RollingNumberText extends StatefulWidget {
  final String value;
  final TextStyle style;

  /// How long each change takes to settle.
  final Duration duration;

  /// Direction the new value travels in from (the old one exits opposite).
  final Offset slideOffset;

  final Alignment alignment;

  /// Optional prefix rendered before the rolling value, matching [style].
  final String? prefix;

  /// Optional suffix rendered after the rolling value, matching [style].
  final String? suffix;

  const RollingNumberText({
    super.key,
    required this.value,
    required this.style,
    this.duration = AppColors.stateAnim,
    this.slideOffset = const Offset(0, 0.6),
    this.alignment = Alignment.center,
    this.prefix,
    this.suffix,
  });

  @override
  State<RollingNumberText> createState() => _RollingNumberTextState();
}

class _RollingNumberTextState extends State<RollingNumberText> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant RollingNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _index++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return Text(
        '${widget.prefix ?? ''}${widget.value}${widget.suffix ?? ''}',
        style: widget.style,
        textAlign: _textAlign,
      );
    }

    final enter = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic));

    final exit = Tween<Offset>(
      begin: Offset.zero,
      end: -widget.slideOffset,
    ).chain(CurveTween(curve: Curves.easeInCubic));

    return ClipRect(
      child: AnimatedSwitcher(
        duration: widget.duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncoming = (child.key as ValueKey<int>?)?.value == _index;
          final offset = isIncoming ? enter : exit;
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: isIncoming
                  ? const Interval(0.15, 1.0)
                  : const Interval(0.0, 0.65),
            ),
            child: SlideTransition(
                position: animation.drive(offset), child: child),
          );
        },
        layoutBuilder: (current, previous) => Stack(
          alignment: widget.alignment,
          children: [
            ...previous,
            if (current != null) current,
          ],
        ),
        child: Text(
          '${widget.prefix ?? ''}${widget.value}${widget.suffix ?? ''}',
          key: ValueKey<int>(_index),
          style: widget.style,
          textAlign: _textAlign,
        ),
      ),
    );
  }

  TextAlign get _textAlign => switch (widget.alignment) {
        Alignment.centerLeft => TextAlign.left,
        Alignment.centerRight => TextAlign.right,
        _ => TextAlign.center,
      };
}

/// A compact stat block with a rolling value, a label and an optional icon.
/// The readout is intentionally quiet: no card, no border, just a value that
/// lives inside a parent surface.
class RollingStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color color;
  final TextStyle? valueStyle;
  final CrossAxisAlignment alignment;

  RollingStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = const Color(0xFF0F7A44),
    this.valueStyle,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            RollingNumberText(
              value: value,
              style: valueStyle ??
                  TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
