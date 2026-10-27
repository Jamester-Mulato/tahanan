import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/app_motion.dart';
import '../core/design_tokens.dart';
import 'app_icons.dart';
import 'lottie_art.dart';
import 'pressable.dart';
import 'motion.dart';

/// Exact visual primitives for the Tahanan reference design:
/// white/mint canvas, emerald heroes, flat 24px cards and pill controls.
///
/// This file is intentionally independent of the older `ui.dart` system so
/// screens can adopt the reference layout without changing business logic.

const double kGutter = 20;
const double kCardRadius = 24;
const double kHeroRadius = 34;
const double kSheetRadius = 28;
Color get kCanvasTop => AppColors.backgroundGradientTop;
Color get kCanvasBottom => AppColors.backgroundGradientBottom;
Color get kSurfaceAlt => AppColors.surface2;
Color get kMint => AppColors.mint100;
Color get kMintDeep => AppColors.mint200;
Color get kInkMuted => AppColors.muted;
Color get kInkSoft => AppColors.textSecondary;
Color get kHairline => AppColors.border;
Color get kDeep => AppColors.primaryDark;
Color get kForest => AppColors.emerald800;
Color get kPrimary => AppColors.primary;
Color get kLime => AppColors.lime;
Color get kHeroMuted => AppColors.heroMuted;
Color get kWarning => AppColors.warning;
Color get kDanger => AppColors.danger;
Color get kInfo => AppColors.info;

// Telegram-flat: surfaces are separated by hairlines and air, not by heavy
// floating shadows. Depth is reserved for the hero and pressed states.
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x0808170F), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0D08170F), blurRadius: 12, offset: Offset(0, 4)),
];

const LinearGradient kHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF06301D), Color(0xFF0A4B30), Color(0xFF0F7A44)],
);

LinearGradient kButtonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kForest, kPrimary],
);

EdgeInsets tScreenPadding(BuildContext context,
    {double top = 20, double bottom = 110}) {
  return EdgeInsets.fromLTRB(
    kGutter,
    MediaQuery.paddingOf(context).top + top,
    kGutter,
    bottom,
  );
}

/// Display type: Plus Jakarta Sans carries every heading, numeral and label
/// that should read as *actually* bold. Inter stays for reading copy so the
/// contrast between statement and explanation is intentional, never uniform.
TextStyle tEyebrow({Color? color}) => AppType.eyebrow.copyWith(
      color: color ?? AppColors.primary,
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.45,
    );

TextStyle tScreenTitle({Color? color}) => AppType.h1.copyWith(
      color: color ?? AppColors.text,
      fontSize: 28,
      height: 1.08,
      letterSpacing: -1.05,
    );

TextStyle tSectionTitle({Color? color}) => AppType.h2.copyWith(
      color: color ?? AppColors.text,
      fontSize: 19,
      height: 1.18,
      letterSpacing: -0.55,
    );

TextStyle tCardTitle({Color? color}) => AppType.h3.copyWith(
      color: color ?? AppColors.text,
      fontSize: 16,
      height: 1.3,
      letterSpacing: -0.35,
    );

TextStyle tBody({Color? color}) => AppType.body.copyWith(
      color: color ?? AppColors.text,
      fontSize: 13.5,
      height: 1.5,
      fontWeight: FontWeight.w400,
    );

TextStyle tMeta({Color? color}) => AppType.caption.copyWith(
      color: color ?? AppColors.muted,
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w500,
    );

TextStyle tStat({Color? color}) => TextStyle(
      color: color ?? AppColors.text,
      fontFamily: AppType.displayFamily,
      fontSize: 26,
      height: 1.05,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.9,
      fontFeatures: [FontFeature.tabularFigures()],
    );

TextStyle tLabel({Color? color}) => TextStyle(
      color: color ?? AppColors.text,
      fontFamily: AppType.displayFamily,
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    );

// ==========================================================
// AMBIENT MOTION
// ==========================================================

/// Slow Lottie artwork that lives *inside* a surface, behind its content.
///
/// The bundled compositions are 320 × 320 artboards. The whole artboard is
/// stretched to the surface's exact rectangle (`BoxFit.fill`), so the JSON's
/// own edge sits precisely on the card edge and never shows as a square
/// floating inside it. Callers must give this layer the full card bounds
/// (`Positioned.fill` over an unpadded `Stack`), not a padded content box.
class TAmbient extends StatefulWidget {
  final String art;
  final double opacity;
  final double size;
  final Alignment alignment;

