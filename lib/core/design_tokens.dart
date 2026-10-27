import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing scale. Every gap, pad and inset in the app comes from here.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  static const EdgeInsets page = EdgeInsets.fromLTRB(20, 16, 20, 32);
  static const EdgeInsets card = EdgeInsets.all(20);
}

/// Corner radii. The app leans on large, soft geometry.
class AppRadius {
  const AppRadius._();

  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
  static const double xxl = 36;
  static const double pill = 999;

  static const BorderRadius rXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}

/// Motion tokens. Spring-like curves, short durations, no linear easing.
class AppTime {
  const AppTime._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration entrance = Duration(milliseconds: 520);
  static const Duration ambient = Duration(seconds: 26);
  static const Duration stagger = Duration(milliseconds: 55);
}

class AppCurves {
  const AppCurves._();

  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecel = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve softIn = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve overshoot = Cubic(0.34, 1.56, 0.64, 1.0);
}

/// Elevation recipes. Tinted with the brand green instead of pure black.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 3,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8)),
      ];

  static List<BoxShadow> get floating => [
        BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 6,
            offset: const Offset(0, 2)),
        BoxShadow(
            color: AppColors.shadowStrong,
            blurRadius: 34,
            offset: const Offset(0, 16)),
      ];

  static List<BoxShadow> get glow => [
        BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: 34,
            offset: const Offset(0, 14)),
      ];

  static List<BoxShadow> get glowLime => [
        BoxShadow(
            color: AppColors.dark
                ? const Color(0x333DDC84)
                : const Color(0x33A3D84A),
            blurRadius: 30,
            offset: const Offset(0, 12)),
      ];
}

/// Typography scale built on Inter with optical tracking at large sizes.
class AppType {
  const AppType._();

  static const String family = 'Inter';
  static const String displayFamily = 'Plus Jakarta Sans';

  static TextStyle get display => TextStyle(
        fontFamily: displayFamily,
        fontSize: 42,
        height: 1.04,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.6,
        color: AppColors.text,
      );

  static TextStyle get h1 => TextStyle(
        fontFamily: displayFamily,
        fontSize: 30,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: AppColors.text,
      );

  static TextStyle get h2 => TextStyle(
        fontFamily: displayFamily,
        fontSize: 22,
        height: 1.16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: AppColors.text,
      );

  static TextStyle get h3 => TextStyle(
        fontFamily: displayFamily,
        fontSize: 17,
        height: 1.24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.text,
      );

  static TextStyle get body => TextStyle(
        fontFamily: family,
        fontSize: 13.5,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodyStrong => TextStyle(
        fontFamily: family,
        fontSize: 13.5,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );

  static TextStyle get caption => TextStyle(
        fontFamily: family,
        fontSize: 11.5,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      );

  static TextStyle get eyebrow => TextStyle(
        fontFamily: family,
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: AppColors.primary,
      );

  static TextStyle get mono => TextStyle(
        fontFamily: 'monospace',
        fontSize: 30,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: 8,
        color: AppColors.primary,
      );
}
