import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';
import '../widgets/lottie_art.dart';
import '../widgets/recaptcha_box.dart';
import '../widgets/recaptcha_dialog.dart';
import '../widgets/tahanan_kit.dart';
import '../widgets/ui.dart';
import '../widgets/heavy_motion.dart';

/// Handout sections 10–11: username + CAPTCHA, a seeded security question,
/// a reset OTP, then a new password. Every step is checked on the server.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _username = TextEditingController();
  final _captcha = TextEditingController();
  final _answer = TextEditingController();
  final _reanswer = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _repassword = TextEditingController();

  int _step = 0;
  bool _busy = false;
  bool _resendBusy = false;
  String? _error;
  String? _info;
  List<Map<String, String>> _questions = [];

  RecaptchaConfig? _recaptchaConfig;
  String? _recaptchaToken;
  CaptchaChallenge? _challenge;
  bool _loadingCaptcha = false;

  String get _recaptchaBaseUrl =>
      AppConfig.apiBaseUrl.replaceFirst('127.0.0.1', 'localhost');

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _username,
      _captcha,
      _answer,
      _reanswer,
      _code,
      _password,
      _repassword
    ]) {
      controller.addListener(_clearError);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCaptchaMode();
    });
  }

  void _clearError() {
    if (_error == null) return;
    setState(() => _error = null);
  }

  @override
  void dispose() {
    for (final controller in [
      _username,
      _captcha,
      _answer,
      _reanswer,
      _code,
      _password,
      _repassword
    ]) {
      controller.removeListener(_clearError);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCaptchaMode() async {
    try {
      final config = await context.read<AppState>().fetchRecaptchaConfig();
      if (!mounted) return;
      setState(() => _recaptchaConfig = config);
      if (!config.enabled) await _refreshCaptcha();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recaptchaConfig = const RecaptchaConfig(enabled: false, siteKey: '');
      });
      await _refreshCaptcha();
    }
  }

  Future<void> _refreshCaptcha() async {
    setState(() => _loadingCaptcha = true);
    try {
      final challenge = await context.read<AppState>().fetchCaptcha();
      if (mounted) setState(() => _challenge = challenge);
    } catch (_) {
      // Reported on submit.
    } finally {
      if (mounted) setState(() => _loadingCaptcha = false);
    }
  }

  Future<void> _verifyRecaptcha() async {
    final config = _recaptchaConfig;
    if (config == null || !config.enabled) return;
    try {
      final token = await showRecaptchaDialog(
        context,
        apiBaseUrl: _recaptchaBaseUrl,
      );
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(() => _error = 'reCAPTCHA was cancelled. Try again.');
        return;
      }
      setState(() {
        _recaptchaToken = token;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'reCAPTCHA failed. Try again.');
    }
  }

  Future<void> _stepOne() async {
    if (_username.text.trim().isEmpty) {
      setState(() => _error = 'Enter your username.');
      return;
    }
    if (_recaptchaConfig?.enabled == true && _recaptchaToken == null) {
      setState(() => _error = 'Complete the Google reCAPTCHA verification.');
      return;
    }
    if (_recaptchaConfig?.enabled != true && _captcha.text.trim().isEmpty) {
      setState(() => _error = 'Enter the CAPTCHA answer.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final questions = await context.read<AppState>().forgotQuestions(
            _username.text,
            captchaId:
                _recaptchaConfig?.enabled == true ? null : _challenge?.id,
            captchaAnswer:
                _recaptchaConfig?.enabled == true ? null : _captcha.text.trim(),
            recaptchaToken:
                _recaptchaConfig?.enabled == true ? _recaptchaToken : null,
          );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _step = 1;
        _recaptchaToken = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      if (_recaptchaConfig?.enabled != true) await _refreshCaptcha();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stepTwo() async {
    if (_questions.isEmpty) return;
    if (_answer.text.trim().length < 2) {
      setState(() => _error = 'Enter your answer.');
      return;
    }
    if (_answer.text.trim() != _reanswer.text.trim()) {
      setState(() => _error = 'Answers do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final challenge = await context.read<AppState>().forgotAnswer(
            username: _username.text,
            question: _questions[_selected]['key']!,
            answer: _answer.text,
            reanswer: _reanswer.text,
          );
      if (!mounted) return;
      setState(() {
        _step2ChallengeId = challenge.challengeId;
        _info =
            'Code sent to ${challenge.maskedEmail}. It expires in 5 minutes.';
        _step = 2;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _selected = 0;

  Future<void> _resendReset() async {
    if (_step2ChallengeId == null || _resendBusy) return;
    setState(() => _resendBusy = true);
    try {
      final challenge =
          await context.read<AppState>().resendResetOtp(_step2ChallengeId!);
      if (!mounted) return;
      setState(() {
        _info = 'New code sent to ${challenge.maskedEmail}. '
            'Open the newest email.';
        _code.clear();
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _resendBusy = false);
    }
  }

  Future<void> _stepThree() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    if (_password.text.length < 9) {
      setState(() => _error = 'Password must be at least 9 characters.');
      return;
    }
    if (_password.text != _repassword.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final app = context.read<AppState>();
      final token = await app.verifyResetOtp(
        challengeId: _step2ChallengeId!,
        code: _code.text,
      );
      await app.resetPassword(
        code: token,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _step = 3;
        _info = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _step2ChallengeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TahananBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kGutter),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
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
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 4),
                            Text('PASSWORD RECOVERY', style: tEyebrow()),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            'Identify your account',
                            'Answer a question',
                            'Enter the code',
                            'Password changed'
                          ][_step],
                          style: tSectionTitle(),
                        ),
                        const SizedBox(height: 4),
                        Text(_subtitle(), style: tMeta()),
                        const SizedBox(height: 16),
                        if (_step == 0) ...[
                          GlideField(
                            controller: _username,
                            label: 'Username',
                            hint: '7-16 letters and digits',
                            icon: AppIcons.personLine,
                            required: true,
                          ),
                          const SizedBox(height: 10),
                          if (_recaptchaConfig == null)
                            const RecaptchaLoadingCard()
                          else if (_recaptchaConfig!.enabled)
                            _recaptchaBox()
                          else
                            _captchaBox(),
                        ],
                        if (_step == 1) ...[
                          _questionDrop(),
                          const SizedBox(height: 10),
                          GlideField(
                            controller: _answer,
                            label: 'Your Answer',
                            hint: 'Your answer',
                            icon: AppIcons.shieldLine,
                            required: true,
                          ),
                          const SizedBox(height: 10),
                          GlideField(
                            controller: _reanswer,
                            label: 'Re-enter Answer',
                            hint: 'Type it again',
                            icon: AppIcons.shieldLine,
                            required: true,
                          ),
                        ],
                        if (_step == 2) ...[
                          if (_info != null) ...[
                            Text(_info!,
                                style:
                                    TextStyle(fontSize: 12, color: kInkMuted)),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _resendBusy ? null : _resendReset,
                                child: Text(
                                  _resendBusy ? 'Sending…' : 'Resend code',
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          GlideField(
                            controller: _code,
                            label: '6-digit code',
                            hint: '000000',
                            icon: Icons.password_rounded,
                            required: true,
                          ),
                          const SizedBox(height: 10),
                          GlideField(
                            controller: _password,
                            label: 'New Password',
                            hint:
                                'At least 9 characters, uppercase and a number',
                            icon: AppIcons.lockLine,
                            obscure: true,
                            required: true,
                          ),
                          const SizedBox(height: 10),
                          GlideField(
                            controller: _repassword,
                            label: 'Re-enter New Password',
                            hint: 'Type it again',
                            icon: AppIcons.lockLine,
                            obscure: true,
                            required: true,
                          ),
                        ],
                        if (_step == 3)
                          const Column(
                            children: [
                              LottieArt('check', size: 120),
                              SizedBox(height: 6),
                              Text(
                                'Successfully Change Password. You can log in '
                                'with the new password.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          ShakeOnError(
                            trigger: _error,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (_step < 3)
                          TButton(
                            text: [
                              'Continue',
                              'Send code',
                              'Change password'
                            ][_step],
                            loading: _busy,
                            onPressed: _busy
                                ? null
                                : (_step == 0
                                    ? _stepOne
                                    : _step == 1
                                        ? _stepTwo
                                        : _stepThree),
                          )
                        else
                          TButton(
                            text: 'Back to log in',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        const SizedBox(height: 10),
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

  String _subtitle() {
    switch (_step) {
      case 0:
        return 'Enter your username and solve the CAPTCHA.';
      case 1:
        return 'Choose one of your three registered questions.';
      case 2:
        return 'Use the code we emailed you, then choose a new password.';
      default:
        return 'Your password has been changed.';
    }
  }

  Widget _questionDrop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Choose the following question',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _questions[_selected]['key'],
              isExpanded: true,
              items: [
                for (final q in _questions)
                  DropdownMenuItem(value: q['key'], child: Text(q['text']!)),
              ],
              onChanged: (value) {
                final index = _questions.indexWhere((q) => q['key'] == value);
                if (index >= 0) setState(() => _selected = index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _recaptchaBox() {
    final verified = _recaptchaToken != null;
    return RecaptchaCheckboxCard(
      verified: verified,
      onVerify: _verifyRecaptcha,
    );
  }

  Widget _captchaBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.shieldLine, size: 15, color: AppColors.muted),
              const SizedBox(width: 6),
              Text('CAPTCHA', style: tEyebrow()),
              const Spacer(),
              TextButton(
                onPressed: _loadingCaptcha ? null : _refreshCaptcha,
                child: const Text('New challenge'),
              ),
            ],
          ),
          Text(
            _challenge?.question ?? 'Tap New challenge to load one.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          GlideField(
            controller: _captcha,
            label: 'Answer',
            hint: 'Your answer',
            icon: AppIcons.shieldLine,
            required: true,
          ),
        ],
      ),
    );
  }
}
