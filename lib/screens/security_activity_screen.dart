import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../state/app_state.dart';
import '../widgets/tahanan_kit.dart';
import '../widgets/ui.dart';

/// Per-account security trail. Every user — owner or tenant — can see the
/// sign-ins and failed attempts on their own account, so they can tell when
/// someone tried to access it.
class SecurityActivityScreen extends StatefulWidget {
  const SecurityActivityScreen({super.key});

  @override
  State<SecurityActivityScreen> createState() => _SecurityActivityScreenState();
}

class _SecurityActivityScreenState extends State<SecurityActivityScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context
          .read<AppState>()
          .api
          .request('GET', '/api/security/activity');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(data as Map);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _label(String type) {
    switch (type) {
      case 'LOGIN_SUCCESS':
      case 'LOGIN_SUCCEEDED':
        return 'Signed in';
      case 'LOGIN_FAILED':
        return 'Failed sign-in attempt';
      case 'OTP_SENT':
        return 'Verification code sent';
      case 'OTP_FAILED':
        return 'Wrong verification code';
      case 'PASSWORD_CHANGED':
        return 'Password changed';
      case 'PASSWORD_RESET':
        return 'Password reset';
      case 'LOGOUT_ALL':
        return 'Signed out everywhere';
      case 'ACCOUNT_LOCKED':
        return 'Account temporarily locked';
      case 'IP_BLOCKED':
        return 'IP address temporarily blocked';
      case 'ACCOUNT_DISABLED':
        return 'Account disabled';
      case 'ADMIN_ACCESS_DENIED':
        return 'Admin access denied';
      case 'CSRF_REJECTED':
        return 'Cross-site request blocked';
      default:
        return type.replaceAll('_', ' ').toLowerCase();
    }
  }

  IconData _icon(String type) {
    if (type.contains('FAILED') ||
        type.contains('DENIED') ||
        type.contains('BLOCKED')) {
      return Icons.warning_amber_rounded;
    }
    if (type.contains('SUCCESS') ||
        type.contains('CHANGED') ||
        type.contains('RESET')) {
      return Icons.verified_user_outlined;
    }
    return Icons.shield_outlined;
  }

  String _when(String raw) {
    final value = DateTime.tryParse(raw)?.toLocal();
    if (value == null) return raw;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${months[value.month - 1]} ${value.day}, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final summary = (_data?['summary'] as Map?) ?? const {};
    final account = (_data?['account'] as Map?) ?? const {};
    final events = (_data?['events'] as List?) ?? const [];
    final locked = account['locked'] == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TahananBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const TBackRow(),
                Text(
                  'Security activity',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign-ins and attempts on ${account['username'] != null ? '@${account['username']}' : 'this account'}.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(
                              color: AppColors.danger, fontSize: 12.5),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_loading && _error == null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: locked
                          ? AppColors.danger.withValues(alpha: 0.08)
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: locked
                            ? AppColors.danger.withValues(alpha: 0.4)
                            : AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          locked
                              ? Icons.lock_clock_rounded
                              : Icons.lock_outline_rounded,
                          size: 18,
                          color: locked ? AppColors.danger : AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            locked
                                ? 'This account is temporarily locked after failed attempts.'
                                : 'This account is secured. Below are the latest sign-ins and attempts.',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat(
                        label: 'Sign-ins',
                        value: '${summary['signins'] ?? 0}',
                      ),
                      const SizedBox(width: 10),
                      _Stat(
                        label: 'Failed attempts',
                        value: '${summary['failures'] ?? 0}',
                        danger: ((summary['failures'] as num?) ?? 0) > 0,
                      ),
                      const SizedBox(width: 10),
                      _Stat(
                        label: 'Wrong codes',
                        value: '${summary['otp_failed'] ?? 0}',
                        danger: ((summary['otp_failed'] as num?) ?? 0) > 0,
                      ),
                    ],
                  ),
                  if (summary['last_signin'] != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Last sign-in: ${_when('${summary['last_signin']}')}',
                      style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Recent activity',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (events.isEmpty)
                    Text(
                      'No activity recorded yet.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    )
                  else
                    ...events.map((raw) {
                      final event = Map<String, dynamic>.from(raw as Map);
                      final type = '${event['event_type']}';
                      final ip = event['ip_address'];
                      final device = event['user_agent'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _icon(type),
                              size: 18,
                              color: type.contains('FAILED') ||
                                      type.contains('DENIED') ||
                                      type.contains('BLOCKED')
                                  ? AppColors.danger
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _label(type),
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      _when('${event['created_at']}'),
                                      if (ip != null) '$ip',
                                      if (device != null)
                                        '$device'.length > 40
                                            ? '${'$device'.substring(0, 40)}…'
                                            : '$device',
                                    ].join(' · '),
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;

  const _Stat({
    required this.label,
    required this.value,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: danger ? AppColors.danger : AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
