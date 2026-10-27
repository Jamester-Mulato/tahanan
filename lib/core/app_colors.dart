import 'package:flutter/material.dart';

/// Centralised palette for Tahanan.
///
/// Light is the original "white & green" identity. Dark is a real, literal
/// palette (deep green-black surfaces, light text, brighter green accents) —
/// not a colour filter. The active variant is selected once by [dark], which
/// the root widget keeps in sync with the theme setting.
class AppColors {
  /// Set by the root widget from the persisted Theme setting.
  static bool dark = false;

  // ---------------------------------------------------------
  // Backgrounds
  // ---------------------------------------------------------
  static Color get background =>
      dark ? const Color(0xFF0A120D) : const Color(0xFFF3F9F5);
  static Color get backgroundGradientTop =>
      dark ? const Color(0xFF0E1812) : const Color(0xFFFFFFFF);
  static Color get backgroundGradientBottom =>
      dark ? const Color(0xFF08100B) : const Color(0xFFE7F5EC);

  // ---------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------
  static Color get surface =>
      dark ? const Color(0xFF111B15) : const Color(0xFFFFFFFF);
  static Color get surfaceCard =>
      dark ? const Color(0xFF121E17) : const Color(0xFFFFFFFF);
  static Color get surfaceElevated =>
      dark ? const Color(0xFF18271E) : const Color(0xFFE7F5EC);
  static Color get surface2 =>
      dark ? const Color(0xFF0E1812) : const Color(0xFFF2FAF5);
  static Color get surfaceDark =>
      dark ? const Color(0xFF0B1410) : const Color(0xFFFAFDFB);
  static Color get surfaceGlass =>
      dark ? const Color(0xE6101A14) : const Color(0xF2FFFFFF);

  // ---------------------------------------------------------
  // Primary green accents
  // ---------------------------------------------------------
  static Color get primary =>
      dark ? const Color(0xFF3DDC84) : const Color(0xFF0F7A44);
  static Color get primaryLight =>
      dark ? const Color(0xFF6EE7A0) : const Color(0xFF22C55E);
  static Color get primaryDark =>
      dark ? const Color(0xFFA7EDC4) : const Color(0xFF0A3D26);
  static Color get primaryGlow =>
      dark ? const Color(0x333DDC84) : const Color(0x2615803D);
  static Color get primarySoft =>
      dark ? const Color(0xFF173826) : const Color(0xFFDCFCE7);

  // Richer emerald scale used by hero panels, the wordmark and gradients.
  static Color get emerald900 =>
      dark ? const Color(0xFF06170F) : const Color(0xFF052E1C);
  static Color get emerald800 =>
      dark ? const Color(0xFF0A2418) : const Color(0xFF0A3D26);
  static Color get emerald700 =>
      dark ? const Color(0xFF0E3322) : const Color(0xFF0C5634);
  static Color get emerald600 =>
      dark ? const Color(0xFF16A356) : const Color(0xFF0F7A44);
  static Color get emerald500 =>
      dark ? const Color(0xFF3DDC84) : const Color(0xFF16A356);
  static Color get mint100 =>
      dark ? const Color(0xFF13241B) : const Color(0xFFEAF9F0);
  static Color get mint200 =>
      dark ? const Color(0xFF1B3326) : const Color(0xFFD3F3DF);
  static Color get lime => const Color(0xFFC7F26A);
  static Color get limeDeep => const Color(0xFFA3D84A);
  static Color get sky => const Color(0xFF38BDF8);
  static Color get teal => const Color(0xFF14B8A6);

  // Text on deep-emerald hero surfaces. Kept as tokens so contrast is tuned
  // once instead of being re-invented per screen.
  static Color get heroText => const Color(0xFFFFFFFF);
  static Color get heroMuted =>
      dark ? const Color(0xFFBFDCCB) : const Color(0xFFC9E2D5);

  // ---------------------------------------------------------
  // Typography
  // ---------------------------------------------------------
  static Color get text =>
      dark ? const Color(0xFFE8F3EC) : const Color(0xFF08170F);
  static Color get muted =>
      dark ? const Color(0xFF9BB3A5) : const Color(0xFF5B7365);
  static Color get textSecondary =>
      dark ? const Color(0xFFB7CBBF) : const Color(0xFF4A6354);
  static Color get textDark =>
      dark ? const Color(0xFF08170F) : const Color(0xFFFFFFFF);

  // ---------------------------------------------------------
  // Borders & elevation
  // ---------------------------------------------------------
  static Color get border =>
      dark ? const Color(0xFF223529) : const Color(0xFFE4EFE8);
  static Color get borderSubtle =>
      dark ? const Color(0xFF1A2B21) : const Color(0xFFF0F8F3);
  static Color get borderLight =>
      dark ? const Color(0xFF2C4636) : const Color(0xFFCFE2D6);
  static Color get hairline =>
      dark ? const Color(0xFF1D2F24) : const Color(0xFFEDF5F0);

