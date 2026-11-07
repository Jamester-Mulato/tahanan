import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/heavy_motion.dart';
import '../widgets/lottie_art.dart';
import '../widgets/tahanan_kit.dart';
import '../widgets/ui.dart';

/// Step two of the handout log-in flow: the 6-digit code emailed to the owner.
///
/// The session is created here, on the server, only when the code is correct.
class LoginOtpScreen extends StatefulWidget {
  final LoginChallenge challenge;
  final String username;
  final String password;
  final bool rememberMe;
  final bool registration;

  const LoginOtpScreen({
    super.key,
    required this.challenge,
    required this.username,
    required this.password,
    required this.rememberMe,
    this.registration = false,
  });

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  late LoginChallenge _challenge;
  Timer? _ticker;
  int _expiresIn = 0;
  int _resendIn = 0;
  bool _verifying = false;
  bool _resending = false;
  bool _success = false;
  int _wrongAttempts = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    _startTimers();
  }

  void _startTimers() {
    _expiresIn = _challenge.expiresIn;
    _resendIn = _challenge.resendIn;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_expiresIn > 0) _expiresIn--;
        if (_resendIn > 0) _resendIn--;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String _clock(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _verify() async {
    // A second tap or the keyboard's submit must not re-send the code after
    // the first attempt already succeeded (that returns already_used).
    if (_verifying || _success) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _verifying = true;
    });

    try {
      if (widget.registration) {
        await context.read<AppState>().verifyRegistrationOtp(
              challengeId: _challenge.challengeId,
              code: code,
            );
      } else {
        await context.read<AppState>().verifyLoginOtp(
              challengeId: _challenge.challengeId,
              code: code,
              password: widget.password,
              rememberMe: widget.rememberMe,
            );
      }
      if (!mounted) return;
      _success = true;
      await _showSuccess();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (error) {
      if (_success) return;
      if (mounted) {
        setState(() {
          _error = error.message;
          _wrongAttempts++;
        });
        _codeController.clear();
        _codeFocus.requestFocus();
      }
    } catch (error) {
      debugPrint('OTP verify failed: ${error.runtimeType}: $error');
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _showSuccess() {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) {
        final navigator = Navigator.of(dialogContext);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (navigator.canPop()) navigator.pop();
        });
        return ColoredBox(
          color: AppColors.background.withValues(alpha: 0.97),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LottieArt('check', size: 150),
                const SizedBox(height: 10),
                Text(
                  widget.registration ? 'Account verified' : 'Signed in',
                  style: tSectionTitle(),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.registration
                      ? 'Your email is confirmed. Welcome to Tahanan.'
                      : 'Welcome back to Tahanan.',
                  style: tMeta(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });

    try {
      final next = widget.registration
          ? await context
              .read<AppState>()
              .resendRegistrationOtp(_challenge.challengeId)
          : await context
              .read<AppState>()
              .resendLoginOtp(_challenge.challengeId);
      if (!mounted) return;
      setState(() {
        _challenge = next;
        _codeController.clear();
        _wrongAttempts = 0;
        _error = null;
      });
      _startTimers();
      _codeFocus.requestFocus();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not resend the code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled =
        _verifying || _resending || _expiresIn == 0 || _wrongAttempts >= 3;

    return Scaffold(
      body: TahananBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kGutter),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: GlideIn(
                  child: TCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Back',
                              onPressed: disabled
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 4),
                            Text('LOG-IN CODE', style: tEyebrow()),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Check your email', style: tSectionTitle()),
                        const SizedBox(height: 6),
                        Text(
                          'We sent a 6-digit code to ${_challenge.maskedEmail}. '
                          '${widget.registration ? 'Enter it to activate the account for' : 'Enter it to finish signing in as'} ${widget.username}.',
                          style: tMeta(),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _codeController,
                          focusNode: _codeFocus,
                          enabled: !disabled,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 10,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '000000',
                            filled: true,
                            fillColor: AppColors.surface2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _verify(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _expiresIn > 0
                                  ? 'Code expires in ${_clock(_expiresIn)}'
                                  : 'This code has expired.',
                              style: TextStyle(
                                fontSize: 12,
                                color: kInkMuted,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed:
                                  (_resendIn > 0 || disabled) ? null : _resend,
                              child: Text(
                                _resendIn > 0
                                    ? 'Resend in ${_resendIn}s'
                                    : 'Resend code',
                              ),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 6),
                          ShakeOnError(
                            trigger: _error,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Magnetic(
                          strength: 3,
                          child: TButton(
                            text: 'Verify and log in',
                            loading: _verifying,
                            onPressed: disabled ? null : _verify,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: disabled
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Use a different account'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _wrongAttempts >= 3
                              ? 'Three wrong entries cancelled this code. '
                                  'Request a new one to continue.'
                              : _expiresIn == 0
                                  ? 'This code has expired. Request a new one '
                                      'to continue.'
                                  : '${3 - _wrongAttempts} of 3 tries left. The '
                                      'code is single-use and expires after '
                                      '5 minutes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: kInkMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '© 2026 Jamester C. Mulato. All rights reserved.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: kInkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
