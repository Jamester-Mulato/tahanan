import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/design_tokens.dart';
import '../lottie_art.dart';

// ==============================================================
// BACKDROP
// ==============================================================

/// Full-bleed animated backdrop: layered aurora light, a slow conic sheen and
/// a static film grain. Only transforms and opacity animate.
class AuroraBackdrop extends StatefulWidget {
  final Widget child;
  final bool animate;

  const AuroraBackdrop({super.key, required this.child, this.animate = true});

  @override
  State<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends State<AuroraBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppTime.ambient,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!widget.animate || reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.dark
                  ? const [
                      Color(0xFF0A120D),
                      Color(0xFF08100B),
                      Color(0xFF0E1812),
                    ]
                  : [
                      Color(0xFFFFFFFF),
                      Color(0xFFF3F9F5),
                      AppColors.surfaceElevated,
                    ],
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _AuroraOrbsPainter(_c),
              isComplex: true,
              willChange: true,
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: GrainOverlay()),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// One painter for every ambient orb: the controller repaints a single layer
/// instead of rebuilding a widget tree four times per frame.
class _AuroraOrbsPainter extends CustomPainter {
  _AuroraOrbsPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static final _orbs = <_AuroraOrb>[
    _AuroraOrb(
      size: 560,
      center: const Offset(100, 60),
      drift: const Offset(34, 26),
      phase: 0,
      color: const Color(0x2A22C55E),
    ),
    _AuroraOrb(
      size: 520,
      center: const Offset(480, 720),
      drift: const Offset(30, 34),
      phase: 1.1,
      color: const Color(0x30C7F26A),
      invert: true,
    ),
    _AuroraOrb(
      size: 420,
      center: const Offset(90, 970),
      drift: const Offset(22, 30),
      phase: 2.3,
      color: const Color(0x1F14B8A6),
      invert: true,
    ),
    _AuroraOrb(
      size: 360,
      center: const Offset(440, 100),
      drift: const Offset(26, 22),
      phase: 0.9,
      color: const Color(0x1A38BDF8),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * math.pi * 2;
    for (final orb in _orbs) {
      final dx = math.sin(t + orb.phase) * orb.drift.dx;
      final dy =
          (orb.invert ? math.sin : math.cos)(t + orb.phase) * orb.drift.dy;
      canvas.save();
      canvas.translate(orb.center.dx + dx, orb.center.dy + dy);
      canvas.drawCircle(Offset.zero, orb.size / 2, orb.paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraOrbsPainter oldDelegate) => false;
}

class _AuroraOrb {
  final double size;
  final Offset center;
  final Offset drift;
  final double phase;
  final bool invert;
  final Paint paint;

  _AuroraOrb({
    required this.size,
    required this.center,
    required this.drift,
    required this.phase,
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

/// Deterministic film grain, painted once per size.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GrainPainter(), size: Size.infinite);
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0808170F);
    final random = math.Random(7);
    final count = (size.width * size.height / 9000).clamp(80, 900).toInt();
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width,
            random.nextDouble() * size.height),
        0.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}

// ==============================================================
// SURFACES
// ==============================================================

/// Frosted glass panel with a gradient hairline and optional brand glow.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double tint;
  final bool glow;
  final Color? borderColor;
  final Gradient? gradient;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.radius = AppRadius.xxl,
    this.blur = 16,
    this.tint = 0.78,
    this.glow = false,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: glow ? AppShadows.glow : AppShadows.floating,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur.clamp(0.0, 18.0).toDouble(),
            sigmaY: blur.clamp(0.0, 18.0).toDouble(),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surface.withValues(alpha: tint),
                      AppColors.surface2.withValues(alpha: tint),
                    ],
                  ),
              border: Border.all(
                color: borderColor ??
                    (AppColors.dark
                        ? AppColors.border.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.75)),
                width: 1.1,
              ),
            ),
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
                          colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
                          stops: [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-pixel gradient border that catches the light at the top edge.
class GradientHairline extends StatelessWidget {
  final Widget child;
  final double radius;

  const GradientHairline({
    super.key,
    required this.child,
    this.radius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x6634D399),
            Color(0x14FFFFFF),
            Color(0x33A3D84A),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: child,
      ),
    );
  }
}