  /// Layered, low-opacity shadows. Cards rely on these instead of hard
  /// borders so surfaces feel like they float rather than sit in a box.
  static Color get shadow =>
      dark ? const Color(0x66000000) : const Color(0x120B1F14);
  static Color get shadowStrong =>
      dark ? const Color(0x99000000) : const Color(0x1F0B1F14);
  static Color get shadowSoft =>
      dark ? const Color(0x44000000) : const Color(0x0A0B1F14);
  static Color get shadowMint =>
      dark ? const Color(0x333DDC84) : const Color(0x1A0F7A44);

  static List<BoxShadow> get panelShadow => [
        BoxShadow(
            color: shadowSoft, blurRadius: 3, offset: const Offset(0, 1)),
        BoxShadow(color: shadow, blurRadius: 22, offset: const Offset(0, 10)),
      ];
  static List<BoxShadow> get floatingShadow => [
        BoxShadow(
            color: shadowSoft, blurRadius: 2, offset: const Offset(0, 1)),
        BoxShadow(
            color: shadowStrong,
            blurRadius: 32,
            offset: const Offset(0, 14)),
      ];

  // ---------------------------------------------------------
  // Statuses
  // ---------------------------------------------------------
  static Color get statusPaid =>
      dark ? const Color(0xFF3DDC84) : const Color(0xFF0F7A44);
  static Color get statusPaidBg =>
      dark ? const Color(0xFF123322) : const Color(0xFFDCFCE7);
  static Color get statusPartial =>
      dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
  static Color get statusPartialBg =>
      dark ? const Color(0xFF3A2A10) : const Color(0xFFFEF3C7);
  static Color get statusUnpaid =>
      dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
  static Color get statusUnpaidBg =>
      dark ? const Color(0xFF3A1616) : const Color(0xFFFEE2E2);
  static Color get warning =>
      dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
  static Color get warningBg =>
      dark ? const Color(0xFF3A2A10) : const Color(0xFFFEF3C7);
  static Color get danger =>
      dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
  static Color get dangerBg =>
      dark ? const Color(0xFF3A1616) : const Color(0xFFFEE2E2);
  static Color get info =>
      dark ? const Color(0xFF60A5FA) : const Color(0xFF0369A1);
  static Color get infoBg =>
      dark ? const Color(0xFF122A3F) : const Color(0xFFE0F2FE);

  // ---------------------------------------------------------
  // Signature gradients
  // ---------------------------------------------------------
  static LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF04150D), Color(0xFF0A3B25), Color(0xFF0F5A38)]
            : const [Color(0xFF052E1C), Color(0xFF0C5634), Color(0xFF127A4A)],
        stops: const [0.0, 0.52, 1.0],
      );
  static LinearGradient get brandGradientBright => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF0C5B36), Color(0xFF16A356)]
            : const [Color(0xFF0E6B3E), Color(0xFF16A356)],
      );
  static LinearGradient get heroGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF06301D),
          Color(0xFF0A4B30),
          Color(0xFF0F7A44),
        ],
        stops: [0.0, 0.55, 1.0],
      );
  static LinearGradient get heroSheen => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x2EFFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.55],
      );
  static LinearGradient get limeGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD9FA8B), Color(0xFFC7F26A)],
      );
  static LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF121E17), Color(0xFF0F1A14)]
            : const [Color(0xFFFFFFFF), Color(0xFFFBFEFC)],
      );
  static LinearGradient get surfaceSheen => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF111C16), Color(0xFF0D1712)]
            : const [Color(0xFFFFFFFF), Color(0xFFF7FCF9)],
      );
  static LinearGradient get mintGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF0F1C15), Color(0xFF12241A)]
            : const [Color(0xFFEFFBF3), Color(0xFFDDF3E5)],
      );
  static LinearGradient get mintGradientSoft => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF0C1711), Color(0xFF101F17)]
            : const [Color(0xFFF4FCF7), Color(0xFFE8F7EE)],
      );

  // ---------------------------------------------------------
  // Radii — deliberately generous so nothing reads as a box.
  // ---------------------------------------------------------
  static const radiusXs = 10.0;
  static const radiusSm = 14.0;
  static const radiusMd = 18.0;
  static const radiusLg = 24.0;
  static const radiusXl = 30.0;
  static const radius2xl = 34.0;

  // ---------------------------------------------------------
  // Motion + depth tokens (GPU-cheap: opacity/translate/scale only)
  // ---------------------------------------------------------
  static const fastAnim = Duration(milliseconds: 140);
  static const normalAnim = Duration(milliseconds: 220);
  static const slowAnim = Duration(milliseconds: 380);
  static const staggerStep = Duration(milliseconds: 45);

  static const pressAnim = Duration(milliseconds: 130);
  static const stateAnim = Duration(milliseconds: 240);
  static const entranceAnim = Duration(milliseconds: 380);
  static const entranceSlide = 14.0;

  // ---------------------------------------------------------
  // Icon tile scale
  // ---------------------------------------------------------
  static const tileRadiusRatio = 0.43;
  static const tileIconRatio = 0.52;
  static const tileSm = 36.0;
  static const tileMd = 42.0;
  static const tileLg = 56.0;
  static const tapTargetMin = 48.0;
}
