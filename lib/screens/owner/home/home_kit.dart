import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_motion.dart';
import '../../../core/design_tokens.dart';
import '../../../models/models.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/lottie_art.dart';
import '../../../widgets/pressable.dart';
import '../../../widgets/tahanan_kit.dart';

// ==========================================================
// TAHANAN HOME KIT
// ==========================================================
//
// The reference visual language for every dashboard in the app. These
// widgets are deliberately independent of any one screen: the owner home
// composes them, and the rooms, tenants, concerns and notices tabs reuse
// the same pieces.
//
// Rules:
//  * Flat white surfaces, hairline edges, air instead of heavy shadows.
//  * Emerald is the only saturated colour; everything else is ink/mint.
//  * Rounded outlines, never chunky filled glyphs.
//  * Every pressable thing answers on the first frame through
//    [PressableSurface]; nothing uses an expanding ripple.
//  * Motion is transform/opacity only and never blocks content.

// ==========================================================
// TOKENS
// ==========================================================

abstract final class HomeStyle {
  static const double gutter = 18;
  static const double cardRadius = 22;
  static const double heroRadius = 30;
  static const double tileRadius = 14;

  static Color get ink => AppColors.dark ? Color(0xFFE8F3EC) : AppColors.text;
  static Color get inkSoft =>
      AppColors.dark ? Color(0xFF9BB3A5) : AppColors.muted;
  static Color get inkFaint =>
      AppColors.dark ? Color(0xFF6F8A7A) : AppColors.muted;
  static Color get hairline => AppColors.hairline;
  static Color get mint =>
      AppColors.dark ? Color(0xFF0E1812) : AppColors.surface2;
  static Color get mintDeep =>
      AppColors.dark ? Color(0xFF16241C) : Color(0xFFE2F2E8);
  static Color get lime => AppColors.lime;
  static Color get emerald => AppColors.primary;
  static Color get forest =>
      AppColors.dark ? Color(0xFF0C3B26) : Color(0xFF0A4B30);

  static List<BoxShadow> get lift => [
        BoxShadow(
            color: AppColors.shadowSoft, blurRadius: 2, offset: Offset(0, 1)),
        BoxShadow(
            color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 5)),
      ];

  static const EdgeInsets screen = EdgeInsets.fromLTRB(gutter, 0, gutter, 0);
}