  const TAmbient({
    super.key,
    this.art = 'flow',
    this.opacity = 0.9,
    this.size = 340,
    this.alignment = Alignment.topRight,
  });

  @override
  State<TAmbient> createState() => _TAmbientState();
}

class _TAmbientState extends State<TAmbient> {
  /// Width/height of every bundled Lottie composition.
  static const double _artboard = 320;

  final _visibilityKey = UniqueKey();

  /// Start on: above-the-fold surfaces should animate immediately. The first
  /// visibility callback pauses anything that is actually offscreen.
  bool _visible = true;

  Widget _art({required bool animate}) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: _artboard,
          height: _artboard,
          child: LottieArt(widget.art, size: _artboard, animate: animate),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return IgnorePointer(
        child: Opacity(
          opacity: widget.opacity,
          child: _art(animate: false),
        ),
      );
    }

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0.01;
        if (visible != _visible) {
          setState(() => _visible = visible);
        }
      },
      child: IgnorePointer(
        child: Opacity(
          opacity: widget.opacity,
          child: _visible ? _art(animate: true) : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ==========================================================
// CANVAS
// ==========================================================

class TCanvas extends StatelessWidget {
  final Widget child;

  const TCanvas({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kCanvasTop, kCanvasBottom],
        ),
      ),
      child: child,
    );
  }
}

// ==========================================================
// CARD
// ==========================================================

class TCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final bool shadow;
  final Border? border;

  /// Which bundled Lottie file drifts behind the card content. Pass `null`
  /// to opt out (for dense lists where motion would be noise).
  final String? ambient;
  final double ambientOpacity;
  final Alignment ambientAlignment;

  const TCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.gradient,
    this.onTap,
    this.onLongPress,
    this.radius = kCardRadius,
    this.shadow = true,
    this.border,
    this.ambient = 'flow',
    this.ambientOpacity = 0.16,
    this.ambientAlignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    final useColor = color != null && color != Colors.white;

    final card = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: gradient == null && useColor ? color : null,
          gradient: gradient ?? (useColor ? null : AppColors.cardGradient),
          borderRadius: shape,
          border: border ??
              Border.all(
                color: (AppColors.dark
                    ? AppColors.border.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9)),
                width: 1.1,
              ),
          boxShadow: shadow ? AppShadows.soft : null,
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: shape,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x16FFFFFF), Color(0x00FFFFFF)],
                        stops: [0.0, 0.55],
                      ),
                    ),
                  ),
                ),
              ),
              if (ambient != null)
                Positioned.fill(
                  child: TAmbient(
                    art: ambient!,
                    opacity: ambientOpacity,
                    size: 430,
                    alignment: ambientAlignment,
                  ),
                ),
              content,
            ],
          ),
        ),
      ),
    );

    if (onTap == null && onLongPress == null) return card;
    return PressableSurface(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: shape,
      pressedScale: AppMotion.cardPressScale,
      highlightColor: Colors.black.withValues(alpha: 0.035),
      child: card,
    );
  }
}

// ==========================================================
// STATS
// ==========================================================

class TStatData {
  final String value;
  final String label;

  const TStatData(this.value, this.label);
}

class TStatRow extends StatelessWidget {
  final List<TStatData> stats;
  final bool onHero;

