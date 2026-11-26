import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_config.dart';
import '../core/design_tokens.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';
import '../widgets/heavy_motion.dart';
import '../widgets/lottie_art.dart';
import '../widgets/premium/premium_kit.dart';
import '../widgets/recaptcha_box.dart';
import '../widgets/recaptcha_dialog.dart';
import '../widgets/privacy_notice.dart';
import '../widgets/tahanan_kit.dart';
import 'account_switcher.dart';
import 'forgot_password_screen.dart';
import 'login_otp.dart';
import 'register_screen.dart';

/// Authentication screen rebuilt on the premium design system.
///
/// Surfaces: aurora backdrop, glass brand hero, glass auth card, live lockout
/// ring, saved-account switcher, and staggered entrances. Behaviour is the
/// handout flow: username + password + CAPTCHA, then a 6-digit email code.
class LoginScreen extends StatefulWidget {
  final bool loadCaptcha;

  const LoginScreen({super.key, this.loadCaptcha = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _captcha = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _showPassword = false;
  bool _submitting = false;
  bool _rememberMe = false;
  bool _loadingCaptcha = false;

  String? _formError;
  String? _usernameError;
  String? _passwordError;
  String? _captchaError;

  int _failedAttempts = 0;
  int _lockSeconds = 0;
  int _lockTotal = 0;
  Timer? _lockTicker;

  RecaptchaConfig? _recaptchaConfig;
  String? _recaptchaToken;
  CaptchaChallenge? _captchaChallenge;

  String get _recaptchaBaseUrl =>
      AppConfig.apiBaseUrl.replaceFirst('127.0.0.1', 'localhost');

  @override
  void initState() {
    super.initState();
    _username.addListener(_clearUsernameError);
    _password.addListener(_clearPasswordError);
    _captcha.addListener(_clearCaptchaError);
    if (widget.loadCaptcha) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadVerification();
      });
    }
  }

  void _clearUsernameError() {
    if (_usernameError == null && _formError == null) return;
    setState(() {
      _usernameError = null;
      _formError = null;
    });
  }

  void _clearPasswordError() {
    if (_passwordError == null && _formError == null) return;
    setState(() {
      _passwordError = null;
      _formError = null;
    });
  }

  void _clearCaptchaError() {
    if (_captchaError == null) return;
    setState(() => _captchaError = null);
  }

  @override
  void dispose() {
    _username.removeListener(_clearUsernameError);
    _password.removeListener(_clearPasswordError);
    _captcha.removeListener(_clearCaptchaError);
    _username.dispose();
    _password.dispose();
    _captcha.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _lockTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadVerification() async {
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
      if (mounted) {
        setState(() {
          _captchaChallenge = challenge;
          _captchaError = null;
        });
      }
    } catch (_) {
      // The error is shown when the form is submitted.
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
        setState(() => _formError = 'reCAPTCHA was cancelled. Try again.');
        return;
      }
      setState(() {
        _recaptchaToken = token;
        _formError = null;
      });
    } catch (_) {
      if (mounted) setState(() => _formError = 'reCAPTCHA failed. Try again.');
    }
  }

  Future<void> _openSavedAccounts() async {
    final account = await showAccountSwitcher(context);
    if (!mounted) return;
    if (account == null) {
      _usernameFocus.requestFocus();
      return;
    }
    setState(() {
      _username.text = account.loginName;
      _password.text = account.canAutofill ? (account.password ?? '') : '';
      _rememberMe = account.canAutofill;
      _usernameError = null;
      _passwordError = null;
    });
    await _refreshCaptcha();
  }

  void _startLockout(int seconds) {
    _lockTicker?.cancel();
    Haptics.error();
    setState(() {
      _lockSeconds = seconds;
      _lockTotal = seconds;
    });
    _lockTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _lockSeconds = (_lockSeconds - 1).clamp(0, 1 << 20));
      if (_lockSeconds <= 0) {
        timer.cancel();
        if (mounted) setState(() => _formError = null);
      }
    });
  }

  String? _validate() {
    _usernameError = null;
    _passwordError = null;
    _captchaError = null;

    final username = _username.text.trim();
    if (username.isEmpty) {
      _usernameError = 'Enter your username.';
    } else if (username.length < 7 || username.length > 16) {
      _usernameError = 'Username must be 7 to 16 characters.';
    } else if (!RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(username)) {
      _usernameError =
          'Username must start with a letter and use letters and digits only.';
    }

    if (_password.text.isEmpty) {
      _passwordError = 'Enter your password.';
    }

    if (_recaptchaConfig?.enabled == true) {
      if (_recaptchaToken == null || _recaptchaToken!.isEmpty) {
        _captchaError = 'Complete the Google reCAPTCHA verification.';
      }
    } else if (_captchaChallenge == null) {
      _captchaError = 'Load a CAPTCHA challenge first.';
    } else if (_captcha.text.trim().isEmpty) {
      _captchaError = 'Enter the CAPTCHA answer.';
    }

    return _usernameError ?? _passwordError ?? _captchaError;
  }

  Future<void> _submit() async {
    if (_lockSeconds > 0) return;
    final problem = _validate();
    if (problem != null) {
      Haptics.error();
      setState(() => _formError = null);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _formError = null;
      _submitting = true;
    });

    final state = context.read<AppState>();
    final reCAPTCHA = _recaptchaConfig?.enabled == true;

    try {
      final challenge = await state.startPasswordLogin(
        username: _username.text.trim(),
        password: _password.text,
        captchaId: reCAPTCHA ? null : _captchaChallenge?.id,
        captchaAnswer: reCAPTCHA ? null : _captcha.text.trim(),
        recaptchaToken: reCAPTCHA ? _recaptchaToken : null,
      );

      if (!mounted) return;
      Haptics.tap();
      setState(() {
        _submitting = false;
        _failedAttempts = 0;
      });

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoginOtpScreen(
            challenge: challenge,
            username: _username.text.trim(),
            password: _password.text,
            rememberMe: _rememberMe,
          ),
        ),
      );
      return;
    } on ApiException catch (error) {
      if (!mounted) return;
      final details = error.details;
      final serverAttempts = (details?['attempts'] as num?)?.toInt();
      final lockDetails = (details?['retryAfter'] as num?)?.toInt();
      if (error.status == 423 || error.status == 429) {
        final seconds = lockDetails ?? error.retryAfter;
        if (seconds != null && seconds > 0) _startLockout(seconds);
      }
      setState(() {
        if (serverAttempts != null) {
          _failedAttempts = serverAttempts;
        } else if (error.status == 401) {
          _failedAttempts++;
        }
        final attemptInCycle =
            _failedAttempts <= 0 ? 1 : ((_failedAttempts - 1) % 3) + 1;
        if (error.status == 423 || error.status == 429) {
          _formError =
              'Too many failed attempts ($attemptInCycle of 3). ${error.message}';
        } else {
          _formError =
              '${error.message} Attempt $attemptInCycle of 3 — the account '
              'locks temporarily after 3 failed attempts.';
        }
        if (error.status == 400) {
          _recaptchaToken = null;
          _captchaError = error.message;
        } else if (error.status == 401) {
          _recaptchaToken = null;
          _captchaError = null;
        }
      });
      if (error.status == 401 || error.status == 400) {
        if (_recaptchaConfig?.enabled != true) await _refreshCaptcha();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _formError =
            'Cannot reach the server right now. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockSeconds > 0;
    final disabled = _submitting || locked;
    final wide = kIsWeb && MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      body: AuroraBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide ? 1120 : 520,
                  minHeight: wide ? MediaQuery.sizeOf(context).height - 40 : 0,
                ),
                child: Column(
                  mainAxisAlignment:
                      wide ? MainAxisAlignment.center : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Reveal(child: _BrandHero()),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Reveal(
                                  delay: const Duration(milliseconds: 90),
                                  child: _authCard(disabled, locked),
                                ),
                                const SizedBox(height: 14),
                                Reveal(
                                  delay: const Duration(milliseconds: 180),
                                  child: _LoginFooter(onPrivacy: _showPrivacy),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      const Reveal(child: _BrandHero()),
                      const SizedBox(height: 18),
                      Reveal(
                        delay: const Duration(milliseconds: 90),
                        child: _authCard(disabled, locked),
                      ),
                      const SizedBox(height: 14),
                      Reveal(
                        delay: const Duration(milliseconds: 180),
                        child: _LoginFooter(onPrivacy: _showPrivacy),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authCard(bool disabled, bool locked) {
    final state = context.watch<AppState>();

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      radius: AppRadius.xxl,
      blur: 22,
      tint: 0.8,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillSelector(
            options: const ['Log in', 'Sign up'],
            selected: 0,
            onSelect: (index) {
              if (locked) return;
              if (index == 1) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              }
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SIGN IN', style: AppType.eyebrow),
                    const SizedBox(height: 4),
                    Text('Welcome back', style: AppType.h2),
                  ],
                ),
              ),
              const LottieArt('shield', size: 52),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Username, password, then the 6-digit code we email you.',
            style: AppType.caption,
          ),
          const SizedBox(height: 18),
          PremiumField(
            controller: _username,
            focusNode: _usernameFocus,
            label: 'Username',
            hint: '7-16 letters and digits',
            icon: AppIcons.personLine,
            required: true,
            enabled: !disabled,
            error: _usernameError,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            onChanged: (_) {
              if (_usernameError != null) setState(() => _usernameError = null);
            },
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            suffix: state.savedAccounts.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Saved accounts',
                    onPressed: disabled ? null : _openSavedAccounts,
                    icon: Icon(
                      Icons.manage_accounts_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          PremiumField(
            controller: _password,
            focusNode: _passwordFocus,
            label: 'Password',
            hint: 'Your password',
            icon: AppIcons.lockLine,
            required: true,
            obscure: !_showPassword,
            enabled: !disabled,
            error: _passwordError,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) {
              if (_passwordError != null) setState(() => _passwordError = null);
            },
            onSubmitted: (_) => _submit(),
            suffix: IconButton(
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 19,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (locked)
            _lockCard()
          else if (_recaptchaConfig == null)
            const RecaptchaLoadingCard()
          else if (_recaptchaConfig!.enabled)
            _recaptchaBox()
          else
            _captchaBox(),
          if (_captchaError != null && !locked) ...[
            const SizedBox(height: 6),
            Text(
              _captchaError!,
              style: AppType.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _rememberRow(),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen(),
                ),
              ),
              child: Text(
                _failedAttempts >= 3 || locked
                    ? 'Forgot Password? Reset Here'
                    : 'Forgot password?',
              ),
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 10),
            ShakeOnError(
              trigger: _formError,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: AppRadius.rMd,
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: AppType.caption.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SheenButton(
            text: locked ? 'Locked for ${_lockSeconds}s' : 'Log in',
            icon:
                locked ? Icons.lock_clock_rounded : Icons.arrow_forward_rounded,
            loading: _submitting,
            onPressed: disabled ? null : _submit,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'New here? Switch to Sign up to create an account.',
              style: AppType.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rememberRow() {
    return Row(
      children: [
        SizedBox(
          height: 26,
          width: 26,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) => setState(() => _rememberMe = value ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remember this account',
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              Text(
                'Autofills the password. The email code is still required.',
                style: AppType.caption.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recaptchaBox() {
    final verified = _recaptchaToken != null && _recaptchaToken!.isNotEmpty;
    return RecaptchaCheckboxCard(
      verified: verified,
      onVerify: _verifyRecaptcha,
    );
  }

  Widget _captchaBox() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.shieldLine, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('CAPTCHA', style: AppType.eyebrow),
              const Spacer(),
              TextButton(
                onPressed: _loadingCaptcha ? null : _refreshCaptcha,
                child: const Text('New challenge'),
              ),
            ],
          ),
          Text(
            _captchaChallenge?.question ?? 'Tap New challenge to load one.',
            style: AppType.bodyStrong,
          ),
          const SizedBox(height: 10),
          PremiumField(
            controller: _captcha,
            label: 'Answer',
            hint: 'Your answer',
            icon: AppIcons.shieldLine,
            required: true,
            enabled: !_loadingCaptcha,
            onChanged: (_) {
              if (_captchaError != null) setState(() => _captchaError = null);
            },
          ),
        ],
      ),
    );
  }

  Widget _lockCard() {
    final total = _lockTotal == 0 ? 1 : _lockTotal;
    final progress = 1 - (_lockSeconds / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerBg.withValues(alpha: 0.7),
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: progress,
            size: 64,
            stroke: 6,
            color: AppColors.danger,
            child: Text(
              '${_lockSeconds}s',
              style: AppType.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temporarily locked',
                  style: AppType.bodyStrong.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: 2),
                Text(
                  'Too many failed attempts. Log in and Sign up are disabled '
                  'until the countdown ends.',
                  style: AppType.caption.copyWith(
                    color: AppColors.danger.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacy() => showPrivacyNotice(context);
}

// ==============================================================
// BRAND HERO
// ==============================================================

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadius.rXxl,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF052E1C), Color(0xFF0A4B30), Color(0xFF0F7A44)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: AppShadows.glow,
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: TAmbient(
              art: 'aurora',
              opacity: 0.5,
              size: 520,
              alignment: Alignment.topRight,
            ),
          ),
          Positioned(
            right: -40,
            top: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0x33C7F26A),
                    const Color(0x00C7F26A),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: AppRadius.rSm,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        Icons.home_work_rounded,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tahanan',
                          style: AppType.h3.copyWith(
                            color: Colors.white,
                            fontSize: 19,
                          ),
                        ),
                        Text(
                          'BOARDING HOUSE, IN ORDER',
                          style: AppType.eyebrow.copyWith(
                            color: const Color(0xFFC7F26A),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const LottieArt('pulse', size: 46),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'A calmer way to run\nyour boarding house.',
                  style: AppType.h1.copyWith(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rooms, tenants and rent, kept in one quiet place.',
                  style: AppType.body.copyWith(
                    color: const Color(0xFFD7EADF),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    _HeroChip(
                        label: 'Rooms', icon: Icons.meeting_room_outlined),
                    SizedBox(width: 8),
                    _HeroChip(label: 'People', icon: Icons.groups_2_outlined),
                    SizedBox(width: 8),
                    _HeroChip(
                        label: 'Updates',
                        icon: Icons.bolt_rounded,
                        active: true),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: AppRadius.rMd,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: const [
                      _HeroStat(value: '6', label: 'Rooms'),
                      _Divider(),
                      _HeroStat(value: '14', label: 'Tenants'),
                      _Divider(),
                      _HeroStat(value: '₱4,500', label: 'Rent'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;

  const _HeroChip({
    required this.label,
    required this.icon,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFC7F26A)
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: AppRadius.rPill,
        border: Border.all(
          color: active
              ? const Color(0xFFC7F26A)
              : Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: active ? const Color(0xFF0A3D26) : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppType.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF0A3D26) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppType.h3.copyWith(
              color: Colors.white,
              fontSize: 19,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppType.caption.copyWith(
              fontSize: 10,
              color: const Color(0xFFB9D7C8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  final VoidCallback onPrivacy;

  const _LoginFooter({required this.onPrivacy});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.muted),
            const SizedBox(width: 5),
            Text(
              'Secured with scrypt · PostgreSQL · OTP',
              style: AppType.caption.copyWith(fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '© 2026 Jamester C. Mulato. All rights reserved.',
          textAlign: TextAlign.center,
          style: AppType.caption.copyWith(fontSize: 10.5),
        ),
        TextButton(
          onPressed: onPrivacy,
          child: const Text('Privacy Notice', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}
