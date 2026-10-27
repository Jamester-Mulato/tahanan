import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/app_config.dart';
import '../core/app_motion.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'app_icons.dart';
import 'motion.dart';
import 'pressable.dart';
import 'tahanan_kit.dart';

// ==========================================================
// BACKGROUND WITH BOTANICAL ACCENTS + IDLE DRIFT
// ==========================================================

// ==========================================================
// BACKGROUND (single owner per navigator branch)
// ==========================================================
//
// [TahananBackground] paints the app gradient exactly once per route.
// Shells (owner/tenant) own the background; tab screens inherit it via
// [_TahananBackgroundScope] and render only their content, so nested
// tabs never composite duplicate gradients. Pushed routes have no
// ancestor scope, so standalone screens (login, houses, detail flows)
// still paint their own background. `showFoliage`/`animate` are retained
// for constructor compatibility; the background is intentionally a
// static gradient (no per-frame foliage or orb tickers) to protect
// mid-range GPUs.

class _TahananBackgroundScope extends InheritedWidget {
  const _TahananBackgroundScope({required super.child});

  @override
  bool updateShouldNotify(covariant _TahananBackgroundScope oldWidget) => false;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TahananBackgroundScope>() !=
      null;
}

class TahananBackground extends StatefulWidget {
  final Widget child;
  final bool showFoliage;
  final bool animate;

  const TahananBackground({
    super.key,
    required this.child,
    this.showFoliage = true,
    this.animate = true,
  });

  @override
  State<TahananBackground> createState() => _TahananBackgroundState();
}

class _TahananBackgroundState extends State<TahananBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!widget.animate || reduce) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inherit the shell's background instead of painting a second gradient.
    if (_TahananBackgroundScope.of(context)) return widget.child;

    return _TahananBackgroundScope(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.backgroundGradientTop,
                  AppColors.background,
                  AppColors.backgroundGradientBottom,
                ],
              ),
            ),
          ),
          // Slow ambient light drift. One painter and one repaint layer.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _BackgroundDriftPainter(_drift),
                isComplex: true,
                willChange: true,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _BackgroundDriftPainter extends CustomPainter {
  _BackgroundDriftPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static final _orbs = <_BackgroundOrb>[
    _BackgroundOrb(
      size: 380,
      color: Color(0x1C22C55E),
      anchor: _OrbAnchor.topRight,
      base: Offset(70, 40),
      drift: Offset(16, 22),
      phase: 0,
    ),
    _BackgroundOrb(
      size: 420,
      color: Color(0x22C7F26A),
      anchor: _OrbAnchor.bottomLeft,
      base: Offset(80, 30),
      drift: Offset(18, 26),
      phase: 0,
      invert: true,
    ),
    _BackgroundOrb(
      size: 260,
      color: Color(0x14A3D84A),
      anchor: _OrbAnchor.topLeft,
      base: Offset(40, 370),
      drift: Offset(20, 30),
      phase: 2.1,
    ),
    _BackgroundOrb(
      size: 280,
      color: Color(0x1238BDF8),
      anchor: _OrbAnchor.topRight,
      base: Offset(320, 180),
      drift: Offset(18, 24),
      phase: 0.8,
      invert: true,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * math.pi * 2;
    for (final orb in _orbs) {
      final dx = math.sin(t + orb.phase) * orb.drift.dx;
      final dy =
          (orb.invert ? math.sin : math.cos)(t + orb.phase) * orb.drift.dy;
      final cx = switch (orb.anchor) {
        _OrbAnchor.topLeft => orb.base.dx,
        _OrbAnchor.topRight => size.width - orb.base.dx,
        _OrbAnchor.bottomLeft => orb.base.dx,
      };
      final cy = switch (orb.anchor) {
        _OrbAnchor.topLeft => orb.base.dy,
        _OrbAnchor.topRight => orb.base.dy,
        _OrbAnchor.bottomLeft => size.height - orb.base.dy,
      };
      canvas.save();
      canvas.translate(cx + dx, cy + dy);
      canvas.drawCircle(Offset.zero, orb.size / 2, orb.paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundDriftPainter oldDelegate) => false;
}

enum _OrbAnchor { topLeft, topRight, bottomLeft }

class _BackgroundOrb {
  final double size;
  final Offset base;
  final Offset drift;
  final double phase;
  final bool invert;
  final _OrbAnchor anchor;
  final Paint paint;

  _BackgroundOrb({
    required this.size,
    required this.base,
    required this.drift,
    required this.phase,
    required this.anchor,
    required Color color,
    this.invert = false,
  }) : paint = Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: size / 2),
          );
}

// Alias for compatibility
typedef AmbientBackground = TahananBackground;
// ==========================================================
// TAHANAN LOGO WIDGET (House with Leaf Roof Accent + idle float)
// ==========================================================

class TahananLogo extends StatelessWidget {
  final double size;
  final bool animate;
  const TahananLogo({super.key, this.size = 80, this.animate = true});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.29);
    final logo = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft ambient glow behind the mark
          Container(
            width: size * 1.18,
            height: size * 1.18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.emerald500.withValues(alpha: 0.22),
                  AppColors.emerald500.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald800.withValues(alpha: 0.30),
                  blurRadius: size * 0.30,
                  offset: Offset(0, size * 0.12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Image.asset(
                'assets/images/tahanan_logo.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
    if (!animate) return logo;
    return IdleFloat(amplitude: size * 0.035, child: logo);
  }
}

// ==========================================================
// PANEL / GLASS CARD
// ==========================================================

class Panel extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool pressScale;
  final Color? accent;
  final Gradient? gradient;
  final bool showShadow;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = AppColors.radiusLg,
    this.pressScale = true,
    this.accent,
    this.gradient,
    this.showShadow = true,
  });

  @override
  State<Panel> createState() => _PanelState();
}