  const TStatRow({super.key, required this.stats, this.onHero = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++)
          Expanded(
            child: Column(
              children: [
                _StatValue(
                  value: stats[i].value,
                  color: onHero ? Colors.white : AppColors.text,
                ),
                const SizedBox(height: 2),
                Text(
                  stats[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tMeta(
                    color: onHero ? kHeroMuted : kInkMuted,
                  ).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Numeric stat text that counts up once on mount (and on value changes),
/// while non-numeric values such as currency strings stay static.
class _StatValue extends StatelessWidget {
  final String value;
  final Color color;

  const _StatValue({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = tStat(color: color);
    final numeric = int.tryParse(value);
    if (numeric == null || MediaQuery.disableAnimationsOf(context)) {
      return Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: numeric.toDouble()),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '${v.round()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

// ==========================================================
// HEADERS
// ==========================================================

class TLightHeader extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<TStatData> stats;

  const TLightHeader({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.stats = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF052E1C), Color(0xFF0A4B30), Color(0xFF0F7A44)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F7A44),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -90,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kLime.withValues(alpha: 0.24),
                      kLime.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -70,
            bottom: -110,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF14B8A6).withValues(alpha: 0.16),
                      const Color(0xFF14B8A6).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: TAmbient(
              art: 'aurora',
              opacity: 0.5,
              size: 460,
              alignment: Alignment.bottomRight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(icon, size: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    eyebrow.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: tEyebrow().copyWith(
                      color: kLime,
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: tScreenTitle().copyWith(
                      color: Colors.white,
                      fontSize: 25,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: tMeta().copyWith(
                        color: const Color(0xFFD7EADF),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: TStatRow(stats: stats, onHero: true),
                    ),
                  ],
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
// BACK NAVIGATION
// ==========================================================

/// Floating back control for pushed screens. Hidden automatically on tab
/// screens that are not inside a route stack.
class TBackButton extends StatelessWidget {
  final String semanticsLabel;

  const TBackButton({super.key, this.semanticsLabel = 'Back'});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();

    return PressableSurface(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).maybePop();
      },
      borderRadius: BorderRadius.circular(999),
      pressedScale: 0.94,
      highlightColor: Colors.black.withValues(alpha: 0.04),
      semanticsLabel: semanticsLabel,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          border: Border.all(color: kHairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1408170F),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          AppIcons.back,
          size: 21,
          color: AppColors.text,
        ),
      ),
    );
  }
}

/// A left-aligned back rail. The whole widget collapses when this screen is
/// not pushed, so tab variants stay flush.
class TBackRow extends StatelessWidget {
  final String semanticsLabel;

  const TBackRow({super.key, this.semanticsLabel = 'Back'});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TBackButton(semanticsLabel: semanticsLabel),
      ),
    );
  }
}

class TIconSquare extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;
  final bool dark;

  /// Optional hairline edge; defaults to transparent so flat tiles stay
  /// flat while bordered variants share one language with [IconTile].
  final Color? borderColor;

  TIconSquare({
    super.key,
    required this.icon,
    this.size = AppColors.tileMd,
    this.color,
    this.background,
    this.dark = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.primary;
    final resolvedBg = background ?? AppColors.primarySoft;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? kDeep : resolvedBg,
        borderRadius: BorderRadius.circular(size * AppColors.tileRadiusRatio),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Icon(
        icon,
        size: size * AppColors.tileIconRatio,
        color: dark ? kLime : resolvedColor,
      ),
    );
  }
}

const List<Color> _avatarColors = [
  Color(0xFF0F7A44),
  Color(0xFF0C5634),
  Color(0xFF0A4B30),
];

class TAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool square;

  const TAvatar({
    super.key,
    required this.name,
    this.size = AppColors.tileMd,
    this.square = false,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'T';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[name.hashCode.abs() % _avatarColors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square
            ? BorderRadius.circular(size * AppColors.tileRadiusRatio)
            : null,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.33,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// ==========================================================
// PILLS / CHIPS
// ==========================================================

enum TPillTone { ok, pending, bad, info, neutral, dark, lime }

class TPill extends StatelessWidget {
  final String text;
  final TPillTone tone;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const TPill({
    super.key,
    required this.text,
    this.tone = TPillTone.neutral,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TPillTone.ok => (AppColors.statusPaidBg, AppColors.statusPaid),
      TPillTone.pending => (AppColors.statusPartialBg, AppColors.statusPartial),
      TPillTone.bad => (AppColors.dangerBg, AppColors.danger),
      TPillTone.info => (AppColors.infoBg, AppColors.info),
      TPillTone.dark => (kForest, Colors.white),
      TPillTone.lime => (kLime, const Color(0xFF0A3D26)),
      TPillTone.neutral => (kSurfaceAlt, kInkMuted),
    };

    final child = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null) return child;
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      pressedScale: 0.96,
      highlightColor: Colors.black.withValues(alpha: 0.05),
      semanticsLabel: text,
      // Keep the 48px touch target without inflating the visual pill.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppColors.tapTargetMin),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}

class TSolidPill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const TSolidPill({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppColors.tapTargetMin),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? kForest : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? kForest : kHairline,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : kInkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TSegmented extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const TSegmented({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: tabs[i],
                child: GestureDetector(
                  onTap: () {
                    if (i == selectedIndex) return;
                    HapticFeedback.selectionClick();
                    onSelect(i);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppColors.tapTargetMin,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color:
                            i == selectedIndex ? kForest : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tabs[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i == selectedIndex ? Colors.white : kInkMuted,
                          fontFamily: AppType.displayFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
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
// BUTTONS
// ==========================================================

enum TButtonVariant { primary, secondary, danger }

class TButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final TButtonVariant variant;

  const TButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.height = 54,
    this.variant = TButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(999);

    final (bg, fg, gradient) = switch (variant) {
      TButtonVariant.primary => (kPrimary, Colors.white, kButtonGradient),
      TButtonVariant.secondary => (kMint, kPrimary, null),
      TButtonVariant.danger => (AppColors.dangerBg, AppColors.danger, null),
    };

    final highlight = gradient == null
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.10);

    return PressableSurface(
      enabled: enabled,
      onTap: enabled ? onPressed : null,
      borderRadius: radius,
      pressedScale: AppMotion.pressScale,
      highlightColor: highlight,
      semanticsLabel: text,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: gradient == null ? bg : null,
            gradient: gradient,
            borderRadius: radius,
            boxShadow: gradient == null
                ? null
                : [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(icon, size: 22, color: fg),
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
// PROGRESS / DOTS
// ==========================================================

class TProgress extends StatelessWidget {
  final double value;
  final double height;
  final Color color;
  final Color track;
  final bool animate;

  TProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.color = const Color(0xFF0F7A44),
    this.track = const Color(0xFFD3F3DF),
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final bar = FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: clamped,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(99),
      ),
      child: animate
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            )
          : bar,
    );
  }
}

class TBedDots extends StatelessWidget {
  final int capacity;
  final int occupied;
  final double size;

  const TBedDots({
    super.key,
    required this.capacity,
    required this.occupied,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < capacity; i++)
          Container(
            width: size,
            height: size,
            margin: EdgeInsets.only(right: i == capacity - 1 ? 0 : 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < occupied ? kPrimary : kMintDeep,
            ),
          ),
      ],
    );
  }
}

// ==========================================================
// LIST ROWS
// ==========================================================

class TPersonRow extends StatelessWidget {
  final String name;
  final String? meta;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double avatarSize;

  const TPersonRow({
    super.key,
    required this.name,
    this.meta,
    this.trailing,
    this.onTap,
    this.avatarSize = 42,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        TAvatar(name: name, size: avatarSize),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              if (meta != null) ...[
                const SizedBox(height: 2),
                Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tMeta(),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );

    if (onTap == null) return content;
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      highlightColor: Colors.black.withValues(alpha: 0.035),
      semanticsLabel: name,
      child: content,
    );
  }
}

class TSettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool first;

  const TSettingRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: kHairline)),
      ),
      child: Row(
        children: [
          TIconSquare(icon: icon, size: 36, background: kMint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),
          ),
          Icon(AppIcons.chevron, size: 22, color: kInkMuted),
        ],
      ),
    );
    if (onTap == null) return content;
    return PressableSurface(
      onTap: onTap,
      semanticsLabel: label,
      highlightColor: Colors.black.withValues(alpha: 0.035),
      child: content,
    );
  }
}

class TFactRow extends StatelessWidget {
  final String label;
  final String value;

