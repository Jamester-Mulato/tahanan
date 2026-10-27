import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/design_tokens.dart';

/// Reveals its child as it scrolls into view: a soft fade plus a short
/// right-to-left glide.
///
/// The first paint is intentionally offset, so lists feel like they assemble
/// as the reader moves down the page. Reduced-motion users get the content
/// immediately. Each widget reveals once and then stops listening.
class ScrollReveal extends StatefulWidget {
  final Widget child;

  /// Used only to stagger neighbouring cards. Not a semantic index.
  final int index;
  final double slide;
  final double minVisible;
  final Duration duration;
  final bool once;

  const ScrollReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.slide = 0.075,
    this.minVisible = 0.06,
    this.duration = const Duration(milliseconds: 520),
    this.once = true,
  });

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal> {
  final _detectorKey = UniqueKey();
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // Safety net for web layouts where the visibility callback can be late:
    // anything already inside the first viewport reveals after the first
    // layout. Offscreen children still wait for the scroll detector.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shown) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      if (bottom > 0 && top < MediaQuery.sizeOf(context).height) {
        _reveal();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reveal() {
    if (_shown || _timer != null) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _shown = true;
      return;
    }
    final delay = Duration(milliseconds: 32 * (widget.index % 7));
    _timer = Timer(delay, () {
      if (!mounted) return;
      VisibilityDetectorController.instance.forget(_detectorKey);
      setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    // Keep the same widget shape for the whole life of the reveal. Swapping
    // the detector out when `_shown` flips would recreate the animated
    // widgets and skip the transition entirely.
    return VisibilityDetector(
      key: _detectorKey,
      onVisibilityChanged: (info) {
        if (!_shown && info.visibleFraction >= widget.minVisible) {
          _reveal();
        }
      },
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : Offset(widget.slide, 0.012),
        duration: widget.duration,
        curve: AppCurves.emphasizedDecel,
        child: AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Wrap a list of widgets so each one reveals in order without repeating the
/// [ScrollReveal] boilerplate in every screen.
List<Widget> revealAll(
  List<Widget> children, {
  int start = 0,
  double slide = 0.075,
}) {
  return [
    for (var i = 0; i < children.length; i++)
      ScrollReveal(
        index: start + i,
        slide: slide,
        child: children[i],
      ),
  ];
}
