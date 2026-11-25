import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Client half of the handout idle-session rule (default 6 minutes, editable
/// at runtime from the admin site).
///
/// The backend enforces the same rule, except for administrators. This guard
/// shows a passive toast during the final warning window (“Signing out in
/// Ns…”), then signs out automatically. There is no blocking dialog and no
/// stay/sign-out prompt — any real interaction simply resets the timer.
///
/// Only real input (pointer/touch/scroll) counts as activity. Background
/// refreshes do not, and neither do rebuilds.
class IdleSessionGuard extends StatefulWidget {
  final bool enabled;
  final Widget child;

  /// Total idle time before sign-out.
  final Duration timeout;

  /// How long before the deadline the countdown toast appears.
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
  bool _expiring = false;
  OverlayEntry? _toast;
  final ValueNotifier<int> _secondsLeft = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant IdleSessionGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.timeout != widget.timeout ||
        oldWidget.warning != widget.warning) {
      _sync();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hideToast();
    _secondsLeft.dispose();
    super.dispose();
  }

  void _sync() {
    _ticker?.cancel();
    _lastActivity = DateTime.now();
    _expiring = false;
    _hideToast();
    if (!widget.enabled) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // Show the countdown on the first frame too, so a short timeout is
    // visible immediately after signing in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _tick();
    });
  }

  /// Any deliberate interaction pushes the deadline back.
  void _markActive() {
    if (!widget.enabled || _expiring) return;
    _lastActivity = DateTime.now();
    _hideToast();
  }

  void _tick() {
    if (!widget.enabled || _expiring) return;
    final idle = DateTime.now().difference(_lastActivity);
    if (idle >= widget.timeout) {
      unawaited(_expire());
      return;
    }

    final remaining = widget.timeout - idle;
    if (widget.warning > Duration.zero && remaining <= widget.warning) {
      final seconds = remaining.inSeconds.clamp(1, widget.warning.inSeconds);
      _secondsLeft.value = seconds;
      _showToast();
    }
  }

  void _showToast() {
    if (_toast != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _toast = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: 28,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1F14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x5527C46A)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ValueListenableBuilder<int>(
                valueListenable: _secondsLeft,
                builder: (context, seconds, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_clock_rounded,
                      size: 15,
                      color: Color(0xFF3DDC84),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Signing out in ${seconds}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
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
    overlay.insert(_toast!);
  }

  void _hideToast() {
    _toast?.remove();
    _toast = null;
  }

  Future<void> _expire() async {
    if (_expiring) return;
    _expiring = true;
    _ticker?.cancel();
    _hideToast();
    if (!mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final label = widget.timeout.inSeconds < 60
        ? '${widget.timeout.inSeconds} seconds'
        : '${widget.timeout.inMinutes} minutes';

    // Clears local state and revokes the token server-side.
    unawaited(context.read<AppState>().signOut());

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: 28,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1F14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x5527C46A)),
              ),
              child: Text(
                'Session ended after $label without activity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Timer(const Duration(seconds: 3), entry.remove);
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
