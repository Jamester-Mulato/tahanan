import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'tahanan_kit.dart';

/// A small, non-blocking refresh pill shown while the app re-fetches data.
/// It sits over the shell so tabs stay usable during a refresh.
class RefreshOverlay extends StatelessWidget {
  final bool visible;

  const RefreshOverlay({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1.4),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kHairline),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.text.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: visible
                          ? CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kPrimary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Refreshing…',
                      style: TextStyle(
                        color: kInkMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
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