// ==========================================================
// SECTION HEADER
// ==========================================================

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.action,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: TextStyle(
                      color: HomeStyle.emerald,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  title,
                  style: AppType.h2.copyWith(fontSize: 19),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (action != null)
            PressableSurface(
              onTap: onAction,
              borderRadius: BorderRadius.circular(10),
              highlightColor: Colors.black.withValues(alpha: 0.04),
              pressedScale: 0.96,
              semanticsLabel: action,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  action!,
                  style: TextStyle(
                    color: HomeStyle.emerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================================
// SMALL CHIPS
// ==========================================================

class HomeTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;
  final bool dot;

  HomeTag({
    super.key,
    required this.text,
    this.color = const Color(0xFF0F7A44),
    this.background = const Color(0xFFE9F8EF),
    this.icon,
    this.dot = true,
  });

  HomeTag.lime({
    super.key,
    required this.text,
    this.icon,
  })  : color = HomeStyle.forest,
        background = const Color(0xFFC7F26A),
        dot = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact filter chip used by the segmented control and filter rows.
class HomeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  const HomeChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : HomeStyle.inkSoft;
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      pressedScale: 0.96,
      highlightColor: Colors.black.withValues(alpha: 0.04),
      semanticsLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.settle,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? HomeStyle.forest : HomeStyle.mint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? HomeStyle.forest : HomeStyle.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill segmented control with a sliding emerald indicator.
class HomeSegmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const HomeSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HomeStyle.mint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomeStyle.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: reduce ? Duration.zero : AppMotion.standard,
                curve: AppMotion.settle,
                left: index * itemWidth,
                top: 0,
                width: itemWidth,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: HomeStyle.lift,
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: PressableSurface(
                          onTap: () => onChanged(i),
                          borderRadius: BorderRadius.circular(999),
                          pressedScale: 0.97,
                          highlightColor: Colors.black.withValues(alpha: 0.035),
                          semanticsLabel: labels[i],
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: reduce ? Duration.zero : AppMotion.fast,
                              style: TextStyle(
                                color: i == index
                                    ? HomeStyle.ink
                                    : HomeStyle.inkSoft,
                                fontSize: 12,
                                fontWeight: i == index
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================================
// COUNT-UP NUMBER
// ==========================================================

class HomeCount extends StatelessWidget {
  final num value;
  final TextStyle style;
  final String Function(num)? format;
  final Duration duration;

  const HomeCount({
    super.key,
    required this.value,
    required this.style,
    this.format,
    this.duration = const Duration(milliseconds: 520),
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final text = format?.call(value) ?? '$value';
    if (reduce) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: AppMotion.settle,
      builder: (context, v, _) {
        final shown = value is int ? v.round() : (v * 10).round() / 10;
        return Text(
          format?.call(shown) ?? '$shown',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

// ==========================================================
// OCCUPANCY RING
// ==========================================================

class HomeRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Widget? center;
  final Color track;
  final List<Color> colors;

  HomeRing({
    super.key,
    required this.value,
    this.size = 92,
    this.stroke = 9,
    this.center,
    this.track = const Color(0xFFE2F2E8),
    this.colors = const [Color(0xFF0F7A44), Color(0xFFC7F26A)],
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 620),
        curve: AppMotion.settle,
        builder: (context, v, child) {
          return CustomPaint(
            painter: _RingPainter(
              value: v,
              stroke: stroke,
              track: track,
              colors: colors,
            ),
            child: child,
          );
        },
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color track;
  final List<Color> colors;

  const _RingPainter({
    required this.value,
    required this.stroke,
    required this.track,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - stroke) / 2,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, base);

    if (value <= 0) return;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
        colors: colors,
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, progress);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value ||
      old.stroke != stroke ||
      old.track != track ||
      old.colors != colors;
}

// ==========================================================
// SPARKLINE
// ==========================================================

class HomeSparkline extends StatelessWidget {
  final List<double> values;
  final double height;
  final Color color;
  final bool fill;

  HomeSparkline({
    super.key,
    required this.values,
    this.height = 44,
    this.color = const Color(0xFF0F7A44),
    this.fill = true,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: color, fill: fill),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool fill;

  const _SparklinePainter({
    required this.values,
    required this.color,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final spread = math.max(maxValue - minValue, 0.0001);
    final dx = size.width / (values.length - 1);

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * dx,
          size.height -
              ((values[i] - minValue) / spread) * (size.height * 0.82) -
              4,
        ),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size);
      canvas.drawPath(area, paint);
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(path, line);

    final dot = Paint()..color = color;
    canvas.drawCircle(points.last, 2.6, dot);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color || old.fill != fill;
}

// ==========================================================
// MINI BAR CHART
// ==========================================================

class HomeBars extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double height;
  final Color color;

  HomeBars({
    super.key,
    required this.values,
    required this.labels,
    this.height = 84,
    this.color = const Color(0xFF0F7A44),
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 1.0 : values.reduce(math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: (values[i] / (maxValue == 0 ? 1 : maxValue))
                          .clamp(0, 1)
                          .toDouble(),
                    ),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : Duration(milliseconds: 420 + i * 40),
                    curve: AppMotion.settle,
                    builder: (context, v, _) {
                      return Container(
                        height: (height - 22) * v,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == values.length - 1
                              ? color
                              : color.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeStyle.inkFaint,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================================
// HERO
// ==========================================================

class HomeHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String badge;
  final double occupancy;
  final int rooms;
  final int tenants;
  final int openBeds;
  final VoidCallback? onRooms;
  final VoidCallback? onTenants;
  final VoidCallback? onConcerns;

  const HomeHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.occupancy,
    required this.rooms,
    required this.tenants,
    required this.openBeds,
    this.onRooms,
    this.onTenants,
    this.onConcerns,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (occupancy * 100).round();
    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06301D), Color(0xFF0A4B30), Color(0xFF0F7A44)],
            stops: [0, 0.55, 1],
          ),
          borderRadius: BorderRadius.circular(HomeStyle.heroRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E06301D),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _HeroAura()),
              ),
            ),
            const Positioned.fill(
              child: TAmbient(
                art: 'aurora',
                opacity: 0.55,
                size: 440,
                alignment: Alignment.bottomRight,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    eyebrow.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HomeStyle.lime,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.h1.copyWith(
                      color: Colors.white,
                      fontSize: 27,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(
                      color: const Color(0xFFC9E2D5),
                      fontSize: 12,
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
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.13),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: HomeRing(
                            value: occupancy,
                            size: 62,
                            stroke: 6,
                            track: HomeStyle.mintDeep,
                            colors: [
                              HomeStyle.emerald,
                              Color(0xFF16A356),
                            ],
                            center: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HomeCount(
                                  value: pct,
                                  format: (v) => '${v.round()}%',
                                  style: TextStyle(
                                    color: HomeStyle.ink,
                                    fontSize: 16,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'FILLED',
                                  style: TextStyle(
                                    color: HomeStyle.inkFaint,
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pct >= 100
                                    ? 'Fully occupied'
                                    : pct >= 50
                                        ? 'Mostly occupied'
                                        : 'Room to fill',
                                style: AppType.h3.copyWith(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$openBeds open ${openBeds == 1 ? 'bed' : 'beds'} right now',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tMeta(
                                  color: const Color(0xFFC9E2D5),
                                ).copyWith(fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: HomeStyle.lime,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          badge,
                          style: const TextStyle(
                            color: Color(0xFFE8F7EE),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.13),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _HeroStat(
                          value: rooms,
                          label: 'Rooms',
                          onTap: onRooms,
                        ),
                        _HeroDivider(),
                        _HeroStat(
                          value: tenants,
                          label: 'Tenants',
                          onTap: onTenants,
                        ),
                        _HeroDivider(),
                        _HeroStat(
                          value: openBeds,
                          label: 'Open beds',
                          onTap: onConcerns,
                        ),
                      ],
                    ),
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

class _HeroStat extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onTap;

  const _HeroStat({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableSurface(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        pressedScale: 0.97,
        highlightColor: Colors.white.withValues(alpha: 0.06),
        semanticsLabel: '$label: $value',
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              children: [
                HomeCount(
                  value: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: AppType.displayFamily,
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFC9E2D5),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _HeroAura extends CustomPainter {
  const _HeroAura();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);
    final center = Offset(size.width * 0.94, -size.height * 0.05);
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(center, 42.0 * i, ring);
    }

    final glowCenter = Offset(size.width * 0.06, size.height * 0.92);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: glowCenter, radius: size.width * 0.62),
      );
    canvas.drawCircle(glowCenter, size.width * 0.62, glow);

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
      ..moveTo(0, size.height * 0.78)
      ..lineTo(size.width * 0.62, 0)
      ..lineTo(size.width * 0.86, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, sheen);
  }

  @override
  bool shouldRepaint(covariant _HeroAura old) => false;
}

// ==========================================================
// METRIC CARD
// ==========================================================

class HomeMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? delta;
  final Color color;
  final VoidCallback? onTap;

  HomeMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.delta,
    this.color = const Color(0xFF0F7A44),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
      pressedScale: AppMotion.cardPressScale,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: '$label: $value',
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
          border: Border.all(color: HomeStyle.hairline),
          boxShadow: HomeStyle.lift,
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: TAmbient(
                art: 'drift',
                opacity: 0.16,
                size: 380,
                alignment: Alignment.topRight,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, size: 17, color: color),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HomeStyle.ink,
                        fontFamily: AppType.displayFamily,
                        fontSize: 25,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HomeStyle.inkFaint,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        delta!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.85),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

// ==========================================================
// ROOM CARD
// ==========================================================

class HomeRoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;

  const HomeRoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onLongPress,
    this.width = 176,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = room.capacity <= 0
        ? 0.0
        : (room.occupied / room.capacity).clamp(0.0, 1.0);
    final full = room.isFull;
    return SizedBox(
      width: width,
      child: PressableSurface(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
        pressedScale: AppMotion.cardPressScale,
        highlightColor: Colors.black.withValues(alpha: 0.03),
        semanticsLabel:
            'Room ${room.roomNumber}, ${room.occupied} of ${room.capacity} beds',
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
            border: Border.all(color: HomeStyle.hairline),
            boxShadow: HomeStyle.lift,
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: TAmbient(
                  art: 'halo',
                  opacity: 0.14,
                  size: 380,
                  alignment: Alignment.bottomRight,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Room ${room.roomNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: HomeStyle.ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        HomeTag(
                          text: full ? 'Full' : '${room.available} open',
                          color: full ? HomeStyle.forest : HomeStyle.emerald,
                          background:
                              full ? HomeStyle.lime : const Color(0xFFE9F8EF),
                          dot: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${room.occupied} of ${room.capacity} beds occupied',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HomeStyle.inkSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: fraction),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 380),
                        curve: AppMotion.settle,
                        builder: (context, v, _) {
                          return LinearProgressIndicator(
                            value: v,
                            minHeight: 5,
                            backgroundColor: HomeStyle.mintDeep,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              full
                                  ? HomeStyle.emerald
                                  : const Color(0xFF16A356),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < room.capacity && i < 8; i++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < room.occupied
                                  ? HomeStyle.emerald
                                  : HomeStyle.mintDeep,
                            ),
                          ),
                        const Spacer(),
                        if (room.available > 0)
                          Icon(
                            AppIcons.chevron,
                            size: 17,
                            color: HomeStyle.inkFaint,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// PERSON ROW
// ==========================================================

class HomePersonRow extends StatelessWidget {
  final String name;
  final String? meta;
  final String? status;
  final String? statusTone;
  final VoidCallback? onTap;
  final Widget? trailing;

  const HomePersonRow({
    super.key,
    required this.name,
    this.meta,
    this.status,
    this.statusTone,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tone = (statusTone ?? status ?? 'paid').toLowerCase();
    final color = tone == 'paid'
        ? HomeStyle.emerald
        : tone == 'partial'
            ? const Color(0xFFB45309)
            : const Color(0xFFB91C1C);
    final bg = tone == 'paid'
        ? const Color(0xFFE9F8EF)
        : tone == 'partial'
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2);

    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      pressedScale: 0.99,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: name,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeStyle.forest,
              ),
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeStyle.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HomeStyle.inkFaint,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (status != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status!,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'T';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

// ==========================================================
// CONCERN ROW
// ==========================================================

class HomeConcernRow extends StatelessWidget {
  final ConcernModel concern;
  final VoidCallback? onTap;

  const HomeConcernRow({super.key, required this.concern, this.onTap});

  @override
  Widget build(BuildContext context) {
    final resolved =
        concern.status.toLowerCase() == ConcernModel.statusResolved;
    final icon = _categoryIcon(concern.category);
    final color = resolved ? HomeStyle.inkSoft : const Color(0xFFB45309);

    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      pressedScale: 0.99,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: concern.subject,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: resolved ? HomeStyle.mint : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    concern.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeStyle.ink,
                      fontSize: 13.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Room ${concern.roomNumber ?? '—'} · ${_when(concern.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeStyle.inkFaint,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HomeTag(
              text: resolved ? 'Resolved' : 'Pending',
              color: resolved ? HomeStyle.emerald : const Color(0xFFB45309),
              background:
                  resolved ? const Color(0xFFE9F8EF) : const Color(0xFFFEF3C7),
              dot: false,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'utility':
        return AppIcons.boltLine;
      case 'cleanliness':
        return AppIcons.cleaningLine;
      case 'security':
        return AppIcons.shieldLine;
      case 'noise':
        return AppIcons.volumeLine;
      default:
        return AppIcons.buildLine;
    }
  }

  static String _when(DateTime? at) {
    if (at == null) return 'just now';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(at);
  }
}

// ==========================================================
// NOTICE CARD
// ==========================================================

class HomeNoticeCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isNew;
  final VoidCallback? onTap;

  const HomeNoticeCard({
    super.key,
    required this.announcement,
    this.isNew = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
      pressedScale: AppMotion.cardPressScale,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: announcement.title,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
          border: Border.all(color: HomeStyle.hairline),
          boxShadow: HomeStyle.lift,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                AppIcons.megaphoneLine,
                size: 17,
                color: Color(0xFF0369A1),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          announcement.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: HomeStyle.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 6),
                        HomeTag.lime(text: 'NEW'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    announcement.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeStyle.inkSoft,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    announcement.publishedAt == null
                        ? 'Recently posted'
                        : DateFormat('MMM d · h:mm a')
                            .format(announcement.publishedAt!),
                    style: TextStyle(
                      color: HomeStyle.inkFaint,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
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

// ==========================================================
// TIMELINE
// ==========================================================

class HomeTimelineItem {
  final IconData icon;
  final String title;
  final String meta;
  final String? tag;
  final Color color;

  HomeTimelineItem({
    required this.icon,
    required this.title,
    required this.meta,
    this.tag,
    this.color = const Color(0xFF0F7A44),
  });
}

class HomeTimeline extends StatelessWidget {
  final List<HomeTimelineItem> items;

  const HomeTimeline({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: items[i].color.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        items[i].icon,
                        size: 14,
                        color: items[i].color,
                      ),
                    ),
                    if (i != items.length - 1)
                      Container(
                        width: 1,
                        height: 22,
                        color: HomeStyle.hairline,
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: HomeStyle.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: HomeStyle.inkFaint,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (items[i].tag != null) HomeTag(text: items[i].tag!),
              ],
            ),
          ),
      ],
    );
  }
}

// ==========================================================
// QUICK ACTION TILE
// ==========================================================

class HomeQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  HomeQuickAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color = const Color(0xFF0F7A44),
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      pressedScale: 0.96,
      highlightColor: Colors.black.withValues(alpha: 0.035),
      semanticsLabel: label,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withValues(alpha: 0.10)),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HomeStyle.inkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// SEARCH PILL
// ==========================================================

class HomeSearchPill extends StatelessWidget {
  final String hint;
  final VoidCallback? onTap;

  const HomeSearchPill({
    super.key,
    this.hint = 'Search rooms, tenants, notices',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      pressedScale: 0.99,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: hint,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: HomeStyle.hairline),
        ),
        child: Row(
          children: [
            Icon(AppIcons.search, size: 18, color: HomeStyle.inkFaint),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HomeStyle.inkFaint,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(AppIcons.tune, size: 17, color: HomeStyle.inkFaint),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// EMPTY / LOADING
// ==========================================================

class HomeEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const HomeEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      child: Column(
        children: [
          const LottieArt('empty', size: 118),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.h3.copyWith(
              color: HomeStyle.ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(
              color: HomeStyle.inkFaint,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSkeletonBlock extends StatelessWidget {
  final double height;
  final double width;
  final double radius;

  const HomeSkeletonBlock({
    super.key,
    this.height = 14,
    this.width = double.infinity,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: HomeStyle.mintDeep,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ==========================================================
// KEY CARD
// ==========================================================

class HomeKeyCard extends StatelessWidget {
  final String houseKey;
  final VoidCallback onCopy;

  const HomeKeyCard({
    super.key,
    required this.houseKey,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF052E1C), Color(0xFF0A4B30)],
        ),
        borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              AppIcons.keyLine,
              size: 18,
              color: HomeStyle.lime,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HOUSE ACCESS KEY',
                  style: TextStyle(
                    color: Color(0xFF9FC7B2),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  houseKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          PressableSurface(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(12),
            pressedScale: 0.94,
            highlightColor: Colors.black.withValues(alpha: 0.08),
            semanticsLabel: 'Copy house key',
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HomeStyle.lime,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                AppIcons.copy,
                size: 18,
                color: Color(0xFF052E1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
