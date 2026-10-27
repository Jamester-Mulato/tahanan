import 'dart:convert';

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

/// The idle motions the splash and key-restore screens can apply to a widget.
enum IdleMotionType {
  none,
  float,
  bob,
  sway,
  breathe,
  pulse,
  wiggle,
  tilt,
  drift,
  orbit,
  shimmer,
}

/// One JSON-defined idle animation.
///
/// `amplitude` is interpreted by the motion:
/// - pixels for float / bob / sway / drift / orbit,
/// - a scale delta for breathe / pulse,
/// - radians for wiggle / tilt,
/// - an opacity delta for shimmer.
class IdleMotionSpec {
  final IdleMotionType type;
  final Duration duration;
  final double amplitude;
  final Duration delay;
  final Curve curve;

  const IdleMotionSpec({
    this.type = IdleMotionType.none,
    this.duration = const Duration(milliseconds: 2400),
    this.amplitude = 2,
    this.delay = Duration.zero,
    this.curve = Curves.easeInOut,
  });

  static const IdleMotionSpec idle = IdleMotionSpec();

  double get delayFraction {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (delay.inMilliseconds % total) / total;
  }

  static IdleMotionSpec fromJson(
    Map<String, dynamic> json, {
    IdleMotionSpec fallback = idle,
  }) {
    return IdleMotionSpec(
      type: _typeFromName(json['type'] as String?) ?? fallback.type,
      duration: Duration(
        milliseconds: _positiveInt(
          json['durationMs'],
          fallback.duration.inMilliseconds,
        ),
      ),
      amplitude: _double(json['amplitude'], fallback.amplitude),
      delay: Duration(
        milliseconds: _nonNegativeInt(
          json['delayMs'],
          fallback.delay.inMilliseconds,
        ),
      ),
      curve: _curveFromName(json['curve'] as String?) ?? fallback.curve,
    );
  }

  static IdleMotionType? _typeFromName(String? name) {
    if (name == null) return null;
    for (final type in IdleMotionType.values) {
      if (type.name == name) return type;
    }
    return null;
  }

  static int _positiveInt(Object? value, int fallback) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed <= 0) return fallback;
    return parsed;
  }

  static int _nonNegativeInt(Object? value, int fallback) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed < 0) return fallback;
    return parsed;
  }

  static double _double(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  static Curve? _curveFromName(String? name) {
    switch (name) {
      case 'linear':
        return Curves.linear;
      case 'easeIn':
        return Curves.easeIn;
      case 'easeOut':
        return Curves.easeOut;
      case 'easeInOut':
        return Curves.easeInOut;
      case 'easeOutCubic':
        return Curves.easeOutCubic;
      case 'easeInOutCubic':
        return Curves.easeInOutCubic;
      case 'elasticOut':
        return Curves.elasticOut;
      case 'bounceOut':
        return Curves.bounceOut;
      default:
        return null;
    }
  }
}

/// Loads the JSON animation sheet once and resolves a spec by widget key.
class MotionCatalog {
  final Map<String, IdleMotionSpec> specs;
  final bool fromAsset;

  const MotionCatalog({
    required this.specs,
    this.fromAsset = false,
  });

  IdleMotionSpec spec(String key) => specs[key] ?? IdleMotionSpec.idle;

  static const String defaultAsset = 'assets/animations/idle_motion.json';

  /// Built-in fallback so the UI still animates if the asset is missing.
  static MotionCatalog fallback() {
    return const MotionCatalog(
      specs: {
        'splash.wordmark': IdleMotionSpec(
          type: IdleMotionType.float,
          duration: Duration(milliseconds: 3200),
          amplitude: 3,
        ),
        'splash.tagline': IdleMotionSpec(
          type: IdleMotionType.sway,
          duration: Duration(milliseconds: 3600),
          amplitude: 4,
          delay: Duration(milliseconds: 260),
        ),
        'splash.logo': IdleMotionSpec(
          type: IdleMotionType.breathe,
          duration: Duration(milliseconds: 2600),
          amplitude: 0.035,
        ),
        'splash.logo.glow': IdleMotionSpec(
          type: IdleMotionType.pulse,
          duration: Duration(milliseconds: 2200),
          amplitude: 0.08,
          delay: Duration(milliseconds: 120),
        ),
        'splash.chip.properties': IdleMotionSpec(
          type: IdleMotionType.bob,
          duration: Duration(milliseconds: 2400),
          amplitude: 3,
        ),
        'splash.chip.people': IdleMotionSpec(
          type: IdleMotionType.bob,
          duration: Duration(milliseconds: 2400),
          amplitude: 3,
          delay: Duration(milliseconds: 240),
        ),
        'splash.chip.updates': IdleMotionSpec(
          type: IdleMotionType.bob,
          duration: Duration(milliseconds: 2400),
          amplitude: 3,
          delay: Duration(milliseconds: 480),
        ),
        'restore.key.emblem': IdleMotionSpec(
          type: IdleMotionType.breathe,
          duration: Duration(milliseconds: 2400),
          amplitude: 0.028,
        ),
        'restore.key.owner': IdleMotionSpec(
          type: IdleMotionType.tilt,
          duration: Duration(milliseconds: 2800),
          amplitude: 0.018,
          delay: Duration(milliseconds: 120),
        ),
        'restore.key.tenant': IdleMotionSpec(
          type: IdleMotionType.tilt,
          duration: Duration(milliseconds: 3000),
          amplitude: 0.018,
          delay: Duration(milliseconds: 260),
        ),
        'restore.key.house': IdleMotionSpec(
          type: IdleMotionType.tilt,
          duration: Duration(milliseconds: 3200),
          amplitude: 0.018,
          delay: Duration(milliseconds: 400),
        ),
        'restore.status': IdleMotionSpec(
          type: IdleMotionType.pulse,
          duration: Duration(milliseconds: 2000),
          amplitude: 0.04,
        ),
      },
    );
  }

  static Future<MotionCatalog> load({
    String asset = defaultAsset,
    AssetBundle? bundle,
  }) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(asset);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return fallback();

      final specs = <String, IdleMotionSpec>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! Map) continue;
        specs[key] = IdleMotionSpec.fromJson(
          Map<String, dynamic>.from(value),
        );
      }

      if (specs.isEmpty) return fallback();
      return MotionCatalog(specs: specs, fromAsset: true);
    } catch (_) {
      return fallback();
    }
  }
}