  const TFactRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: kHairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tMeta()),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// CAPSULE ACTIONS
// ==========================================================

class TEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const TEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          LottieArt('empty', size: 112),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.h3.copyWith(fontSize: 15.5),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: tMeta(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Static-look skeleton line. Delegates to the canonical animated
/// [SkeletonBox] so loading placeholders share one shimmer; honors
/// reduced motion automatically.
class TKeyStrip extends StatelessWidget {
  final String keyText;
  final VoidCallback onCopy;
  final String label;

  const TKeyStrip({
    super.key,
    required this.keyText,
    required this.onCopy,
    this.label = 'House key',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppColors.dark ? const Color(0xFF0C3B26) : kDeep,
        borderRadius: BorderRadius.circular(14),
        border: AppColors.dark
            ? Border.all(color: AppColors.border.withValues(alpha: 0.6))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            CustomPaint(
              size: const Size(double.infinity, 2),
              painter: _DashedLinePainter(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: tEyebrow(color: kHeroMuted)
                              .copyWith(fontSize: 10.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          keyText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Copy house key',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onCopy,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kLime,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              AppIcons.copy,
                              size: 18,
                              color: const Color(0xFF0A3D26),
                            ),
                          ),
                        ),
                      ),
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

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (!size.width.isFinite || size.width <= 0) return;
    final paint = Paint()
      ..color = kHairline.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset(x + dash, 1), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================================
// CARDS FOR CONCERNS & NOTICES
// ==========================================================

class TConcernCard extends StatelessWidget {
  final String subject;
  final String meta;
  final IconData icon;
  final String statusText;
  final TPillTone statusTone;
  final int? rating;
  final VoidCallback? onTap;

  const TConcernCard({
    super.key,
    required this.subject,
    required this.meta,
    required this.icon,
    required this.statusText,
    required this.statusTone,
    this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TIconSquare(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 20 / 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tMeta()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TPill(text: statusText, tone: statusTone),
              const Spacer(),
              if (rating != null) TStars(rating: rating!),
            ],
          ),
        ],
      ),
    );
  }
}

class TStars extends StatelessWidget {
  final int rating;
  final double size;

