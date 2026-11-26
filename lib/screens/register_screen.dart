import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_config.dart';
import '../core/design_tokens.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';
import '../widgets/lottie_art.dart';
import '../widgets/premium/premium_kit.dart';
import '../widgets/privacy_notice.dart';
import '../widgets/recaptcha_box.dart';
import '../widgets/recaptcha_dialog.dart';
import 'login_otp.dart';

/// Four-step, handout-complete registration wizard.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _steps = ['Personal', 'Address', 'Tenancy', 'Account'];
  static const _stepTitles = [
    'Tell us who you are',
    'Where do you live?',
    'Your tenancy details',
    'Secure your account',
  ];
  static const _stepBlurbs = [
    'Your name, birthdate and the ID Number that identifies you.',
    'Six address fields, all required and validated on the server.',
    'The Government ID is encrypted with AES-256 before it is stored.',
    'Username, password, three security answers and your consent.',
  ];
  static const _questions = {
    'Q6': 'What was the first song you learned by heart?',
    'Q1': 'What was the name of your first pet?',
    'Q3': 'Who was your favorite teacher in high school?',
  };

  final _id = TextEditingController();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _family = TextEditingController();
  final _extensionOther = TextEditingController();
  final _purok = TextEditingController();
  final _barangay = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _country = TextEditingController(text: 'Philippines');
  final _zip = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _repassword = TextEditingController();
  final _governmentId = TextEditingController();
  final _emergency = TextEditingController();
  final _notes = TextEditingController();
  final _answerA = TextEditingController();
  final _answerB = TextEditingController();
  final _answerC = TextEditingController();
  final _captcha = TextEditingController();

  /// Protection 8 (honeypot). The field is present in the widget tree but
  /// never rendered, so a human cannot fill it. `_submit` sends whatever it
  /// holds; the server refuses the registration silently when it is non-empty.
  final _website = TextEditingController();

  String _extension = '';
  String _roomType = 'Single';
  DateTime? _birthdate;
  DateTime? _moveIn;
  bool _consent = false;
  bool _submitting = false;
  bool _showPassword = false;
  int _step = 0;
  String? _error;
  String? _idError;
  Map<String, String> _fieldErrors = {};

  RecaptchaConfig? _recaptchaConfig;
  String? _recaptchaToken;
  CaptchaChallenge? _captchaChallenge;
  bool _loadingCaptcha = false;

  /// Live username availability (handout 4.9). Null until the user types.
  String? _usernameStatus;
  bool? _usernameAvailable;
  Timer? _usernameTimer;

  String get _recaptchaBaseUrl =>
      AppConfig.apiBaseUrl.replaceFirst('127.0.0.1', 'localhost');

  /// Which error keys each input owns. Typing in a field clears that field's
  /// stale message immediately, so a corrected value never keeps showing the
  /// old complaint under it.
  late final Map<TextEditingController, List<String>> _fieldErrorKeys = {
    _id: ['id_number'],
    _first: ['first_name'],
    _middle: ['middle_name'],
    _family: ['family_name'],
    _extensionOther: ['name_extension'],
    _purok: ['address_purok'],
    _barangay: ['address_barangay'],
    _city: ['address_city'],
    _province: ['address_province'],
    _country: ['address_country'],
    _zip: ['address_zip'],
    _email: ['email'],
    _username: ['username'],
    _password: ['password', 'repassword'],
    _repassword: ['repassword', 'password'],
    _governmentId: ['government_id'],
    _emergency: ['emergency_contact'],
    _notes: ['tenancy_notes'],
    _answerA: ['answer_a'],
    _answerB: ['answer_b'],
    _answerC: ['answer_c'],
    _captcha: ['captcha'],
  };

  void _clearFieldErrors(TextEditingController controller) {
    final keys = _fieldErrorKeys[controller];
    if (keys == null) return;
    if (_error == null &&
        _idError == null &&
        !keys.any(_fieldErrors.containsKey)) {
      return;
    }
    setState(() {
      final next = Map<String, String>.from(_fieldErrors);
      for (final key in keys) {
        next.remove(key);
      }
      _fieldErrors = next;
      _error = null;
      _idError = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _username.addListener(_onUsernameChanged);
    _password.addListener(_onPasswordChanged);
    for (final controller in _fieldErrorKeys.keys) {
      controller.addListener(() => _clearFieldErrors(controller));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCaptchaMode();
    });
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _username.removeListener(_onUsernameChanged);
    _password.removeListener(_onPasswordChanged);
    for (final controller in [
      _id,
      _first,
      _middle,
      _family,
      _extensionOther,
      _purok,
      _barangay,
      _city,
      _province,
      _country,
      _zip,
      _email,
      _username,
      _password,
      _repassword,
      _governmentId,
      _emergency,
      _notes,
      _answerA,
      _answerB,
      _answerC,
      _captcha,
      _website
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  // ---------------- password strength (Weak / Medium / Strong) -------------

  bool get _longEnough => _password.text.length >= 9;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_password.text);
  bool get _hasDigit => RegExp(r'[0-9]').hasMatch(_password.text);
  bool get _hasSymbol => RegExp(r'[^A-Za-z0-9]').hasMatch(_password.text);

  int get _strengthScore {
    final value = _password.text;
    var score = 0;
    if (value.length >= 9) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (_hasSymbol) score++;
    return score.clamp(0, 5);
  }

  String get _strengthLabel {
    if (_password.text.isEmpty) return '';
    if (!_longEnough || !_hasUpper || !_hasDigit) return 'Weak';
    return _strengthScore >= 5 ? 'Strong' : 'Medium';
  }

  bool get _passwordIsWeak =>
      _password.text.isNotEmpty && _strengthLabel == 'Weak';

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  // ---------------- live username availability (handout 4.9) --------------

  void _onUsernameChanged() {
    _usernameTimer?.cancel();
    final value = _username.text.trim();
    if (value.isEmpty) {
      setState(() {
        _usernameStatus = null;
        _usernameAvailable = null;
      });
      return;
    }
    if (value.length < 7) {
      setState(() {
        _usernameStatus = 'Username must be at least 7 characters.';
        _usernameAvailable = false;
      });
      return;
    }
    if (value.length > 16) {
      setState(() {
        _usernameStatus = 'Username must be at most 16 characters.';
        _usernameAvailable = false;
      });
      return;
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(value)) {
      setState(() {
        _usernameStatus =
            'Username must start with a letter and use letters and digits only.';
        _usernameAvailable = false;
      });
      return;
    }

    setState(() {
      _usernameStatus = 'Checking availability…';
      _usernameAvailable = null;
    });
    _usernameTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final ok = await context.read<AppState>().usernameAvailable(value);
        if (!mounted || _username.text.trim() != value) return;
        setState(() {
          _usernameAvailable = ok;
          _usernameStatus =
              ok ? 'Username is available.' : 'That username is already taken.';
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _usernameAvailable = null;
          _usernameStatus = null;
        });
      }
    });
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
      if (mounted) setState(() => _captchaChallenge = challenge);
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

  Future<void> _pickDate({required bool birth}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birth ? DateTime(1998, 1, 1) : now,
      firstDate: birth ? DateTime(1900) : DateTime(2000, 1, 1),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (birth) {
        _birthdate = picked;
        _fieldErrors = Map<String, String>.from(_fieldErrors)
          ..remove('birthdate');
      } else {
        _moveIn = picked;
        _fieldErrors = Map<String, String>.from(_fieldErrors)
          ..remove('move_in_date');
      }
      _error = null;
    });
  }

  String? _date(DateTime? value) {
    if (value == null) return null;
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }

  int? get _age {
    final birth = _birthdate;
    if (birth == null) return null;
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  String? _problemForStep(int step) {
    switch (step) {
      case 0:
        if (!RegExp(r'^\d{4}-\d{4}$').hasMatch(_id.text.trim())) {
          return 'ID Number must follow the format xxxx-xxxx.';
        }
        if (_first.text.trim().length < 2) return 'Enter your first name.';
        if (_family.text.trim().length < 2) return 'Enter your family name.';
        if (_birthdate == null) return 'Select your birthdate.';
        if ((_age ?? 0) < 18) {
          return 'You must be at least 18 years old to register.';
        }
        return null;
      case 1:
        if (_purok.text.trim().length < 3) {
          return 'Enter your Purok / Street (3-50 characters).';
        }
        if (_barangay.text.trim().length < 2) return 'Enter your Barangay.';
        if (_city.text.trim().length < 2) {
          return 'Enter your Municipality / City.';
        }
        if (_province.text.trim().length < 2) return 'Enter your Province.';
        if (_country.text.trim().length < 2) return 'Enter your Country.';
        if (!RegExp(r'^\d{4}$').hasMatch(_zip.text.trim())) {
          return 'ZIP Code must be exactly 4 digits.';
        }
        return null;
      case 2:
        if (!RegExp(r'^\d{4}-\d{4}-\d{4}$')
            .hasMatch(_governmentId.text.trim())) {
          return 'Government ID Number must follow the format xxxx-xxxx-xxxx.';
        }
        if (_moveIn == null) return 'Select your move-in date.';
        if (!RegExp(r'^09\d{9}$').hasMatch(_emergency.text.trim())) {
          return 'Contact number must be 11 digits and start with 09.';
        }
        return null;
      default:
        if (!_email.text.contains('@') || !_email.text.contains('.')) {
          return 'Enter a valid email address.';
        }
        if (_username.text.trim().length < 7) {
          return 'Username must be at least 7 characters.';
        }
        if (_password.text.length < 9) {
          return 'Password must be at least 9 characters.';
        }
        if (_passwordIsWeak) {
          return 'Password must include an uppercase letter and a number.';
        }
        if (_password.text != _repassword.text) {
          return 'Passwords do not match.';
        }
        if (_answerA.text.trim().length < 2) {
          return 'Answer the first security question.';
        }
        if (_answerB.text.trim().length < 2) {
          return 'Answer the second security question.';
        }
        if (_answerC.text.trim().length < 2) {
          return 'Answer the third security question.';
        }
        if (!_consent) {
          return 'You must agree to the Privacy Notice to register.';
        }
        if (_recaptchaConfig?.enabled == true) {
          if (_recaptchaToken == null || _recaptchaToken!.isEmpty) {
            return 'Complete the Google reCAPTCHA verification.';
          }
        } else if (_captchaChallenge == null) {
          return 'Load the CAPTCHA challenge, then answer it.';
        } else if (_captcha.text.trim().isEmpty) {
          return 'Enter the CAPTCHA answer.';
        }
        return null;
    }
  }

  /// Handout 3.x/G2: an error should sit under its own field, not only in a
  /// list at the top. Known messages are routed to their field; the rest use
  /// the single summary banner.
  void _showProblem(String problem) {
    String? field;
    if (problem.startsWith('Username')) {
      field = 'username';
    } else if (problem == 'Enter a valid email address.') {
      field = 'email';
    } else if (problem.startsWith('Password must')) {
      field = 'password';
    } else if (problem.startsWith('Passwords do not match')) {
      field = 'repassword';
    } else if (problem.startsWith('Answer the first')) {
      field = 'answer_a';
    } else if (problem.startsWith('Answer the second')) {
      field = 'answer_b';
    } else if (problem.startsWith('Answer the third')) {
      field = 'answer_c';
    } else if (problem.startsWith('You must agree')) {
      field = 'consent';
    }

    setState(() {
      _error = field == null ? problem : null;
      if (field != null) {
        _fieldErrors = {..._fieldErrors, field: problem};
      }
    });
  }

  void _next() {
    final problem = _problemForStep(_step);
    if (problem != null) {
      Haptics.error();
      _showProblem(problem);
      return;
    }
    Haptics.tap();
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(0, 3);
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _error = null;
      _step--;
    });
  }

  Future<void> _submit() async {
    final problem = _problemForStep(3);
    if (problem != null) {
      Haptics.error();
      _showProblem(problem);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _fieldErrors = {};
    });

    final payload = <String, dynamic>{
      'id_number': _id.text.trim(),
      'first_name': _first.text.trim(),
      'middle_name': _middle.text.trim(),
      'family_name': _family.text.trim(),
      'name_extension': _extension,
      'name_extension_other': _extensionOther.text.trim(),
      'birthdate': _date(_birthdate),
      'age': '${_age ?? ''}',
      'address_purok': _purok.text.trim(),
      'address_barangay': _barangay.text.trim(),
      'address_city': _city.text.trim(),
      'address_province': _province.text.trim(),
      'address_country': _country.text.trim(),
      'address_zip': _zip.text.trim(),
      'email': _email.text.trim(),
      'username': _username.text.trim(),
      'password': _password.text,
      'repassword': _repassword.text,
      'government_id': _governmentId.text.trim(),
      'move_in_date': _date(_moveIn),
      'room_type': _roomType,
      'emergency_contact': _emergency.text.trim(),
      'tenancy_notes': _notes.text.trim(),
      'answer_a': _answerA.text.trim(),
      'answer_b': _answerB.text.trim(),
      'answer_c': _answerC.text.trim(),
      'consent': _consent,
      'website': _website.text.trim(),
      if (_recaptchaConfig?.enabled == true && _recaptchaToken != null)
        'recaptchaToken': _recaptchaToken
      else ...{
        'captchaId': _captchaChallenge?.id,
        'captchaAnswer': _captcha.text.trim(),
      },
    };

    try {
      final challenge = await context.read<AppState>().registerAccount(payload);
      if (!mounted) return;
      Haptics.success();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoginOtpScreen(
            challenge: challenge,
            username: _username.text.trim(),
            password: _password.text,
            rememberMe: false,
            registration: true,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      Haptics.error();
      final details = error.details;
      final fieldErrors = <String, String>{};
      if (details != null) {
        for (final entry in details.entries) {
          final value = entry.value;
          if (value is String) {
            fieldErrors[entry.key] = value;
          }
        }
      }
      final targetStep = _stepForField(fieldErrors.keys);
      setState(() {
        _fieldErrors = fieldErrors;
        _error = error.message;
        _recaptchaToken = null;
        if (targetStep != null) _step = targetStep;
      });
      if (_recaptchaConfig?.enabled != true) await _refreshCaptcha();
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Cannot reach the server right now. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  int? _stepForField(Iterable<String> keys) {
    const step0 = {
      'id_number',
      'first_name',
      'middle_name',
      'family_name',
      'name_extension',
      'birthdate'
    };
    const step1 = {
      'address_purok',
      'address_barangay',
      'address_city',
      'address_province',
      'address_country',
      'address_zip'
    };
    const step2 = {
      'government_id',
      'move_in_date',
      'room_type',
      'emergency_contact',
      'tenancy_notes'
    };
    for (final key in keys) {
      if (step0.contains(key)) return 0;
      if (step1.contains(key)) return 1;
      if (step2.contains(key)) return 2;
    }
    return keys.isEmpty ? null : 3;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      body: AuroraBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 900 : 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(onBack: _back),
                    const SizedBox(height: 10),
                    GlassPanel(
                      padding: EdgeInsets.all(wide ? 26 : 18),
                      radius: AppRadius.xxl,
                      blur: 20,
                      tint: 0.8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Protection 8: never painted, never read by a
                          // person, but present in the tree for a bot to trip.
                          Offstage(
                            offstage: true,
                            child: ExcludeSemantics(
                              child: TextField(
                                controller: _website,
                                autofillHints: const [AutofillHints.url],
                                decoration: const InputDecoration(
                                  labelText: 'Website',
                                ),
                              ),
                            ),
                          ),
                          _StepHeader(
                            step: _step,
                            total: _steps.length,
                            label: _steps[_step],
                            title: _stepTitles[_step],
                            blurb: _stepBlurbs[_step],
                          ),
                          const SizedBox(height: 18),
                          AnimatedSwitcher(
                            duration: AppTime.normal,
                            switchInCurve: AppCurves.emphasizedDecel,
                            switchOutCurve: AppCurves.softIn,
                            transitionBuilder: (child, animation) {
                              final slide = Tween<Offset>(
                                begin: const Offset(0.04, 0),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: _stepBody(wide),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.dangerBg.withValues(alpha: 0.8),
                                borderRadius: AppRadius.rMd,
                                border: Border.all(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      size: 18, color: AppColors.danger),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: AppType.caption.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              if (_step > 0) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _submitting ? null : _back,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: AppRadius.rPill,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFDCE9E1),
                                      ),
                                    ),
                                    child: const Text('Back'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                flex: 2,
                                child: SheenButton(
                                  text: _step == 3
                                      ? 'Create account'
                                      : 'Continue',
                                  icon: _step == 3
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                  loading: _submitting,
                                  onPressed: _submitting
                                      ? null
                                      : (_step == 3 ? _submit : _next),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '© 2026 Jamester C. Mulato. All rights reserved.',
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(fontSize: 10),
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

  Widget _stepBody(bool wide) {
    switch (_step) {
      case 0:
        return Column(
          children: [
            _row(wide, [
              PremiumField(
                controller: _id,
                label: 'ID Number',
                hint: 'xxxx-xxxx',
                icon: AppIcons.personLine,
                required: true,
                keyboardType: TextInputType.number,
                error: _idError ?? _fieldErrors['id_number'],
                onChanged: (value) {
                  final trimmed = value.trim();
                  setState(() {
                    if (trimmed.isEmpty) {
                      _idError = null;
                    } else if (!RegExp(r'^\d{4}-\d{4}$').hasMatch(trimmed)) {
                      _idError = 'ID Number must follow the format xxxx-xxxx.';
                    } else {
                      _idError = null;
                    }
                  });
                },
              ),
              _dateField('Birthdate', _birthdate, () => _pickDate(birth: true),
                  error: _fieldErrors['birthdate']),
            ]),
            const SizedBox(height: 12),
            _row(wide, [
              PremiumField(
                controller: _first,
                label: 'First Name',
                hint: 'Juan',
                icon: AppIcons.personLine,
                required: true,
                error: _fieldErrors['first_name'],
              ),
              PremiumField(
                controller: _middle,
                label: 'Middle Name',
                hint: 'Optional',
                icon: AppIcons.personLine,
                optional: true,
                error: _fieldErrors['middle_name'],
              ),
            ]),
            const SizedBox(height: 12),
            _row(wide, [
              PremiumField(
                controller: _family,
                label: 'Family Name',
                hint: 'Dela Cruz',
                icon: AppIcons.personLine,
                required: true,
                error: _fieldErrors['family_name'],
              ),
              _extensionField(),
            ]),
            if (_extension == 'Other') ...[
              const SizedBox(height: 12),
              PremiumField(
                controller: _extensionOther,
                label: 'Extension',
                hint: 'I, II, III, IV, IX or X',
                icon: AppIcons.personLine,
                error: _fieldErrors['name_extension'],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                borderRadius: AppRadius.rMd,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    _age == null
                        ? 'Age is calculated from your birthdate'
                        : 'Age: $_age (must be 18 or older)',
                    style: AppType.caption,
                  ),
                ],
              ),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            _row(wide, [
              PremiumField(
                controller: _purok,
                label: 'Purok / Street',
                hint: 'Purok 3',
                icon: AppIcons.homeLine,
                required: true,
                error: _fieldErrors['address_purok'],
              ),
              PremiumField(
                controller: _barangay,
                label: 'Barangay',
                hint: 'San Jose',
                icon: AppIcons.homeLine,
                required: true,
                error: _fieldErrors['address_barangay'],
              ),
            ]),
            const SizedBox(height: 12),
            _row(wide, [
              PremiumField(
                controller: _city,
                label: 'Municipality / City',
                hint: 'Butuan City',
                icon: AppIcons.homeLine,
                required: true,
                error: _fieldErrors['address_city'],
              ),
              PremiumField(
                controller: _province,
                label: 'Province',
                hint: 'Agusan Del Norte',
                icon: AppIcons.homeLine,
                required: true,
                error: _fieldErrors['address_province'],
              ),
            ]),
            const SizedBox(height: 12),
            _row(wide, [
              PremiumField(
                controller: _country,
                label: 'Country',
                hint: 'Philippines',
                icon: AppIcons.homeLine,
                required: true,
                error: _fieldErrors['address_country'],
              ),
              PremiumField(
                controller: _zip,
                label: 'ZIP Code',
                hint: '8600',
                icon: AppIcons.homeLine,
                required: true,
                keyboardType: TextInputType.number,
                error: _fieldErrors['address_zip'],
              ),
            ]),
          ],
        );
      case 2:
        return Column(
          children: [
            _row(wide, [
              PremiumField(
                controller: _governmentId,
                label: 'Government ID Number',
                hint: 'xxxx-xxxx-xxxx',
                icon: Icons.badge_outlined,
                required: true,
                error: _fieldErrors['government_id'],
              ),
              _dateField('Move-in Date', _moveIn, () => _pickDate(birth: false),
                  error: _fieldErrors['move_in_date']),
            ]),
            const SizedBox(height: 12),
            _row(wide, [
              _dropdownField(),
              PremiumField(
                controller: _emergency,
                label: 'Emergency Contact',
                hint: '09xxxxxxxxx',
                icon: Icons.call_outlined,
                required: true,
                keyboardType: TextInputType.phone,
                error: _fieldErrors['emergency_contact'],
              ),
            ]),
            const SizedBox(height: 12),
            PremiumField(
              controller: _notes,
              label: 'Tenancy Notes',
              hint: 'Optional notes for the administrator',
              icon: Icons.notes_rounded,
              optional: true,
              maxLines: 3,
              error: _fieldErrors['tenancy_notes'],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF9F0),
                borderRadius: AppRadius.rMd,
                border: Border.all(color: const Color(0xFFD3F3DF)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your Government ID is encrypted with AES-256-GCM and '
                      'only decrypted for you and the administrator.',
                      style: AppType.caption.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return Column(
          children: [
            _row(wide, [
              PremiumField(
                controller: _email,
                label: 'Email address',
                hint: 'name@school.edu.ph',
                icon: Icons.mail_outline_rounded,
                required: true,
                keyboardType: TextInputType.emailAddress,
                error: _fieldErrors['email'],
              ),
              PremiumField(
                controller: _username,
                label: 'Username',
                hint: '7-16 letters and digits',
                icon: AppIcons.personLine,
                required: true,
                error: _fieldErrors['username'],
              ),
            ]),
            if (_usernameStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Row(
                  children: [
                    Icon(
                      _usernameAvailable == null
                          ? Icons.hourglass_empty_rounded
                          : _usernameAvailable!
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                      size: 14,
                      color: _usernameAvailable == null
                          ? AppColors.muted
                          : _usernameAvailable!
                              ? AppColors.primary
                              : AppColors.danger,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _usernameStatus!,
                        style: AppType.caption.copyWith(
                          fontSize: 10.5,
                          color: _usernameAvailable == null
                              ? AppColors.muted
                              : _usernameAvailable!
                                  ? AppColors.primary
                                  : AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _row(wide, [
              PremiumField(
                controller: _password,
                label: 'Password',
                hint: 'At least 9 characters, uppercase and a number',
                icon: AppIcons.lockLine,
                required: true,
                obscure: !_showPassword,
                error: _fieldErrors['password'],
                suffix: IconButton(
                  tooltip: _showPassword ? 'Hide' : 'Show',
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: AppColors.muted,
                  ),
                ),
              ),
              PremiumField(
                controller: _repassword,
                label: 'Re-enter Password',
                hint: 'Type it again',
                icon: AppIcons.lockLine,
                required: true,
                obscure: !_showPassword,
                error: _fieldErrors['repassword'],
              ),
            ]),
            const SizedBox(height: 10),
            _passwordStrengthPanel(),
            const SizedBox(height: 16),
            _answersAndConsent(),
          ],
        );
    }
  }

  Widget _passwordStrengthPanel() {
    final label = _strengthLabel;
    final color = label == 'Weak'
        ? AppColors.danger
        : label == 'Medium'
            ? const Color(0xFFB45309)
            : AppColors.primary;
    final filled = _password.text.isEmpty ? 0 : _strengthScore;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.isEmpty ? 'PASSWORD STRENGTH' : label.toUpperCase(),
                style: AppType.eyebrow.copyWith(
                  fontSize: 9,
                  color: label.isEmpty ? AppColors.muted : color,
                ),
              ),
              const Spacer(),
              for (var i = 0; i < 5; i++) ...[
                AnimatedContainer(
                  duration: AppTime.fast,
                  width: 18,
                  height: 5,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.rPill,
                    color: i < filled ? color : const Color(0xFFDCE9E1),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _strengthRule('At least 9 characters', _longEnough),
          _strengthRule('One uppercase letter', _hasUpper),
          _strengthRule('One number', _hasDigit),
          if (_passwordIsWeak)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'A weak password cannot be submitted.',
                style: AppType.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _strengthRule(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 13,
            color: ok ? AppColors.primary : const Color(0xFFA9BDB2),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppType.caption.copyWith(
              fontSize: 10,
              color: ok ? AppColors.text : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _answersAndConsent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('SECURITY QUESTIONS', style: AppType.eyebrow),
        const SizedBox(height: 8),
        PremiumField(
          controller: _answerA,
          label: _questions['Q6']!,
          hint: 'Your answer',
          icon: AppIcons.shieldLine,
          required: true,
          error: _fieldErrors['answer_a'],
        ),
        const SizedBox(height: 10),
        PremiumField(
          controller: _answerB,
          label: _questions['Q1']!,
          hint: 'Your answer',
          icon: AppIcons.shieldLine,
          required: true,
          error: _fieldErrors['answer_b'],
        ),
        const SizedBox(height: 10),
        PremiumField(
          controller: _answerC,
          label: _questions['Q3']!,
          hint: 'Your answer',
          icon: AppIcons.shieldLine,
          required: true,
          error: _fieldErrors['answer_c'],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 26,
              width: 26,
              child: Checkbox(
                value: _consent,
                onChanged: (value) => setState(() {
                  _consent = value ?? false;
                  if (_consent) {
                    _fieldErrors = Map<String, String>.from(_fieldErrors)
                      ..remove('consent');
                    _error = null;
                  }
                }),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'I have read the Privacy Notice and agree to the collection and '
                'processing of my personal data in accordance with the Data '
                'Privacy Act of 2012 (RA 10173).',
                style: AppType.caption.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showPrivacyNotice(context),
            icon: const Icon(AppIcons.articleLine, size: 15),
            label: Text(
              'Read the Privacy Notice',
              style: AppType.caption.copyWith(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (_fieldErrors['consent'] != null)
          Text(
            _fieldErrors['consent']!,
            style: AppType.caption.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 14),
        if (_recaptchaConfig == null)
          const RecaptchaLoadingCard()
        else if (_recaptchaConfig!.enabled)
          _recaptchaBox()
        else
          _captchaBox(),
      ],
    );
  }

  Widget _row(bool wide, List<Widget> children) {
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    VoidCallback onTap, {
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              ' *',
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.rMd,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.72),
              borderRadius: AppRadius.rMd,
              border: Border.all(
                color: error != null
                    ? AppColors.danger.withValues(alpha: 0.55)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 18, color: Color(0xFF8AA395)),
                const SizedBox(width: 10),
                Text(
                  _date(value) ?? 'Select a date',
                  style: AppType.bodyStrong.copyWith(
                    color: value == null
                        ? const Color(0xFF9AB0A3)
                        : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              error,
              style: AppType.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _dropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Room Type *',
          style: AppType.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.72),
            borderRadius: AppRadius.rMd,
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _roomType,
              isExpanded: true,
              borderRadius: AppRadius.rMd,
              items: const ['Single', 'Shared', 'Bedspacer', 'Studio']
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => setState(() {
                _roomType = value ?? 'Single';
                _fieldErrors = Map<String, String>.from(_fieldErrors)
                  ..remove('room_type');
                _error = null;
              }),
            ),
          ),
        ),
        if (_fieldErrors['room_type'] != null)
          Text(
            _fieldErrors['room_type']!,
            style: AppType.caption.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _extensionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Name Extension',
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              ' optional',
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.72),
            borderRadius: AppRadius.rMd,
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _extension,
              isExpanded: true,
              borderRadius: AppRadius.rMd,
              items: const ['', 'Jr.', 'Sr.', 'Other']
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.isEmpty ? 'None' : item),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                _extension = value ?? '';
                _fieldErrors = Map<String, String>.from(_fieldErrors)
                  ..remove('name_extension');
                _error = null;
              }),
            ),
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
          ),
        ],
      ),
    );
  }
}

// ==============================================================
// HEADER
// ==============================================================

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 2),
        Text('REGISTRATION', style: AppType.eyebrow),
        const Spacer(),
        const LottieArt('shield', size: 44),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final int total;
  final String label;
  final String title;
  final String blurb;

  const _StepHeader({
    required this.step,
    required this.total,
    required this.label,
    required this.title,
    required this.blurb,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: AppTime.normal,
                  curve: AppCurves.emphasized,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.rPill,
                    gradient: i <= step
                        ? const LinearGradient(
                            colors: [Color(0xFF0B4D2F), Color(0xFF16A356)],
                          )
                        : null,
                    color: i <= step ? null : const Color(0xFFDCE9E1),
                  ),
                ),
              ),
              if (i != total - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'STEP ${step + 1} OF $total · ${label.toUpperCase()}',
          style: AppType.eyebrow,
        ),
        const SizedBox(height: 4),
        Text(title, style: AppType.h2),
        const SizedBox(height: 4),
        Text(blurb, style: AppType.caption),
      ],
    );
  }
}
