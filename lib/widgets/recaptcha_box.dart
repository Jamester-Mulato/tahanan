import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/design_tokens.dart';
import 'app_icons.dart';
import 'pressable.dart';
import 'tahanan_kit.dart';

class RecaptchaLoadingCard extends StatelessWidget {
  const RecaptchaLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDADCE0)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading Google reCAPTCHA…',
            style: AppType.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// The familiar Google reCAPTCHA checkbox card.
///
/// The real widget (checkbox + image challenge) opens in the verified Google
/// frame; this surface keeps the form compact and unmistakably Google.
class RecaptchaCheckboxCard extends StatelessWidget {
  final bool verified;
  final VoidCallback onVerify;

  const RecaptchaCheckboxCard({
    super.key,
    required this.verified,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: verified ? null : onVerify,
      borderRadius: BorderRadius.circular(16),
      pressedScale: 0.995,
      highlightColor: Colors.black.withValues(alpha: 0.02),
      semanticsLabel: verified
          ? 'Google reCAPTCHA verified'
          : 'I am not a robot. Verify with Google reCAPTCHA',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: verified ? const Color(0xFFBFE7CD) : const Color(0xFFDADCE0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A08170F),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: verified ? kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: verified ? kPrimary : const Color(0xFFB8BEC6),
                  width: 1.6,
                ),
              ),
              child: verified
                  ? const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    verified ? 'You are verified' : "I'm not a robot",
                    style: AppType.bodyStrong.copyWith(
                      fontSize: 13.5,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    verified
                        ? 'You can continue to Tahanan.'
                        : 'Tap to open Google reCAPTCHA',
                    style: AppType.caption.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    AppIcons.shieldLine,
                    size: 17,
                    color: Color(0xFF4285F4),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'reCAPTCHA',
                  style: TextStyle(
                    color: Color(0xFF5F6368),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const Text(
                  'Privacy · Terms',
                  style: TextStyle(
                    color: Color(0xFF80868B),
                    fontSize: 6.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