class _PanelState extends State<Panel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? tap = widget.onTap;
    final interactive = tap != null || widget.onLongPress != null;

    final Widget inkOrChild = interactive
        ? InkWell(
            onTap: tap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    tap();
                  },
            onLongPress: widget.onLongPress,
            onHighlightChanged: widget.pressScale
                ? (pressed) {
                    if (_pressed != pressed) {
                      setState(() => _pressed = pressed);
                    }
                  }
                : null,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: AppColors.primary.withValues(alpha: 0.09),
            highlightColor: AppColors.primary.withValues(alpha: 0.035),
            child: widget.child,
          )
        : widget.child;

    final panel = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.gradient == null
              ? (widget.backgroundColor ?? AppColors.surface)
              : null,
          gradient: widget.gradient ?? AppColors.surfaceSheen,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.borderColor == null
              ? null
              : Border.all(color: widget.borderColor!, width: 1),
          boxShadow: widget.showShadow ? AppColors.panelShadow : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            children: [
              // A barely-there top sheen catches the light like soft paper.
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                        stops: [0.0, 0.62],
                      ),
                    ),
                  ),
                ),
              ),
              // Material lives inside the decorated box so InkWell ripples
              // and ListTile ink paint above the panel background.
              Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: widget.padding,
                  child: inkOrChild,
                ),
              ),
              if (widget.accent != null)
                Positioned(
                  left: 6,
                  top: 12,
                  bottom: 12,
                  width: 3.5,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.accent!,
                            widget.accent!.withValues(alpha: 0.35),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!interactive || !widget.pressScale) return panel;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: panel,
    );
  }
}

// ==========================================================
// STATUS PILLS
// ==========================================================

enum StatusType { paid, partial, unpaid, full, open, active, custom }

class StatusPill extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? backgroundColor;
  final StatusType type;

  const StatusPill({
    super.key,
    required this.text,
    this.color,
    this.backgroundColor,
    this.type = StatusType.custom,
  });

  factory StatusPill.fromPaymentStatus(String? status) {
    final s = (status ?? 'paid').toLowerCase();
    if (s == 'paid') {
      return StatusPill(
        text: 'Paid',
        color: AppColors.statusPaid,
        backgroundColor: AppColors.statusPaidBg,
        type: StatusType.paid,
      );
    } else if (s == 'partial') {
      return StatusPill(
        text: 'Partial',
        color: AppColors.statusPartial,
        backgroundColor: AppColors.statusPartialBg,
        type: StatusType.partial,
      );
    } else {
      return StatusPill(
        text: 'Unpaid',
        color: AppColors.statusUnpaid,
        backgroundColor: AppColors.statusUnpaidBg,
        type: StatusType.unpaid,
      );
    }
  }

  factory StatusPill.fromOccupancy(RoomModel room) {
    if (room.isFull) {
      return StatusPill(
        text: 'Full',
        color: AppColors.primary,
        backgroundColor: AppColors.statusPaidBg,
        type: StatusType.full,
      );
    } else {
      return StatusPill(
        text: '${room.available} Open',
        color: AppColors.primary,
        backgroundColor: AppColors.statusPaidBg,
        type: StatusType.open,
      );
    }
  }

  factory StatusPill.fromConcernStatus(String status) {
    final s = status.toLowerCase();
    if (s == ConcernModel.statusResolved) {
      return StatusPill(
        text: 'Resolved',
        color: AppColors.statusPaid,
        backgroundColor: AppColors.statusPaidBg,
      );
    } else if (s == ConcernModel.statusPending) {
      return StatusPill(
        text: 'Pending',
        color: AppColors.statusPartial,
        backgroundColor: AppColors.statusPartialBg,
      );
    } else {
      return StatusPill(
        text: 'Unread',
        color: AppColors.statusUnpaid,
        backgroundColor: AppColors.statusUnpaidBg,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final bg = backgroundColor ?? c.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.35),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// Alias for backwards compatibility
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      text: text,
      color: color,
      backgroundColor: color.withValues(alpha: 0.15),
    );
  }
}

