import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/design_tokens.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';
import '../widgets/lottie_art.dart';
import '../widgets/premium/premium_kit.dart';
import '../widgets/tahanan_kit.dart';

/// "Your call" 11: safe password change with a strength meter, a rules
/// checklist and a success state.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _submitting = false;
  bool _done = false;
  bool _showCurrent = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [_current, _password, _confirm]) {
      controller.addListener(_clearError);
    }
  }

  void _clearError() {
    if (_error == null) return;
    setState(() => _error = null);
  }

  @override
  void dispose() {
    for (final controller in [_current, _password, _confirm]) {
      controller.removeListener(_clearError);
    }
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  int get _score {
    final value = _password.text;
    var score = 0;
    if (value.length >= 9) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score.clamp(0, 5);
  }

  String get _strengthLabel =>
      ['Very weak', 'Weak', 'Fair', 'Medium', 'Strong', 'Excellent'][_score];

  Color get _strengthColor => _score <= 1
      ? AppColors.danger
      : _score <= 3
          ? const Color(0xFFB45309)
          : AppColors.primary;

  bool get _longEnough => _password.text.length >= 9;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_password.text);
  bool get _hasDigit => RegExp(r'[0-9]').hasMatch(_password.text);
  bool get _matches =>
      _password.text.isNotEmpty && _password.text == _confirm.text;

  Future<void> _submit() async {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (!_longEnough) {
      setState(() => _error = 'Password must be at least 9 characters.');
      return;
    }
    if (!_hasUpper || !_hasDigit) {
      setState(() =>
          _error = 'Password must include an uppercase letter and a number.');
      return;
    }
    if (!_matches) {
      setState(() => _error = 'Mismatch Password');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await context.read<AppState>().changePassword(
            currentPassword: _current.text,
            newPassword: _password.text,
          );
      if (!mounted) return;
      Haptics.success();
      setState(() => _done = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not change the password. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const TBackButton(),
                        const SizedBox(width: 8),
                        Text('SECURITY', style: AppType.eyebrow),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GlassPanel(
                      padding: const EdgeInsets.all(20),
                      radius: AppRadius.xxl,
                      glow: true,
                      child: _done ? _success() : _form(),
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

  Widget _success() {
    return Column(
      children: [
        const LottieArt('check', size: 140),
        Text('Successfully Change Password',
            style: AppType.h2, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'You will be signed out of other sessions. Sign in again with the '
          'new password.',
          style: AppType.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        SheenButton(
          text: 'Back to log in',
          icon: Icons.login_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CHANGE PASSWORD', style: AppType.eyebrow),
                  const SizedBox(height: 4),
                  Text('Choose a new password', style: AppType.h2),
                ],
              ),
            ),
            const LottieArt('shield', size: 54),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Weak passwords are refused, and the last three passwords cannot be '
          'reused.',
          style: AppType.caption,
        ),
        const SizedBox(height: 18),
        PremiumField(
          controller: _current,
          label: 'Current Password',
          hint: 'Your current password',
          icon: AppIcons.lockLine,
          required: true,
          obscure: !_showCurrent,
          enabled: !_submitting,
          onChanged: (_) => setState(() => _error = null),
          suffix: IconButton(
            tooltip: _showCurrent ? 'Hide' : 'Show',
            onPressed: () => setState(() => _showCurrent = !_showCurrent),
            icon: Icon(
              _showCurrent
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 19,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        PremiumField(
          controller: _password,
          label: 'New Password',
          hint: 'At least 9 characters, uppercase and a number',
          icon: AppIcons.lockLine,
          required: true,
          obscure: !_showPassword,
          enabled: !_submitting,
          onChanged: (_) => setState(() => _error = null),
          suffix: IconButton(
            tooltip: _showPassword ? 'Hide' : 'Show',
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
        const SizedBox(height: 12),
        PremiumField(
          controller: _confirm,
          label: 'Re-enter New Password',
          hint: 'Type it again',
          icon: AppIcons.lockLine,
          required: true,
          obscure: !_showPassword,
          enabled: !_submitting,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 14),
        _strengthPanel(),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerBg.withValues(alpha: 0.8),
              borderRadius: AppRadius.rMd,
              border:
                  Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
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
          const SizedBox(height: 12),
        ],
        SheenButton(
          text: 'Change password',
          icon: Icons.shield_outlined,
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'The new password is hashed with scrypt before it is stored.',
            style: AppType.caption.copyWith(fontSize: 10.5),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _strengthPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
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
                _password.text.isEmpty
                    ? 'PASSWORD STRENGTH'
                    : _strengthLabel.toUpperCase(),
                style: AppType.eyebrow.copyWith(
                  color:
                      _password.text.isEmpty ? AppColors.muted : _strengthColor,
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
                    color:
                        i < _score ? _strengthColor : const Color(0xFFDCE9E1),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _rule('At least 9 characters', _longEnough),
          _rule('One uppercase letter', _hasUpper),
          _rule('One number', _hasDigit),
          _rule('Passwords match', _matches),
        ],
      ),
    );
  }

  Widget _rule(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 15,
            color: ok ? AppColors.primary : const Color(0xFFB3C6BA),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppType.caption.copyWith(
              color: ok ? AppColors.primary : AppColors.muted,
              fontWeight: ok ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
