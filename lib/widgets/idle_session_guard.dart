import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../state/app_state.dart';

/// Client half of the handout idle-session rule (seed: 6 minutes).
///
/// The backend enforces the same rule in `middleware/auth.ts`
/// (`IDLE_TIMEOUT_SECONDS`, `last_activity_at`). This guard warns the user one
/// minute before the deadline and signs out locally + on the server, so the
/// screen never keeps showing protected data after the token is dead.
///
/// Only real input (pointer/touch/scroll) counts as activity. Background
/// refreshes do not, and neither do rebuilds.
class IdleSessionGuard extends StatefulWidget {
  final bool enabled;
  final Widget child;

  /// Total idle time before sign-out. Defaults to the seeded 6 minutes.
  final Duration timeout;

  /// How long before the deadline the warning appears. Defaults to 1 minute.
  final Duration warning;

  const IdleSessionGuard({
    super.key,
    required this.enabled,
    required this.child,
    this.timeout = const Duration(minutes: 6),
    this.warning = const Duration(minutes: 1),
  });

  @override
  State<IdleSessionGuard> createState() => _IdleSessionGuardState();
}

class _IdleSessionGuardState extends State<IdleSessionGuard> {
  Timer? _ticker;
  DateTime _lastActivity = DateTime.now();
  bool _warningOpen = false;
  bool _expiring = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant IdleSessionGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _sync();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _sync() {
    _ticker?.cancel();
    _lastActivity = DateTime.now();
    _warningOpen = false;
    _expiring = false;
    if (!widget.enabled) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Any deliberate interaction pushes the deadline back.
  void _markActive() {
    if (!widget.enabled || _warningOpen || _expiring) return;
    _lastActivity = DateTime.now();
  }

  void _tick() {
    if (!widget.enabled || _expiring || _warningOpen) return;
    final idle = DateTime.now().difference(_lastActivity);
    if (idle >= widget.timeout) {
      unawaited(_expire());
      return;
    }
    if (idle >= widget.timeout - widget.warning) {
      unawaited(_showWarning());
    }
  }

  Future<void> _showWarning() async {
    if (_warningOpen || _expiring || !mounted) return;
    _warningOpen = true;
    final stayed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _IdleWarningDialog(
        seconds: widget.warning.inSeconds,
        timeout: widget.timeout,
      ),
    );
    if (!mounted) return;
    _warningOpen = false;
    if (stayed == true) {
      _lastActivity = DateTime.now();
      return;
    }
    await _expire();
  }

  Future<void> _expire() async {
    if (_expiring) return;
    _expiring = true;
    _ticker?.cancel();
    if (!mounted) return;

    // Clears local state and revokes the token server-side.
    unawaited(context.read<AppState>().signOut());

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        title: Text('Signed out', style: AppType.h3),
        content: Text(
          'Your session ended after ${widget.timeout.inMinutes} minutes '
          'without activity, as required by the security policy.',
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Sign in again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _markActive(),
      onPointerSignal: (_) => _markActive(),
      child: widget.child,
    );
  }
}

class _IdleWarningDialog extends StatefulWidget {
  final int seconds;
  final Duration timeout;

  const _IdleWarningDialog({required this.seconds, required this.timeout});

  @override
  State<_IdleWarningDialog> createState() => _IdleWarningDialogState();
}

class _IdleWarningDialogState extends State<_IdleWarningDialog> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_left <= 1) {
        timer.cancel();
        Navigator.of(context).pop(false);
        return;
      }
      setState(() => _left -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      title: Text('Still there?', style: AppType.h3),
      content: Text(
        'You have been inactive for a while. For your security you will be '
        'signed out in $_left seconds.',
        style: AppType.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Sign out now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Stay signed in'),
        ),
      ],
    );
  }
}