  const TStars({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    // Meaning cross-fades on change instead of snapping: filled star for
    // earned points, outlined star for the remainder (canonical taxonomy).
    return AnimatedSwitcher(
      duration: AppColors.stateAnim,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Row(
        key: ValueKey(rating),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= rating ? AppIcons.star : AppIcons.starLine,
              size: size,
              color: kWarning,
            ),
        ],
      ),
    );
  }
}

class TNoticeRow extends StatelessWidget {
  final String date;
  final String title;
  final VoidCallback? onTap;

  const TNoticeRow({
    super.key,
    required this.date,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date, style: tMeta()),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 20 / 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// SHEETS / SNACKS / DIALOGS
// ==========================================================

const Color kScrim = Color(0x7308170F);

ShapeBorder get tSheetShape => const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kSheetRadius)),
    );

Widget tSheetBody(BuildContext context, Widget child) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kHairline,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: child,
          ),
        ),
      ],
    ),
  );
}

void showTSnack(
  BuildContext context,
  String message, {
  IconData icon = AppIcons.check,
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.dark ? const Color(0xFF123322) : kDeep,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Row(
        children: [
          Icon(icon, size: 22, color: error ? const Color(0xFFFFB4AB) : kLime),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool> tConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String cancel = 'Cancel',
  String confirm = 'Confirm',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppTheme.scrim(kScrim),
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(message, style: tBody(color: kInkMuted)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TButton(
                    text: cancel,
                    variant: TButtonVariant.secondary,
                    height: 48,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TButton(
                    text: confirm,
                    variant:
                        danger ? TButtonVariant.danger : TButtonVariant.primary,
                    height: 48,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

// ==========================================================
// MISC
// ==========================================================

String tTimeAgo(DateTime? date) {
  if (date == null) return 'Just now';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String tShortDate(DateTime? date) {
  if (date == null) return 'Today';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String tWhen(DateTime? date) {
  if (date == null) return 'Just now';
  final now = DateTime.now();
  final local = date.toLocal();
  final h =
      local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
  final m = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  final time = '$h:$m $ampm';
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) return 'Today, $time';
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Yesterday, $time';
  }
  return '${tShortDate(local)}, $time';
}

class TRing extends StatelessWidget {
  final double value;
  final String label;
  final double size;
  final double stroke;

  const TRing({
    super.key,
    required this.value,
    required this.label,
    this.size = 84,
    this.stroke = 8,
  });

  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value: pct, stroke: stroke),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.text,
              fontSize: size * 0.27,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;

  const _RingPainter({required this.value, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..color = kMintDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = kPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708,
        6.28318 * value,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.stroke != stroke;
}
