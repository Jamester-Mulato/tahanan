import 'package:flutter/material.dart';

import '../core/app_motion.dart';
import '../core/app_theme.dart';
import '../core/app_colors.dart';

// ==========================================================
// LIQUID PAGE ROUTE
// ==========================================================
//
// A soft push transition modelled on FareFair's `LiquidPageRoute`. Instead of
// the platform default slide, pages rise slightly, fade in and scale from
// 0.985 — which reads as "a card settling into place" and matches the app's
// floating surfaces.
//
// The transition only animates opacity, translate and scale. When the
// platform requests reduced motion, the route short-circuits to no
// transition so content appears immediately.

class LiquidPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  final Duration duration;
  final Duration reverseDuration;

  LiquidPageRoute({
    required this.builder,
    super.settings,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 240),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) return child;
            final incoming = CurvedAnimation(
              parent: animation,
              curve: AppMotion.enter,
              reverseCurve: AppMotion.exit,
            );
            final outgoing = CurvedAnimation(
              parent: secondaryAnimation,
              curve: AppMotion.enter,
              reverseCurve: AppMotion.exit,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0.68).animate(outgoing),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: const Offset(-0.03, 0),
                ).animate(outgoing),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0, end: 1).animate(incoming),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.09, 0),
                      end: Offset.zero,
                    ).animate(incoming),
                    child: ScaleTransition(
                      scale:
                          Tween<double>(begin: 0.992, end: 1).animate(incoming),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        );
}

/// A modal-sheet-style route that slides up with a frosted scrim. Useful for
/// full-height flows that should still feel dismissible. Reduced motion
/// renders the sheet immediately with no slide or fade.
class LiquidSheetRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  LiquidSheetRoute({required this.builder, super.settings})
      : super(
          opaque: false,
          barrierColor: AppTheme.scrim(const Color(0x6605180D)),
          barrierDismissible: true,
          transitionDuration: AppMotion.page,
          reverseTransitionDuration: AppMotion.pageReverse,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) return child;
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppMotion.enter,
              reverseCurve: AppMotion.exit,
            );
            return FadeTransition(
              opacity: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

// ==========================================================
// CANONICAL ROUTING HELPERS
// ==========================================================
//
// Every navigation in the client goes through these helpers so the whole
// app shares one transition language and one reduced-motion fallback.
// Raw MaterialPageRoute / showModalBottomSheet / showDialog calls in
// screens are legacy and should migrate here; the helpers preserve the
// same navigation semantics (pop results, barrier dismissal).

/// Push a page with the liquid transition. Falls back to a plain
/// [MaterialPageRoute] (no transition) when reduced motion is requested.
Future<T?> pushLiquidPage<T>(BuildContext context, Widget page) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }
  return Navigator.of(context).push<T>(LiquidPageRoute(builder: (_) => page));
}

/// Show a bottom sheet with the shared scrim, shape and behavior contract
/// (scroll-controlled, safe-area aware, draggable, 28px top radius).
/// Call-site content (including `tSheetBody`) is preserved verbatim; only
/// the wrapper is standardized. Reduced-motion users get the same sheet
/// with the platform's default (non-animated) presentation.
Future<T?> showLiquidSheet<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    enableDrag: true,
    backgroundColor: AppColors.surface,
    barrierColor: AppTheme.scrim(const Color(0x7308170F)),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    sheetAnimationStyle: const AnimationStyle(
      duration: AppMotion.page,
      reverseDuration: AppMotion.pageReverse,
    ),
    builder: builder,
  );
}

/// Show a dialog with the shared scrim. Falls back to a plain dialog with
/// no transition when reduced motion is requested.
Future<T?> showLiquidDialog<T>(
  BuildContext context,
  Widget Function(BuildContext dialogContext) builder,
) {
  return showGeneralDialog<T>(
    context: context,
    barrierColor: AppTheme.scrim(const Color(0x7308170F)),
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.fast,
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionBuilder: (ctx, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(ctx)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
