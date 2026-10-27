import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// One tempo for the whole app.
///
/// Telegram's personality comes from every surface agreeing on the same
/// small set of durations and curves. Keep these short, decisive and
/// interruptible; never add a bounce.
abstract final class AppMotion {
  /// Touch acknowledgement. Must land on the first frame.
  static const Duration instant = Duration(milliseconds: 80);

  /// Small state changes: icon morphs, highlights, badges.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions: tabs, expands, cross-fades.
  static const Duration standard = Duration(milliseconds: 210);

  /// Large spatial moves: page pushes and sheets.
  static const Duration page = Duration(milliseconds: 260);
  static const Duration pageReverse = Duration(milliseconds: 220);

  /// Quick, confident start with a soft settle. No overshoot.
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve settle = Curves.easeOutCubic;

  static const double pressScale = 0.975;
  static const double cardPressScale = 0.988;
}

/// Rubber-band scrolling everywhere, so every list has the same weight and
/// momentum instead of switching physics between platforms.
class TahananScrollBehavior extends MaterialScrollBehavior {
  const TahananScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

/// Layered push: the new page slides in decisively from the edge while the
/// page beneath drifts the same direction more slowly and dims under a
/// shadow. Both layers stay interruptible for the whole transition.
class TelegramPageTransitionsBuilder extends PageTransitionsBuilder {
  const TelegramPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
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
      // The page underneath dims and drifts back rather than sliding away.
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
              scale: Tween<double>(begin: 0.992, end: 1).animate(incoming),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