// ==========================================================
// STAT CARD & KEY HERO CARD
// ==========================================================

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasChevron;
  final Color? accentColor;
  final num? animatedValue;
  final String? caption;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.hasChevron = false,
    this.accentColor,
    this.animatedValue,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return Panel(
      onTap: onTap,
      pressScale: false,
      padding: EdgeInsets.zero,
      borderRadius: AppColors.radiusLg,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surface,
          color.withValues(alpha: 0.055),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const Spacer(),
                if (hasChevron)
                  Icon(
                    AppIcons.outward,
                    color: color.withValues(alpha: 0.42),
                    size: 15,
                  ),
              ],
            ),
            const SizedBox(height: 15),
            if (animatedValue != null)
              CountUp(
                value: animatedValue!,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.9,
                  color: AppColors.text,
                ),
              )
            else
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.9,
                  color: AppColors.text,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color.withValues(alpha: 0.78),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class KeyHeroCard extends StatelessWidget {
  final String joinKey;
  final String? boardingHouseName;
  final String? domain;
  final String? ownerName;
  final String? ownerEmail;
  final VoidCallback? onCopy;

  const KeyHeroCard({
    super.key,
    required this.joinKey,
    this.boardingHouseName,
    this.domain,
    this.ownerName,
    this.ownerEmail,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final hasOwner = (ownerName != null && ownerName!.isNotEmpty) ||
        (ownerEmail != null && ownerEmail!.isNotEmpty);
    final ownerLabel =
        ownerName?.isNotEmpty == true ? ownerName! : 'Signed-in account';
    final initial = ownerLabel.substring(0, 1).toUpperCase();

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF8FDFA),
              Color(0xFFEFFAF3),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          border: Border.all(
              color: (AppColors.dark
                  ? AppColors.border.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9))),
          boxShadow: AppColors.floatingShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -70,
                child: IgnorePointer(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.10),
                          AppColors.primary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _KeyPatternPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emerald800
                                    .withValues(alpha: 0.20),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            AppIcons.key,
                            color: AppColors.lime,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HOUSE ACCESS KEY',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                boardingHouseName ?? 'Boarding House',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (domain != null && domain!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '@$domain',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lime.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.shield,
                                size: 10,
                                color: AppColors.emerald800,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'PRIVATE',
                                style: TextStyle(
                                  color: AppColors.emerald800,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Perforated boarding-pass divider.
                    const SizedBox(
                      height: 12,
                      width: double.infinity,
                      child: CustomPaint(painter: _PerforationPainter()),
                    ),
                    const SizedBox(height: 12),

                    // Key strip
                    Container(
                      padding: const EdgeInsets.fromLTRB(13, 9, 8, 9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.emerald900,
                            AppColors.emerald700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald900.withValues(alpha: 0.20),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SHARE TO JOIN',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.46),
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    joinKey,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      height: 1.15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CopyKeyButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: joinKey));
                              if (onCopy != null) {
                                onCopy!();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'House key copied to clipboard',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Icon(
                          AppIcons.info,
                          size: 13,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Share this key so tenants can join your house.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasOwner) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              gradient: AppColors.mintGradient,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.4,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: AppColors.emerald700,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Owner · $ownerLabel'
                              '${ownerEmail != null && ownerEmail!.isNotEmpty ? ' · $ownerEmail' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Dashed perforation with two notches, turning the key card into a
/// boarding-pass style ticket.
class _PerforationPainter extends CustomPainter {
  const _PerforationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final dash = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    var x = 18.0;
    while (x < size.width - 18) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
      x += 10;
    }

    final notch = Paint()..color = AppColors.background;
    canvas.drawCircle(Offset(0, y), 6, notch);
    canvas.drawCircle(Offset(size.width, y), 6, notch);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CopyKeyButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CopyKeyButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AppColors.limeGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.lime.withValues(alpha: 0.24),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            AppIcons.copy,
            color: AppColors.emerald900,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Faint concentric key-rings etched into the green hero card.
class _KeyPatternPainter extends CustomPainter {
  const _KeyPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);

    final center = Offset(size.width * 0.92, size.height * 0.10);
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(center, 26.0 * i, ring);
    }

    final dot = Paint()..color = Colors.white.withValues(alpha: 0.10);
    const spots = [
      Offset(0.08, 0.90),
      Offset(0.17, 0.78),
      Offset(0.86, 0.72),
      Offset(0.92, 0.56),
      Offset(0.72, 0.16),
    ];
    for (final s in spots) {
      canvas.drawCircle(
        Offset(size.width * s.dx, size.height * s.dy),
        1.6,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ROOM CARD
// ==========================================================

class RoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = room.capacity <= 0
        ? 0.0
        : (room.occupied / room.capacity).clamp(0.0, 1.0);
    final full = room.isFull;
    final accent = full ? AppColors.emerald600 : AppColors.emerald500;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          onTap: onTap,
          onLongPress: onLongPress,
          pressScale: false,
          padding: EdgeInsets.zero,
          borderRadius: AppColors.radiusLg,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 13, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.mintGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        AppIcons.room,
                        color: AppColors.emerald700,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room ${room.roomNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.25,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${room.occupied} of ${room.capacity} beds occupied',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusPill.fromOccupancy(room),
                    const SizedBox(width: 2),
                    Icon(
                      AppIcons.chevron,
                      color: AppColors.muted.withValues(alpha: 0.45),
                      size: 19,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BedDots(
                        capacity: room.capacity,
                        occupied: room.occupied,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      full ? 'Full' : '${room.available} open',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _OccupancyBar(value: fraction, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OccupancyBar extends StatelessWidget {
  final double value;
  final Color color;

  const _OccupancyBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: animated.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.65)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==========================================================
// OCCUPANCY RING + BED DOTS
// ==========================================================

class OccupancyRing extends StatelessWidget {
  final double value;
  final String label;
  final String? caption;
  final double size;
  final Color color;
  final Color trackColor;
  final double stroke;

  OccupancyRing({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.size = 72,
    this.color = const Color(0xFF0F7A44),
    this.trackColor = const Color(0xFFE7F5EC),
    this.stroke = 7,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: AppColors.slowAnim,
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            return CustomPaint(
              painter: _RingPainter(
                value: v,
                color: color,
                trackColor: trackColor,
                stroke: stroke,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: size * 0.24,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption!,
                        maxLines: 1,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double stroke;

  const _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [color, color.withValues(alpha: 0.55)],
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.stroke != stroke;
  }
}

class BedDots extends StatelessWidget {
  final int capacity;
  final int occupied;
  final Color color;

  BedDots({
    super.key,
    required this.capacity,
    required this.occupied,
    this.color = const Color(0xFF0F7A44),
  });

  @override
  Widget build(BuildContext context) {
    final total = capacity.clamp(0, 24);
    final filled = occupied.clamp(0, total);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isFilled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.62)],
                  )
                : null,
            color: isFilled ? null : AppColors.surfaceElevated,
          ),
        );
      }),
    );
  }
}

class TenantCard extends StatelessWidget {
  final TenantModel tenant;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final List<PopupMenuEntry<String>> Function(BuildContext)? menuBuilder;
  final void Function(String)? onMenuSelected;

  const TenantCard({
    super.key,
    required this.tenant,
    this.onTap,
    this.onMenu,
    this.menuBuilder,
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final initial = tenant.fullName.isNotEmpty
        ? tenant.fullName.substring(0, 1).toUpperCase()
        : 'T';
    final status = (tenant.paymentStatus ?? 'paid').toLowerCase();
    final accent = status == 'paid'
        ? AppColors.statusPaid
        : status == 'partial'
            ? AppColors.statusPartial
            : AppColors.statusUnpaid;
    final assigned = tenant.roomNumber != null;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          onTap: onTap,
          pressScale: false,
          borderRadius: AppColors.radiusLg,
          accent: accent,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 9, 13),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.mintGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: AppColors.emerald700,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.18),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.25,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: assigned
                                  ? AppColors.surface2
                                  : AppColors.warningBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  assigned
                                      ? AppIcons.roomAlt
                                      : AppIcons.concernAlert,
                                  size: 11,
                                  color: assigned
                                      ? AppColors.muted
                                      : AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  assigned
                                      ? 'Room ${tenant.roomNumber}'
                                      : 'Not assigned',
                                  style: TextStyle(
                                    color: assigned
                                        ? AppColors.textSecondary
                                        : AppColors.warning,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                StatusPill.fromPaymentStatus(tenant.paymentStatus),
                if (menuBuilder != null)
                  PopupMenuButton<String>(
                    icon: Icon(
                      AppIcons.moreVertical,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: AppColors.border),
                    ),
                    onSelected: onMenuSelected,
                    itemBuilder: menuBuilder!,
                  )
                else
                  const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// ANNOUNCEMENT CARD
// ==========================================================

class AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isNew;
  final VoidCallback? onMore;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.isNew = false,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = announcement.publishedAt != null
        ? DateFormat('MMM d, yyyy · h:mm a').format(announcement.publishedAt!)
        : 'Recently posted';

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Panel(
          pressScale: false,
          borderRadius: AppColors.radiusLg,
          accent: AppColors.info,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 15, 13, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.infoBg,
                            AppColors.info.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AppIcons.announcement,
                        color: AppColors.info,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Announcement',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.sparkle,
                              size: 10,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'New',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (onMore != null) ...[
                      const SizedBox(width: 2),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onMore,
                        icon: Icon(
                          AppIcons.moreVertical,
                          color: AppColors.muted,
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  announcement.title,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.25,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  announcement.message,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.55,
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

// ==========================================================
// FEATURED ANNOUNCEMENT CARD
// ==========================================================

/// A deep-emerald showcase for the most recent notice.
///
/// Used at the top of the notice board (and the tenant home) so the newest
/// update reads as a headline instead of another white card.
class FeaturedAnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const FeaturedAnnouncementCard({
    super.key,
    required this.announcement,
    this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = announcement.publishedAt != null
        ? DateFormat('MMM d · h:mm a').format(announcement.publishedAt!)
        : 'Recently posted';

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  },
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            splashColor: Colors.white.withValues(alpha: 0.10),
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald900.withValues(alpha: 0.20),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: AppColors.emerald900.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration:
                              BoxDecoration(gradient: AppColors.heroSheen),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -52,
                      top: -58,
                      child: IgnorePointer(
                        child: Container(
                          width: 168,
                          height: 168,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.lime.withValues(alpha: 0.09),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 26,
                      bottom: -74,
                      child: IgnorePointer(
                        child: Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(9, 5, 10, 5),
                                decoration: BoxDecoration(
                                  gradient: AppColors.limeGradient,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(999),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.sparkle,
                                      size: 11,
                                      color: AppColors.emerald900,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'LATEST NOTICE',
                                      style: TextStyle(
                                        color: AppColors.emerald900,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (onMore != null)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onMore,
                                  icon: Icon(
                                    AppIcons.moreVertical,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              announcement.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                height: 1.24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Text(
                              announcement.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.heroMuted,
                                fontSize: 12,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                AppIcons.calendar,
                                size: 12,
                                color: AppColors.lime,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  dateStr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.60),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Read notice',
                                style: TextStyle(
                                  color: AppColors.lime,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                AppIcons.chevron,
                                color: AppColors.lime,
                                size: 16,
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
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// CONCERN CARD
// ==========================================================

class ConcernCard extends StatelessWidget {
  final ConcernModel concern;
  final VoidCallback? onTap;

  const ConcernCard({
    super.key,
    required this.concern,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = concern.status.toLowerCase();
    final accent = status == ConcernModel.statusResolved
        ? AppColors.statusPaid
        : status == ConcernModel.statusUnread
            ? AppColors.statusUnpaid
            : AppColors.statusPartial;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Panel(
          onTap: onTap,
          pressScale: false,
          borderRadius: AppColors.radiusLg,
          accent: accent,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 15, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.concern,
                            size: 11,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            concern.category,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    StatusPill.fromConcernStatus(concern.status),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        concern.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.25,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    if (concern.rating != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.star,
                              color: AppColors.warning,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${concern.rating}',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (concern.tenantName != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        AppIcons.tenantSingle,
                        size: 12,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${concern.tenantName}'
                          '${concern.roomNumber != null ? ' · Room ${concern.roomNumber}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  concern.details,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),
                if (concern.attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: concern.attachments.map((att) {
                      final url = att.publicUrl ?? '';
                      final fullUrl = url.startsWith('http')
                          ? url
                          : '${AppConfig.apiBaseUrl}$url';
                      final isVideo =
                          att.mimeType?.startsWith('video') ?? false;

                      return GestureDetector(
                        onTap: () {
                          if (isVideo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Video playback coming soon. View the thumbnail above.',
                                ),
                              ),
                            );
                          } else {
                            ImageViewerDialog.show(
                              context,
                              fullUrl,
                              title: att.fileName ?? 'Attachment',
                            );
                          }
                        },
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (isVideo)
                                  Center(
                                    child: Icon(
                                      AppIcons.video,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  )
                                else
                                  RepaintBoundary(
                                    child: Image.network(
                                      fullUrl,
                                      fit: BoxFit.cover,
                                      cacheWidth: 192,
                                      filterQuality: FilterQuality.low,
                                      gaplessPlayback: true,
                                      errorBuilder: (ctx, err, stack) => Center(
                                        child: Icon(
                                          AppIcons.image,
                                          color: AppColors.muted,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isVideo)
                                  Center(
                                    child: Icon(
                                      AppIcons.play,
                                      color: (AppColors.dark
                                          ? AppColors.border
                                              .withValues(alpha: 0.8)
                                          : Colors.white
                                              .withValues(alpha: 0.9)),
                                      size: 26,
                                    ),
                                  ),
                                Positioned(
                                  bottom: 3,
                                  right: 3,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Icon(
                                      isVideo
                                          ? AppIcons.video
                                          : AppIcons.zoomIn,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (concern.ownerResponse != null &&
                    concern.ownerResponse!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.mint100,
                          AppColors.mint100.withValues(alpha: 0.55),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              AppIcons.concern,
                              color: AppColors.primary,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'OWNER RESPONSE',
                              style: TextStyle(
                                color: AppColors.primaryDark
                                    .withValues(alpha: 0.85),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          concern.ownerResponse!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// IMAGE VIEWER DIALOG
// ==========================================================

// IMAGE VIEWER DIALOG
// ==========================================================

class ImageViewerDialog extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const ImageViewerDialog({
    super.key,
    required this.imageUrl,
    this.title,
  });

  static void show(BuildContext context, String imageUrl, {String? title}) {
    showDialog(
      context: context,
      builder: (ctx) => ImageViewerDialog(imageUrl: imageUrl, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${AppConfig.apiBaseUrl}$imageUrl';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 560),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 48, 10),
                      child: Row(
                        children: [
                          Icon(AppIcons.attachment,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: RepaintBoundary(
                        child: Image.network(
                          fullUrl,
                          fit: BoxFit.contain,
                          cacheWidth: 1080,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (ctx, err, stack) => Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppIcons.brokenImage,
                                    size: 48, color: AppColors.muted),
                                SizedBox(height: 8),
                                Text('Unable to load photo',
                                    style: TextStyle(color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black87,
              radius: 18,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(AppIcons.close, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// DEDICATED TENANT CALENDAR SHEET
// ==========================================================

class TenantCalendarSheet extends StatefulWidget {
  final TenantModel tenant;
  final bool isOwner;

  const TenantCalendarSheet({
    super.key,
    required this.tenant,
    this.isOwner = false,
  });

  static void show(BuildContext context, TenantModel tenant,
      {bool isOwner = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TenantCalendarSheet(tenant: tenant, isOwner: isOwner),
    );
  }

  @override
  State<TenantCalendarSheet> createState() => _TenantCalendarSheetState();
}

class _TenantCalendarSheetState extends State<TenantCalendarSheet> {
  bool _loading = true;
  List<TenantMonthlyStatusModel> _statuses = [];

  // Generate 12 months for the academic year (e.g., June to May of current/next year)
  late final List<DateTime> _months;

  @override
  void initState() {
    super.initState();
    _initMonths();
    _loadStatuses();
  }

  void _initMonths() {
    final now = DateTime.now();
    // Start from 12 months ago to 24 months ahead (3 years total)
    final start = DateTime(now.year, now.month - 12, 1);
    _months = List.generate(36, (index) {
      return DateTime(start.year, start.month + index, 1);
    });
  }

  Future<void> _loadStatuses() async {
    try {
      final s = context.read<AppState>();
      final list = await s.getTenantStatuses(widget.tenant.id);
      if (mounted) {
        setState(() {
          _statuses = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _getStatusForMonth(DateTime monthDate) {
    for (final st in _statuses) {
      final statusDate = DateTime.tryParse(st.monthStart);
      if (statusDate != null &&
          statusDate.year == monthDate.year &&
          statusDate.month == monthDate.month) {
        return st.status.toLowerCase();
      }
    }
    // Default to tenant's current payment status if it matches current month, else unpaid
    final now = DateTime.now();
    if (monthDate.year == now.year && monthDate.month == now.month) {
      return (widget.tenant.paymentStatus ?? 'paid').toLowerCase();
    }
    return 'unpaid';
  }

  Future<void> _changeStatus(DateTime monthDate, String newStatus) async {
    // Send as unambiguous ISO string to prevent off-by-one month bugs in backend
    final dateStr =
        '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}-01';
    try {
      await context.read<AppState>().updateTenantMonthStatus(
            widget.tenant.id,
            dateStr,
            newStatus,
          );
      await _loadStatuses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateFormat('MMMM yyyy').format(monthDate)} updated to ${newStatus.toUpperCase()}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showStatusPicker(BuildContext context, DateTime monthDate) {
    if (!widget.isOwner) return;

    final monthName = DateFormat('MMMM yyyy').format(monthDate);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Status · $monthName',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Update payment record for ${widget.tenant.fullName}',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _statusOption(ctx, monthDate, 'paid', 'Mark as Paid',
                AppColors.statusPaid, AppIcons.success),
            const SizedBox(height: 8),
            _statusOption(ctx, monthDate, 'partial', 'Mark as Partial',
                AppColors.statusPartial, AppIcons.partial),
            const SizedBox(height: 8),
            _statusOption(ctx, monthDate, 'unpaid', 'Mark as Unpaid',
                AppColors.statusUnpaid, AppIcons.cancel),
          ],
        ),
      ),
    );
  }

  Widget _statusOption(
    BuildContext ctx,
    DateTime monthDate,
    String statusValue,
    String title,
    Color color,
    IconData icon,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        _changeStatus(monthDate, statusValue);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int paidCount = 0;
    int partialCount = 0;
    int unpaidCount = 0;

    for (final m in _months) {
      final st = _getStatusForMonth(m);
      if (st == 'paid') {
        paidCount++;
      } else if (st == 'partial') {
        partialCount++;
      } else {
        unpaidCount++;
      }
    }

    final initial = widget.tenant.fullName.isNotEmpty
        ? widget.tenant.fullName.substring(0, 1).toUpperCase()
        : 'T';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surfaceElevated,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tenant.fullName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            widget.tenant.roomNumber != null
                                ? 'Room ${widget.tenant.roomNumber}'
                                : 'Not assigned',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.isOwner
                                  ? 'OWNER CONTROL'
                                  : 'TENANT CALENDAR',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.close, color: AppColors.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Stats summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _miniStat('Paid', '$paidCount', AppColors.statusPaid,
                    AppColors.statusPaidBg),
                const SizedBox(width: 8),
                _miniStat('Partial', '$partialCount', AppColors.statusPartial,
                    AppColors.statusPartialBg),
                const SizedBox(width: 8),
                _miniStat('Unpaid', '$unpaidCount', AppColors.statusUnpaid,
                    AppColors.statusUnpaidBg),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (widget.isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.tap, color: AppColors.primary, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap any month below to change its payment status.',
                        style: TextStyle(color: AppColors.text, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Month Grid
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: _months.length,
                    itemBuilder: (ctx, index) {
                      final monthDate = _months[index];
                      final monthName = DateFormat('MMMM').format(monthDate);
                      final yearStr = DateFormat('yyyy').format(monthDate);
                      final status = _getStatusForMonth(monthDate);
                      final isCurrent =
                          DateFormat('yyyy-MM').format(monthDate) ==
                              DateFormat('yyyy-MM').format(DateTime.now());

                      return InkWell(
                        onTap: widget.isOwner
                            ? () => _showStatusPicker(context, monthDate)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrent
                                  ? AppColors.primary.withValues(alpha: 0.6)
                                  : AppColors.border,
                              width: isCurrent ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          monthName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        Text(
                                          yearStr,
                                          style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.isOwner)
                                    Icon(
                                      AppIcons.edit,
                                      color: AppColors.muted,
                                      size: 14,
                                    ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  StatusPill.fromPaymentStatus(status),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'CURRENT',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// TENANT CONCERN DETAIL & STATUS SHEET
// ==========================================================

class TenantConcernDetailSheet extends StatefulWidget {
  final ConcernModel concern;
  final bool isOwner;

  const TenantConcernDetailSheet({
    super.key,
    required this.concern,
    this.isOwner = false,
  });

  static void show(BuildContext context, ConcernModel concern,
      {bool isOwner = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      barrierColor: AppTheme.scrim(kScrim),
      shape: tSheetShape,
      builder: (ctx) =>
          TenantConcernDetailSheet(concern: concern, isOwner: isOwner),
    );
  }

  @override
  State<TenantConcernDetailSheet> createState() =>
      _TenantConcernDetailSheetState();
}

class _TenantConcernDetailSheetState extends State<TenantConcernDetailSheet> {
  int? _rating;
  bool _submittingRating = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.concern.rating;
  }

  Future<void> _submitRating(int rating) async {
    if (_submittingRating || widget.isOwner || widget.concern.rating != null) {
      return;
    }

    setState(() => _submittingRating = true);
    try {
      await context
          .read<AppState>()
          .updateConcernRating(widget.concern.id, rating);
      setState(() {
        _rating = rating;
        _submittingRating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your rating!')),
        );
      }
    } catch (e) {
      setState(() => _submittingRating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to submit rating: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.concern.status.toLowerCase();
    final isResolved = status == ConcernModel.statusResolved;
    final room = widget.concern.roomNumber;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(kSheetRadius)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kHairline,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                Row(
                  children: [
                    TPill(
                      text: isResolved ? 'Resolved' : 'Pending',
                      tone: isResolved ? TPillTone.ok : TPillTone.pending,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(AppIcons.closeLine, color: kInkSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.concern.subject,
                  style: TextStyle(
                    fontSize: 22,
                    height: 27 / 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${room == null ? 'No room' : 'Room $room'} · '
                  '${tWhen(widget.concern.createdAt)}',
                  style: tMeta(),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSurfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _ConcernStep(
                        title: 'Report logged',
                        meta: tWhen(widget.concern.createdAt),
                        active: true,
                        last: false,
                      ),
                      _ConcernStep(
                        title: 'Owner notified',
                        meta: widget.concern.ownerResponse != null &&
                                widget.concern.ownerResponse!.isNotEmpty
                            ? 'A response was posted'
                            : 'Waiting for a response',
                        active: widget.concern.ownerResponse != null &&
                            widget.concern.ownerResponse!.isNotEmpty,
                        last: false,
                      ),
                      _ConcernStep(
                        title: 'Fixed',
                        meta: isResolved ? 'Marked resolved' : 'In progress',
                        active: isResolved,
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(widget.concern.details, style: tBody()),
                if (widget.concern.attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.concern.attachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final att = widget.concern.attachments[i];
                        final url = att.publicUrl ?? '';
                        final fullUrl = url.startsWith('http')
                            ? url
                            : '${AppConfig.apiBaseUrl}$url';
                        final isVideo =
                            att.mimeType?.startsWith('video') ?? false;
                        return GestureDetector(
                          onTap: isVideo
                              ? null
                              : () => ImageViewerDialog.show(
                                    context,
                                    fullUrl,
                                    title: att.fileName ?? 'Attachment',
                                  ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 64,
                              height: 64,
                              color: kMintDeep,
                              child: isVideo
                                  ? Icon(
                                      AppIcons.videoLine,
                                      color: kPrimary,
                                    )
                                  : Image.network(
                                      fullUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        AppIcons.imageLine,
                                        color: kPrimary,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kMint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OWNER RESPONSE', style: tEyebrow()),
                      const SizedBox(height: 6),
                      Text(
                        widget.concern.ownerResponse != null &&
                                widget.concern.ownerResponse!.isNotEmpty
                            ? widget.concern.ownerResponse!
                            : 'No response from your landlord yet.',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isResolved) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kHairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How did we do?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.isOwner)
                          Row(
                            children: [
                              TStars(rating: _rating ?? 0, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _rating == null
                                    ? 'Awaiting tenant rating'
                                    : '$_rating / 5',
                                style: tMeta(),
                              ),
                            ],
                          )
                        else if (_rating != null)
                          Row(
                            children: [
                              TStars(rating: _rating!, size: 20),
                              const SizedBox(width: 8),
                              Text('$_rating / 5', style: tMeta()),
                            ],
                          )
                        else if (_submittingRating)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                color: kPrimary,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              for (var i = 1; i <= 5; i++)
                                GestureDetector(
                                  onTap: () => _submitRating(i),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 4,
                                    ),
                                    child: Icon(
                                      AppIcons.starLine,
                                      color: kWarning,
                                      size: 30,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcernStep extends StatelessWidget {
  final String title;
  final String meta;
  final bool active;
  final bool last;

  const _ConcernStep({
    required this.title,
    required this.meta,
    required this.active,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? kPrimary : kMintDeep,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: kMintDeep,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(meta, style: tMeta()),
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
// BUTTONS
// ==========================================================

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedOpacity(
        opacity: enabled || loading ? 1 : 0.55,
        duration: const Duration(milliseconds: 180),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: enabled || loading
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0C5B37),
                      Color(0xFF0F7A44),
                      Color(0xFF18A55B),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  )
                : LinearGradient(
                    colors: [AppColors.borderLight, AppColors.borderLight],
                  ),
            borderRadius: BorderRadius.circular(AppColors.radiusLg - 4),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusLg - 4),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: enabled
                        ? () {
                            HapticFeedback.lightImpact();
                            onPressed!.call();
                          }
                        : null,
                    borderRadius: BorderRadius.circular(AppColors.radiusLg - 4),
                    splashColor: Colors.white.withValues(alpha: 0.14),
                    highlightColor: Colors.white.withValues(alpha: 0.05),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Row(
                                key: const ValueKey('label'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (icon != null) ...[
                                    Icon(icon, size: 19, color: Colors.white),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
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

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.surfaceSheen,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          boxShadow: AppColors.panelShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  }
                : null,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            splashColor: AppColors.primary.withValues(alpha: 0.07),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _googleIcon(),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          AppIcons.forward,
                          size: 16,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _googleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final red = Paint()..color = const Color(0xFFEA4335);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final green = Paint()..color = const Color(0xFF34A853);
    final blue = Paint()..color = const Color(0xFF4285F4);

    // Blue horizontal bar
    canvas.drawRect(
      Rect.fromLTRB(center.dx, center.dy - radius * 0.22, center.dx + radius,
          center.dy + radius * 0.22),
      blue,
    );

    // Outer colored arcs
    final strokeWidth = radius * 0.44;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final arcRect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Red arc (top)
    strokePaint.color = red.color;
    canvas.drawArc(arcRect, -3.14 * 0.75, 3.14 * 0.5, false, strokePaint);

    // Yellow arc (left)
    strokePaint.color = yellow.color;
    canvas.drawArc(arcRect, -3.14 * 1.25, 3.14 * 0.5, false, strokePaint);

    // Green arc (bottom)
    strokePaint.color = green.color;
    canvas.drawArc(arcRect, 3.14 * 0.25, 3.14 * 0.5, false, strokePaint);

    // Blue arc (right-bottom)
    strokePaint.color = blue.color;
    canvas.drawArc(arcRect, 0, 3.14 * 0.25, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================================
// BOTTOM NAVIGATION
// ==========================================================

typedef TahananNavItem = BottomNavItem;

class BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const BottomNavItem({
    required this.icon,
    IconData? activeIcon,
    required this.label,
  }) : activeIcon = activeIcon ?? icon;
}

class TahananBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  const TahananBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : AppMotion.standard;
    final count = items.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: RepaintBoundary(
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F08170F),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0x1408170F),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / count;
              final indicatorWidth = itemWidth - 8;
              return SizedBox(
                width: constraints.maxWidth,
                height: 66,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: duration,
                      curve: AppMotion.settle,
                      left: currentIndex * itemWidth + 4,
                      top: 5,
                      width: indicatorWidth,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0A4B30), Color(0xFF0F7A44)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x330A4B30),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: List.generate(count, (index) {
                          final item = items[index];
                          final selected = index == currentIndex;
                          return Expanded(
                            child: Semantics(
                              button: true,
                              selected: selected,
                              label: item.label,
                              child: PressableSurface(
                                onTap: () {
                                  if (index == currentIndex) return;
                                  onTap(index);
                                },
                                borderRadius: BorderRadius.circular(24),
                                pressedScale: 0.98,
                                highlightColor:
                                    Colors.black.withValues(alpha: 0.04),
                                semanticButton: false,
                                child: Center(
                                  child: _NavTabItem(
                                    item: item,
                                    selected: selected,
                                    reduceMotion: reduce,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final BottomNavItem item;
  final bool selected;
  final bool reduceMotion;

  const _NavTabItem({
    required this.item,
    required this.selected,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: selected ? 1 : 0),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final color = Color.lerp(
          AppColors.muted,
          Colors.white,
          t,
        )!;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: 1 + 0.06 * t,
              child: MorphIcon(
                icon: selected ? item.activeIcon : item.icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                height: 1.05,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================================
// SEGMENTED TABS
// ==========================================================

// SEGMENTED TABS
// ==========================================================

class SegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final count = tabs.length;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald900.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          height: 42,
          child: Stack(
            children: [
              // Sliding gradient pill
              AnimatedAlign(
                alignment: Alignment(
                  count <= 1 ? 0 : (selectedIndex / (count - 1)) * 2 - 1,
                  0,
                ),
                duration: reduceMotion ? Duration.zero : AppColors.normalAnim,
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: count == 0 ? 1 : 1 / count,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(tabs.length, (i) {
                  final isSelected = i == selectedIndex;
                  return Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () {
                          if (i == selectedIndex) return;
                          HapticFeedback.selectionClick();
                          onSelect(i);
                        },
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        splashColor: AppColors.primary.withValues(alpha: 0.06),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : AppColors.muted,
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              letterSpacing: 0,
                            ),
                            child: Text(
                              tabs[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// SEARCH FIELD
// ==========================================================

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const SearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search tenant by name or email',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.surfaceSheen,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          boxShadow: AppColors.panelShadow,
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.text,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            fillColor: Colors.transparent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 6, right: 2),
              child: Icon(
                AppIcons.search,
                color: AppColors.primary,
                size: 19,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 42,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      AppIcons.clear,
                      color: AppColors.muted,
                      size: 18,
                    ),
                    onPressed: () {
                      controller.clear();
                      if (onClear != null) onClear!();
                      if (onChanged != null) onChanged!('');
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// EMPTY STATE
// ==========================================================

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IdleFloat(
              amplitude: 4,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.10),
                      AppColors.primary.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: AppColors.mintGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.panelShadow,
                  ),
                  child: Icon(icon, color: AppColors.emerald700, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.25,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onAction!.call();
                },
                icon: const Icon(AppIcons.addHouse, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header used across dashboards: icon tile + title + action.
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Color? iconBackground;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient:
                iconBackground == null ? AppColors.mintGradientSoft : null,
            color: iconBackground,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor ?? AppColors.emerald700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: AppColors.text,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onAction!.call();
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.fromLTRB(11, 6, 7, 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      AppIcons.chevron,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==========================================================
// SCREEN HEADER (emerald hero)
// ==========================================================

/// A deep-emerald hero panel used at the top of the primary screens.
///
/// Keeps all decoration in a single [RepaintBoundary] and uses only
/// transforms/opacity, so scrolling past it stays at 60fps.
class ScreenHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final String avatarText;
  final IconData? leadingIcon;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBell;
  final int badgeCount;
  final VoidCallback? onBell;
  final VoidCallback? onAvatar;
  final VoidCallback? onTitleTap;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.avatarText = '',
    this.leadingIcon,
    this.onBack,
    this.trailing,
    this.subtitle,
    this.showBell = false,
    this.badgeCount = 0,
    this.onBell,
    this.onAvatar,
    this.onTitleTap,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(18, 17, 16, 18),
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        avatarText.isNotEmpty ? avatarText.substring(0, 1).toUpperCase() : 'U';

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald900.withValues(alpha: 0.22),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: AppColors.emerald900.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          child: Stack(
            children: [
              // Warm lime glow, bottom-right.
              Positioned(
                right: -70,
                bottom: -90,
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.lime.withValues(alpha: 0.14),
                          AppColors.lime.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: AppColors.heroSheen),
                  ),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _HeaderPatternPainter()),
                ),
              ),
              Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (onBack != null) ...[
                          Pressable(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onBack!();
                            },
                            pressedScale: 0.90,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                AppIcons.back,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Pressable(
                          onTap: onAvatar,
                          pressedScale: 0.92,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: leadingIcon != null
                                  ? BorderRadius.circular(15)
                                  : null,
                              shape: leadingIcon != null
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald900
                                      .withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: leadingIcon != null
                                ? Icon(
                                    leadingIcon,
                                    color: AppColors.lime,
                                    size: 21,
                                  )
                                : Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: AppColors.lime,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        eyebrow.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.80,
                                          ),
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: onTitleTap,
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 19.5,
                                          height: 1.22,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.55,
                                        ),
                                      ),
                                    ),
                                    if (onTitleTap != null) ...[
                                      const SizedBox(width: 2),
                                      Icon(
                                        AppIcons.expand,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        size: 20,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                        if (showBell)
                          _HeaderBell(
                            count: badgeCount,
                            onTap: onBell,
                          ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 11),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppColors.surface.withValues(alpha: 0.72),
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.05,
                        ),
                      ),
                    ],
                    if (footer != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.055),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: footer!,
                      ),
                    ],
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

class _HeaderBell extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _HeaderBell({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.notifications,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -3,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.emerald800, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: TextStyle(
                  color: AppColors.emerald900,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Metric used inside a [ScreenHeader]'s footer.
class HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? accent;
  final Color? valueColor;
  final Color? labelColor;

  /// When set, the value counts up from zero instead of snapping into place.
  /// [value] is still used for layout parity and semantics.
  final int? number;

  const HeroStat({
    super.key,
    required this.value,
    required this.label,
    this.accent,
    this.valueColor,
    this.labelColor,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: accent ?? valueColor ?? Colors.white,
      fontSize: 19,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (number != null)
            CountUp(
              value: number!,
              style: style,
              duration: AppColors.slowAnim,
            )
          else
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor ?? Colors.white.withValues(alpha: 0.62),
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical hairline used between [HeroStat]s.
class HeroDivider extends StatelessWidget {
  final Color? color;

  const HeroDivider({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white.withValues(alpha: 0.20);
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.withValues(alpha: 0.02),
            c,
            c.withValues(alpha: 0.02),
          ],
        ),
      ),
    );
  }
}

/// Compact quick-action button used on dashboards.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? tint;

  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.emerald700;

    return Pressable(
      enabled: onTap != null,
      pressedScale: 0.93,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(AppColors.surface, color, 0.17)!,
                        Color.lerp(AppColors.surface, color, 0.05)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
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

/// Top navigation bar for pushed detail / workflow screens.
///
/// Pairs a tactile squircle back button with an optional eyebrow label,
/// crisp title, and optional trailing action widget.
class PageHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final VoidCallback? onBack;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.onBack,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Pressable(
            onTap: () {
              HapticFeedback.selectionClick();
              if (onBack != null) {
                onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            pressedScale: 0.91,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppColors.surfaceSheen,
                borderRadius: BorderRadius.circular(15),
                boxShadow: AppColors.panelShadow,
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.back,
                color: AppColors.text,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          eyebrow!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Consistent header chrome for modal bottom sheets.
class SheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBg;
  final Widget? trailing;
  final bool showClose;

  SheetHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.iconBg,
    this.trailing,
    this.showClose = true,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = iconColor ?? AppColors.primary;
    final resolvedBg = iconBg ?? AppColors.primarySoft;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: AppColors.borderLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            IconTile(
              icon: icon,
              color: resolvedColor,
              background: resolvedBg,
              size: 44,
              iconSize: 21,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (showClose) ...[
              const SizedBox(width: 8),
              Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).maybePop();
                },
                pressedScale: 0.90,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.close,
                    size: 16,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Tactile square `-` / `+` button used alongside numeric fields.
class StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const StepperButton({
    super.key,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      enabled: enabled,
      pressedScale: 0.90,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.mintGradient : null,
          color: enabled ? null : AppColors.surface2,
          borderRadius: BorderRadius.circular(13),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.emerald700 : AppColors.muted,
        ),
      ),
    );
  }
}

class _HeaderPatternPainter extends CustomPainter {
  const _HeaderPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.055);

    final center = Offset(size.width * 1.02, -size.height * 0.10);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, 34.0 * i, ring);
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.lime.withValues(alpha: 0.20),
          AppColors.lime.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(-size.width * 0.05, size.height * 1.05),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(-size.width * 0.05, size.height * 1.05),
      size.width * 0.55,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