// ==============================================================
// HEADINGS
// ==============================================================

class SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool onDark;

  const SectionHeading({
    super.key,
    this.eyebrow = '',
    required this.title,
    this.subtitle,
    this.action,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppType.h2.copyWith(
      color: onDark ? Colors.white : AppColors.text,
    );
    final subStyle = AppType.caption.copyWith(
      color: onDark ? const Color(0xFFC9E2D5) : AppColors.muted,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow.isNotEmpty) ...[
                Text(
                  eyebrow.toUpperCase(),
                  style: AppType.eyebrow.copyWith(
                    color: onDark ? const Color(0xFFC7F26A) : null,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(title, style: titleStyle),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: subStyle),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

// ==============================================================
// FIELDS
// ==============================================================

/// Field with a floating label, focus glow, icon colour shift and inline error.
class PremiumField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool required;
  final bool optional;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? error;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final int maxLines;

  const PremiumField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.required = false,
    this.optional = false,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.error,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.maxLines = 1,
  });

  @override
  State<PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<PremiumField> {
  FocusNode? _internal;
  bool _focused = false;

  FocusNode get _focus => widget.focusNode ?? (_internal ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _internal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null && widget.error!.isNotEmpty;
    final accent = hasError ? AppColors.danger : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            if (widget.required)
              Text(
                ' *',
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              )
            else if (widget.optional)
              Text(
                ' optional',
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: AppTime.fast,
          curve: AppCurves.emphasized,
          decoration: BoxDecoration(
            borderRadius: AppRadius.rMd,
            color: widget.enabled ? AppColors.surface : AppColors.surface2,
            border: Border.all(
              color: hasError
                  ? AppColors.danger.withValues(alpha: 0.55)
                  : _focused
                      ? AppColors.primary.withValues(alpha: 0.55)
                      : AppColors.border,
              width: _focused || hasError ? 1.4 : 1.0,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              AnimatedSwitcher(
                duration: AppTime.fast,
                child: Icon(
                  widget.icon,
                  key: ValueKey(_focused || hasError),
                  size: 19,
                  color:
                      _focused || hasError ? accent : const Color(0xFF8AA395),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  obscureText: widget.obscure,
                  autocorrect: false,
                  enableSuggestions: !widget.obscure,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  autofillHints: widget.autofillHints,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  maxLines: widget.maxLines,
                  style: AppType.bodyStrong.copyWith(fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintStyle: AppType.body.copyWith(
                      color: const Color(0xFF9AB0A3),
                      fontWeight: FontWeight.w500,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                widget.suffix!,
                const SizedBox(width: 4),
              ] else
                const SizedBox(width: 12),
            ],
          ),
        ),
        AnimatedSize(
          duration: AppTime.fast,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(
                    widget.error!,
                    style: AppType.caption.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ==============================================================
// BUTTONS
// ==============================================================

/// Primary action with a moving sheen and a tactile press.
class SheenButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;
  final Gradient? gradient;

  const SheenButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 56,
    this.gradient,
  });

  @override
  State<SheenButton> createState() => _SheenButtonState();
}

class _SheenButtonState extends State<SheenButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    _sheen.repeat();
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.text,
      child: _PressScale(
        enabled: enabled,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          duration: AppTime.fast,
          opacity: enabled ? 1 : 0.55,
          child: Container(
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: AppRadius.rPill,
              gradient: widget.gradient ??
                  const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0B4D2F),
                      Color(0xFF0F7A44),
                      Color(0xFF16A356)
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
              boxShadow: AppShadows.glow,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!reduce)
                  AnimatedBuilder(
                    animation: _sheen,
                    builder: (context, _) {
                      final x = -1.4 + _sheen.value * 2.8;
                      return ClipRRect(
                        borderRadius: AppRadius.rPill,
                        child: Transform.translate(
                          offset: Offset(x * 220, 0),
                          child: Container(
                            width: 120,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x00FFFFFF),
                                  Color(0x33FFFFFF),
                                  Color(0x00FFFFFF)
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Center(
                  child: widget.loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.text,
                              style: AppType.bodyStrong.copyWith(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                            if (widget.icon != null) ...[
                              const SizedBox(width: 8),
                              Icon(widget.icon, size: 20, color: Colors.white),
                            ],
                          ],
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

class _PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback? onTap;

  const _PressScale({
    required this.child,
    required this.enabled,
    this.onTap,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: widget.enabled ? () => setState(() => _down = false) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.enabled
          ? () {
              Haptics.tap();
              widget.onTap?.call();
            }
          : null,
      child: AnimatedScale(
        duration: AppTime.instant,
        curve: AppCurves.emphasized,
        scale: _down ? 0.975 : 1,
        child: widget.child,
      ),
    );
  }
}

// ==============================================================
// SELECTORS
// ==============================================================

/// Two-option segmented control with a sliding indicator.
class PillSelector extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  const PillSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadius.rPill,
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppTime.normal,
                curve: AppCurves.emphasized,
                left: width * selected,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.rPill,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0B4D2F), Color(0xFF0F7A44)],
                    ),
                    boxShadow: AppShadows.soft,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < options.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == selected,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Haptics.tap();
                            onSelect(i);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: AppTime.normal,
                                style: AppType.caption.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: i == selected
                                      ? Colors.white
                                      : AppColors.muted,
                                ),
                                child: Text(options[i]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==============================================================
// MOTION
// ==============================================================

/// Staggered entrance: fade + rise, optional horizontal drift.
class Reveal extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final double offset;
  final bool horizontal;

  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTime.entrance,
      curve: AppCurves.emphasizedDecel,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: horizontal
                ? Offset((1 - value) * offset, 0)
                : Offset(0, (1 - value) * offset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ==============================================================
// DATA DISPLAY
// ==============================================================

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? delta;
  final Color? accent;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.delta,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.lg,
      blur: 12,
      tint: 0.7,
      glow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.rXs,
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const Spacer(),
              if (delta != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: AppRadius.rPill,
                  ),
                  child: Text(
                    delta!,
                    style: AppType.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F7A44),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppType.h2.copyWith(fontSize: 24, letterSpacing: -0.8),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption),
        ],
      ),
    );
  }
}

class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  Sparkline({
    super.key,
    required this.values,
    this.color = const Color(0xFF0F7A44),
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparkPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final span =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - minValue) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.color != color;
}

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String lottie;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.lottie = 'empty',
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LottieArt(lottie, size: 150),
            const SizedBox(height: 8),
            Text(title, style: AppType.h3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AppType.body, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              SheenButton(text: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  final String text;
  final Color color;

  const TagChip(
      {super.key, required this.text, this.color = const Color(0xFF0F7A44)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.rPill,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: AppType.caption.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Circular progress used for lockouts and uploads.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Widget? child;

  ProgressRing({
    super.key,
    required this.value,
    this.size = 88,
    this.stroke = 8,
    this.color = const Color(0xFF0F7A44),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: AppTime.slow,
        curve: AppCurves.emphasized,
        builder: (context, animated, _) {
          return CustomPaint(
            painter: _RingPainter(animated, stroke, color),
            child: Center(child: child),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color color;

  _RingPainter(this.value, this.stroke, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}

class AvatarBubble extends StatelessWidget {
  final String initials;
  final double size;
  final bool ring;
  final Color color;

  AvatarBubble({
    super.key,
    required this.initials,
    this.size = 40,
    this.ring = false,
    this.color = const Color(0xFF0F7A44),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
        border: ring ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: AppShadows.soft,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: AppType.bodyStrong.copyWith(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class Haptics {
  const Haptics._();

  static void tap() {
    HapticFeedback.lightImpact();
  }

  static void success() {
    HapticFeedback.mediumImpact();
  }

  static void error() {
    HapticFeedback.heavyImpact();
  }
}
