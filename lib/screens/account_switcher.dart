import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/design_tokens.dart';
import '../services/saved_accounts_store.dart';
import '../state/app_state.dart';
import '../widgets/lottie_art.dart';
import '../widgets/premium/premium_kit.dart';
import '../widgets/pressable.dart';

/// Opens the full-screen account chooser and returns the account the user
/// picked, or null when they choose "Use another account".
Future<SavedAccount?> showAccountSwitcher(BuildContext context) {
  return Navigator.of(context).push<SavedAccount>(
    PageRouteBuilder<SavedAccount>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, animation, __) => const AccountSwitcherScreen(),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppCurves.emphasizedDecel,
          reverseCurve: AppCurves.softIn,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class AccountSwitcherScreen extends StatefulWidget {
  const AccountSwitcherScreen({super.key});

  @override
  State<AccountSwitcherScreen> createState() => _AccountSwitcherScreenState();
}

class _AccountSwitcherScreenState extends State<AccountSwitcherScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );

  String _query = '';
  String? _removingId;

  @override
  void initState() {
    super.initState();
    _ambient.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ambient.stop();
    } else if (!_ambient.isAnimating) {
      _ambient.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _ambient.dispose();
    super.dispose();
  }

  List<SavedAccount> _filtered(List<SavedAccount> accounts) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return accounts;
    return accounts
        .where(
          (account) =>
              account.displayName.toLowerCase().contains(query) ||
              account.email.toLowerCase().contains(query) ||
              account.loginName.toLowerCase().contains(query),
        )
        .toList();
  }

  String _lastUsed(DateTime? time) {
    if (time == null) return 'Previously used on this device';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Last used just now';
    if (diff.inMinutes < 60) return 'Last used ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last used ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Last used ${diff.inDays}d ago';
    return 'Last used ${time.month}/${time.day}/${time.year}';
  }

  Future<void> _remove(SavedAccount account) async {
    Haptics.tap();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppTheme.scrim(AppColors.text.withValues(alpha: 0.42)),
      isScrollControlled: true,
      builder: (sheetContext) => _RemoveSheet(account: account),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _removingId = account.id);
    try {
      await context.read<AppState>().removeSavedAccount(account.id);
      Haptics.success();
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  void _choose(SavedAccount account) {
    Haptics.tap();
    Navigator.of(context).pop(account);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accounts = _filtered(state.savedAccounts);
    final hasMany = state.savedAccounts.length > 3;

    return Scaffold(
      body: AuroraBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(onBack: () => Navigator.of(context).pop(null)),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Hero(count: state.savedAccounts.length),
                          const SizedBox(height: 16),
                          if (hasMany) ...[
                            PremiumField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              label: 'Find an account',
                              hint: 'Name, username or email',
                              icon: Icons.search_rounded,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (state.savedAccounts.isEmpty)
                            _EmptyAccounts(
                              onContinue: () => Navigator.of(context).pop(null),
                            )
                          else if (accounts.isEmpty)
                            _NoMatches(
                              query: _query,
                              onClear: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          else
                            _AccountList(
                              accounts: accounts,
                              removingId: _removingId,
                              lastUsed: _lastUsed,
                              onChoose: _choose,
                              onRemove: _remove,
                            ),
                          const SizedBox(height: 16),
                          _ContinueAnother(
                            onTap: () {
                              Haptics.tap();
                              Navigator.of(context).pop(null);
                            },
                          ),
                          const SizedBox(height: 18),
                          _SecurityNote(ambient: _ambient),
                          const SizedBox(height: 10),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================
// CHROME
// ==============================================================

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 16, 2),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 2),
          Text('ACCOUNTS', style: AppType.eyebrow),
          const Spacer(),
          const LottieArt('pulse', size: 40),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final int count;

  const _Hero({required this.count});

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 0
                ? 'Welcome back'
                : '$count ${count == 1 ? 'account' : 'accounts'} on this device',
            style: AppType.h1.copyWith(fontSize: 27),
          ),
          const SizedBox(height: 5),
          Text(
            'Pick an account to continue. Saved credentials stay in the '
            'device keystore, never in plain text.',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

// ==============================================================
// LIST
// ==============================================================

class _AccountList extends StatelessWidget {
  final List<SavedAccount> accounts;
  final String? removingId;
  final String Function(DateTime?) lastUsed;
  final ValueChanged<SavedAccount> onChoose;
  final ValueChanged<SavedAccount> onRemove;

  const _AccountList({
    required this.accounts,
    required this.removingId,
    required this.lastUsed,
    required this.onChoose,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < accounts.length; i++) ...[
          Reveal(
            delay: Duration(milliseconds: 60 + i * 55),
            child: _AccountCard(
              account: accounts[i],
              index: i,
              removing: removingId == accounts[i].id,
              lastUsed: lastUsed(accounts[i].lastUsedAt),
              onTap: () => onChoose(accounts[i]),
              onRemove: () => onRemove(accounts[i]),
            ),
          ),
          if (i != accounts.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AccountCard extends StatefulWidget {
  final SavedAccount account;
  final int index;
  final bool removing;
  final String lastUsed;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _AccountCard({
    required this.account,
    required this.index,
    required this.removing,
    required this.lastUsed,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _down = false;

  static const _gradients = [
    [Color(0xFF0B4D2F), Color(0xFF16A356)],
    [Color(0xFF0F3E6B), Color(0xFF2F7FD1)],
    [Color(0xFF6B3F0B), Color(0xFFD08A2F)],
    [Color(0xFF3F0B52), Color(0xFF9A4FC7)],
  ];

  String get _initials {
    final parts = widget.account.displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'T';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final colors = _gradients[widget.index % _gradients.length];
    final remembered = account.remembersMe;
    final canAutofill = account.canAutofill;

    return Semantics(
      button: true,
      label: 'Sign in as ${account.displayName}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.removing ? null : widget.onTap,
        child: AnimatedScale(
          duration: AppTime.instant,
          scale: _down ? 0.986 : 1,
          child: AnimatedOpacity(
            duration: AppTime.fast,
            opacity: widget.removing ? 0.45 : 1,
            child: GlassPanel(
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
              radius: AppRadius.lg,
              blur: 14,
              tint: 0.74,
              child: Row(
                children: [
                  _Avatar(initials: _initials, colors: colors),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.bodyStrong.copyWith(
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            if (remembered) ...[
                              const SizedBox(width: 7),
                              const TagChip(text: 'Auto sign-in'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${account.loginName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(fontSize: 10.5),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              canAutofill
                                  ? Icons.bolt_rounded
                                  : Icons.history_rounded,
                              size: 12,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.lastUsed,
                              style: AppType.caption.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    children: [
                      IconButton(
                        tooltip: 'Remove from this device',
                        onPressed: widget.removing ? null : widget.onRemove,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: AppColors.muted,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final List<Color> colors;

  const _Avatar({required this.initials, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ==============================================================
// STATES
// ==============================================================

class _EmptyAccounts extends StatelessWidget {
  final VoidCallback onContinue;

  const _EmptyAccounts({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      radius: AppRadius.xxl,
      child: Column(
        children: [
          const LottieArt('empty', size: 150),
          const SizedBox(height: 4),
          Text(
            'No saved accounts yet',
            style: AppType.h2.copyWith(fontSize: 19),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            'Sign in once and choose "Remember this account" to keep it here.',
            style: AppType.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SheenButton(text: 'Use another account', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const _NoMatches({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      radius: AppRadius.lg,
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 30, color: AppColors.muted),
          const SizedBox(height: 8),
          Text(
            'No account matches "$query"',
            style: AppType.bodyStrong,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onClear, child: const Text('Clear search')),
        ],
      ),
    );
  }
}

class _ContinueAnother extends StatelessWidget {
  final VoidCallback onTap;

  const _ContinueAnother({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: AppRadius.rLg,
      pressedScale: 0.99,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        radius: AppRadius.lg,
        blur: 10,
        tint: 0.6,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.rSm,
              ),
              child: Icon(
                Icons.person_add_alt_1_outlined,
                size: 19,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Use another account', style: AppType.bodyStrong),
                  Text(
                    'Sign in with a different username',
                    style: AppType.caption.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  final Animation<double> ambient;

  const _SecurityNote({required this.ambient});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: ambient,
          builder: (context, child) {
            final pulse = 0.55 + math.sin(ambient.value * math.pi * 2) * 0.25;
            return Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: AppColors.muted.withValues(alpha: pulse),
            );
          },
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            'Passwords stay in the device keystore · the email code is still '
            'required every time',
            textAlign: TextAlign.center,
            style: AppType.caption.copyWith(fontSize: 10),
          ),
        ),
      ],
    );
  }
}

// ==============================================================
// REMOVE SHEET
// ==============================================================

class _RemoveSheet extends StatelessWidget {
  final SavedAccount account;

  const _RemoveSheet({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: AppRadius.rSm,
                ),
                child: Icon(
                  Icons.person_remove_outlined,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remove from this device?', style: AppType.h3),
                    Text(
                      account.displayName,
                      style: AppType.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'The saved password and auto sign-in for ${account.loginName} will '
            'be deleted from the keystore. The account itself is not deleted.',
            style: AppType.body,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.rPill,
                    ),
                    side: const BorderSide(color: Color(0xFFDCE9E1)),
                  ),
                  child: const Text('Keep'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SheenButton(
                  text: 'Remove',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F1D1D), Color(0xFFB91C1C)],
                  ),
                  onPressed: () {
                    Haptics.error();
                    Navigator.pop(context, true);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
