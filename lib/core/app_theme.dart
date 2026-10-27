import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_motion.dart';

class AppTheme {
  /// Light "white & green" theme used across Tahanan.
  static ThemeData get lightTheme {
    final base = AppColors.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        )
        .copyWith(
          headlineMedium: GoogleFonts.plusJakartaSans(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.12,
            color: AppColors.text,
          ),
          headlineSmall: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.18,
            color: AppColors.text,
          ),
          titleLarge: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.text,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: AppColors.text,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 15,
            height: 1.55,
            letterSpacing: -0.1,
            color: AppColors.text,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 13.5,
            height: 1.55,
            letterSpacing: -0.05,
            color: AppColors.text,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
            height: 1.5,
            color: AppColors.muted,
          ),
          labelLarge: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        );

    final scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.textDark,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.primaryDark,
      onSecondary: AppColors.textDark,
      secondaryContainer: AppColors.surfaceElevated,
      onSecondaryContainer: AppColors.primaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surface2,
      surfaceContainer: AppColors.surfaceElevated,
      surfaceContainerHigh: AppColors.surfaceElevated,
      surfaceContainerHighest: AppColors.borderSubtle,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
      onError: AppColors.textDark,
      errorContainer: AppColors.dangerBg,
      onErrorContainer: AppColors.statusUnpaid,
      shadow: AppColors.shadow,
      scrim: AppColors.shadow,
      inverseSurface: AppColors.text,
      onInverseSurface: AppColors.textDark,
      inversePrimary: AppColors.primaryLight,
    ).copyWith(
      brightness: AppColors.dark ? Brightness.dark : Brightness.light,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      textTheme: textTheme,
      // No expanding ripple waves: press feedback is immediate (highlight +
      // short scale settle) through PressableSurface.
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: AppColors.primary.withValues(alpha: 0.035),
      focusColor: AppColors.primary.withValues(alpha: 0.08),
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TelegramPageTransitionsBuilder(),
          TargetPlatform.iOS: TelegramPageTransitionsBuilder(),
          TargetPlatform.linux: TelegramPageTransitionsBuilder(),
          TargetPlatform.macOS: TelegramPageTransitionsBuilder(),
          TargetPlatform.windows: TelegramPageTransitionsBuilder(),
          TargetPlatform.fuchsia: TelegramPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.text),
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 17.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          // Canonical card radius (single source: tahanan_kit kCardRadius).
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.danger, width: 1.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.hairline, width: 1),
        ),
        labelStyle: TextStyle(color: AppColors.muted, fontSize: 14),
        floatingLabelStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        hintStyle: TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: TextStyle(color: AppColors.danger, fontSize: 12),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textDark,
          disabledBackgroundColor: AppColors.borderLight,
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          minimumSize: const Size(0, 50),
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.mintGradientSoft.colors.last,
          side: BorderSide(color: AppColors.hairline, width: 1),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.muted,
          highlightColor: AppColors.primary.withValues(alpha: 0.08),
          // 48x48 minimum hit target for keyboard and touch traversal.
          minimumSize: const Size(
            AppColors.tapTargetMin,
            AppColors.tapTargetMin,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: AppColors.shadowStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.emerald800,
        contentTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.lime,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.shadowStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.muted,
        textColor: AppColors.text,
        subtitleTextStyle: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      iconTheme: IconThemeData(color: AppColors.muted),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceElevated,
        circularTrackColor: AppColors.surfaceElevated,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Backwards-compatible alias for screens that still reference the old name.
  static ThemeData get darkTheme => lightTheme;

  /// True while the whole-app dark filter is active. Used only for a few
  /// colours that are composited outside the normal content flow (scrims),
  /// so they can be pre-inverted.
  static bool darkActive = false;

  /// A modal barrier that still reads as dark after the dark-mode filter.
  static Color scrim(Color normal) => normal;

  /// Whole-app dark mode: invert lightness while preserving hue (the same
  /// effect as CSS `invert(1) hue-rotate(180deg)`). Light surfaces become
  /// dark, dark text becomes light, and the green accents stay green.
  static const ColorFilter darkModeFilter = ColorFilter.matrix(<double>[
    0.488,
    -1.216,
    -0.122,
    0,
    240,
    -0.362,
    -0.366,
    -0.122,
    0,
    240,
    -0.362,
    -1.216,
    0.728,
    0,
    240,
    0,
    0,
    0,
    1,
    0,
  ]);
}

/// Backwards-compatible name for [TelegramPageTransitionsBuilder]. The
/// layered slide lives in `app_motion.dart` so every route shares one tempo.
@Deprecated('Use TelegramPageTransitionsBuilder from app_motion.dart')
class TahananPageTransitionsBuilder extends TelegramPageTransitionsBuilder {
  const TahananPageTransitionsBuilder();
}
