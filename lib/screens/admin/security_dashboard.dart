import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../services/api_client.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/ui.dart';
import '../../core/app_colors.dart';

/// Admin-only, read-only security monitoring dashboard.
///
/// Data comes from GET /api/admin/security. The endpoint checks `is_admin`,
/// logs ADMIN_ACCESS_DENIED for normal users, and only logs
/// ADMIN_VIEWED_DASHBOARD on the initial load (not every 60 s refresh).
class AdminSecurityScreen extends StatefulWidget {
  const AdminSecurityScreen({super.key});

  @override
  State<AdminSecurityScreen> createState() => _AdminSecurityScreenState();
}

class _AdminSecurityScreenState extends State<AdminSecurityScreen> {
  final _username = TextEditingController();
  final _ip = TextEditingController();
  Timer? _refresh;

  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  String _event = '';
  String _from = '';
  String _to = '';
  DateTime? _lastUpdated;

  static const _eventOptions = <String>[
    'All events',
    'REGISTERED',
    'ACCOUNT_VERIFIED',
    'LOGIN_SUCCESS',
    'LOGIN_FAILED',
    'LOGIN_BLOCKED',
    'OTP_SENT',
    'OTP_FAILED',
    'LOCKOUT_TIER_1',
    'LOCKOUT_TIER_2',
    'LOCKOUT_TIER_3',
    'IP_BLOCKED',
    'ALERT_EMAIL_SENT',
    'ALERT_EMAIL_FAILED',
    'RESET_REQUESTED',
    'RESET_TOKEN_ISSUED',
    'PASSWORD_CHANGED',
    'CAPTCHA_FAILED',
    'RECAPTCHA_FAILED',
    'HONEYPOT_TRIGGERED',
    'CSRF_REJECTED',
    'ADMIN_VIEWED_DASHBOARD',
    'ADMIN_ACCESS_DENIED',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(true));
    _refresh = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _load(false),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _username.dispose();
    _ip.dispose();
    super.dispose();
  }

  Future<void> _load(bool logView) async {
    if (!mounted) return;
    if (_data == null) setState(() => _loading = true);
    try {
      final data = await context.read<AppState>().fetchAdminSecurity(
            from: _from,
            to: _to,
            event: _event,
            username: _username.text.trim(),
            ip: _ip.text.trim(),
            logView: logView,
          );
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the security log.';
      });
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDate: now,
    );
    if (picked == null || !mounted) return;
    final value =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (from) {
        _from = value;
      } else {
        _to = value;
      }
    });
    await _load(false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final summary = data == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(data['summary'] as Map? ?? {});
    final events = data == null
        ? const <dynamic>[]
        : (data['events'] as List? ?? const []);
    final denied = _error != null &&
        (_error!.toLowerCase().contains('access') ||
            _error!.toLowerCase().contains('admin'));

    return Scaffold(
      body: TahananBackground(
        child: RefreshIndicator(
          color: kPrimary,
          backgroundColor: AppColors.surface,
          onRefresh: () => _load(true),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: tScreenPadding(context),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  const TBackRow(),
                  TLightHeader(
                    icon: AppIcons.shieldLine,
                    eyebrow: 'Admin only',
                    title: 'Security monitoring',
                    subtitle:
                        'Read-only activity log and live security findings.',
                    stats: [
                      TStatData('${summary['logins'] ?? 0}', 'Logins today'),
                      TStatData('${summary['failed'] ?? 0}', 'Failed today'),
                      TStatData('${events.length}', 'Events shown'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_loading && data == null)
                    const TCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (denied)
                    TCard(
                      child: TEmpty(
                        icon: AppIcons.shieldLine,
                        title: 'Access denied',
                        message:
                            'This dashboard is for administrators. The attempt was recorded as ADMIN_ACCESS_DENIED.',
                      ),
                    )
                  else if (_error != null && data == null)
                    TCard(
                      child: TEmpty(
                        icon: AppIcons.alert,
                        title: 'Could not load the log',
                        message: _error!,
                      ),
                    )
                  else ...[
                    _SummaryGrid(summary: summary),
                    const SizedBox(height: 12),
                    _HourlyChart(
                      entries: (data?['hourly'] as List? ?? const []),
                    ),
                    const SizedBox(height: 12),
                    _TopIps(entries: (data?['topIps'] as List? ?? const [])),
                    const SizedBox(height: 12),
                    _Flags(entries: (data?['flags'] as List? ?? const [])),
                    const SizedBox(height: 18),
                    _FilterCard(
                      event: _event,
                      from: _from,
                      to: _to,
                      usernameController: _username,
                      ipController: _ip,
                      options: _eventOptions,
                      onEvent: (value) {
                        setState(
                          () => _event =
                              (value == null || value == 'All events')
                                  ? ''
                                  : value,
                        );
                        _load(false);
                      },
                      onApply: () => _load(false),
                      onClear: () {
                        _username.clear();
                        _ip.clear();
                        setState(() {
                          _event = '';
                          _from = '';
                          _to = '';
                        });
                        _load(false);
                      },
                      onFrom: () => _pickDate(from: true),
                      onTo: () => _pickDate(from: false),
                    ),
                    const SizedBox(height: 12),
                    _EventList(entries: events),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        _lastUpdated == null
                            ? 'Refreshing every 60 seconds'
                            : 'Updated ${tWhen(_lastUpdated)} · refreshes every 60 s · read-only',
                        textAlign: TextAlign.center,
                        style: tMeta().copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// SUMMARY
// ==========================================================

class _SummaryGrid extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Logins', summary['logins'], AppIcons.checkLine, kPrimary),
      ('Failed', summary['failed'], AppIcons.cancel, kDanger),
      ('Locked now', summary['locked'], AppIcons.lockLine, kWarning),
      ('IPs blocked', summary['blocked'], AppIcons.shieldLine, kInfo),
      ('OTP sent', summary['otp_sent'], AppIcons.email, kPrimary),
      ('OTP failed', summary['otp_failed'], AppIcons.alert, kWarning),
      ('Alerts sent', summary['alerts'], AppIcons.notifications, kInfo),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: width,
                child: _MetricTile(
                  label: tile.$1,
                  value: '${tile.$2 ?? 0}',
                  icon: tile.$3,
                  color: tile.$4,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TCard(
      padding: const EdgeInsets.all(13),
      ambient: 'drift',
      ambientOpacity: 0.09,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TIconSquare(icon: icon, size: 34, color: color),
              const Spacer(),
              Text(
                value,
                style: AppType.h2.copyWith(fontSize: 22, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: tEyebrow(color: kInkSoft).copyWith(fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// HOURLY CHART
// ==========================================================

class _HourlyChart extends StatelessWidget {
  final List<dynamic> entries;

  const _HourlyChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final counts = List<int>.filled(24, 0);
    for (final raw in entries) {
      final item = Map<String, dynamic>.from(raw as Map);
      final hour = int.tryParse('${item['hour']}'.split(':').first);
      if (hour != null && hour >= 0 && hour < 24) {
        counts[hour] = (item['failures'] as num?)?.toInt() ?? 0;
      }
    }
    final max = counts.fold<int>(1, (a, b) => b > a ? b : a);
    return TCard(
      ambient: 'flow',
      ambientOpacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('Failed logins · last 24 h', style: tSectionTitle()),
              ),
              Text('${counts.fold<int>(0, (a, b) => a + b)}',
                  style: tStat(color: kDanger).copyWith(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 24; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 4 + (counts[i] / max) * 82,
                            decoration: BoxDecoration(
                              color: counts[i] == 0
                                  ? kMintDeep
                                  : kDanger.withValues(alpha: 0.75),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            i % 6 == 0 ? '$i' : '',
                            style: tMeta().copyWith(fontSize: 7.5),
                          ),
                        ],
                      ),
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

// ==========================================================
// TOP IPS / FLAGS
// ==========================================================

class _TopIps extends StatelessWidget {
  final List<dynamic> entries;

  const _TopIps({required this.entries});

  @override
  Widget build(BuildContext context) {
    return TCard(
      ambient: 'halo',
      ambientOpacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top IP addresses · 24 h', style: tSectionTitle()),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text('No failed addresses in the last 24 hours.', style: tMeta()),
          for (var i = 0; i < entries.length; i++) ...[
            Builder(builder: (context) {
              final item = Map<String, dynamic>.from(entries[i] as Map);
              final blocked = item['blocked'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(AppIcons.link, size: 17, color: kPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item['ip_address'] ?? 'unknown'}',
                        style: tLabel(),
                      ),
                    ),
                    Text('${item['failures'] ?? 0} fails', style: tMeta()),
                    const SizedBox(width: 8),
                    TPill(
                      text: blocked ? 'Blocked' : 'Watching',
                      tone: blocked ? TPillTone.bad : TPillTone.neutral,
                    ),
                  ],
                ),
              );
            }),
            if (i != entries.length - 1) Divider(height: 1, color: kHairline),
          ],
        ],
      ),
    );
  }
}

class _Flags extends StatelessWidget {
  final List<dynamic> entries;

  const _Flags({required this.entries});

  @override
  Widget build(BuildContext context) {
    return TCard(
      ambient: 'aurora',
      ambientOpacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Monitoring flags', style: tSectionTitle())),
              TPill(
                text: '${entries.length} today',
                tone: entries.isEmpty ? TPillTone.ok : TPillTone.pending,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text('No findings written today.', style: tMeta()),
          for (var i = 0; i < entries.length; i++) ...[
            Builder(builder: (context) {
              final item = Map<String, dynamic>.from(entries[i] as Map);
              final high = '${item['severity']}'.toUpperCase() == 'HIGH';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TPill(
                      text: high ? 'HIGH' : 'MED',
                      tone: high ? TPillTone.bad : TPillTone.pending,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['pattern']} · ${item['target']}',
                              style: tLabel()),
                          const SizedBox(height: 1),
                          Text(
                            '${item['details'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tMeta().copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (i != entries.length - 1) Divider(height: 1, color: kHairline),
          ],
        ],
      ),
    );
  }
}

// ==========================================================
// FILTERS / EVENTS
// ==========================================================

class _FilterCard extends StatelessWidget {
  final String event;
  final String from;
  final String to;
  final TextEditingController usernameController;
  final TextEditingController ipController;
  final List<String> options;
  final ValueChanged<String?> onEvent;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final VoidCallback onFrom;
  final VoidCallback onTo;

  const _FilterCard({
    required this.event,
    required this.from,
    required this.to,
    required this.usernameController,
    required this.ipController,
    required this.options,
    required this.onEvent,
    required this.onApply,
    required this.onClear,
    required this.onFrom,
    required this.onTo,
  });

  @override
  Widget build(BuildContext context) {
    return TCard(
      ambient: 'flow',
      ambientOpacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter the log', style: tSectionTitle()),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey(event),
            initialValue: event.isEmpty ? 'All events' : event,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Event type'),
            items: [
              for (final option in options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: onEvent,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    isDense: true,
                  ),
                  onSubmitted: (_) => onApply(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: ipController,
                  decoration: const InputDecoration(
                    labelText: 'IP address',
                    isDense: true,
                  ),
                  onSubmitted: (_) => onApply(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFrom,
                  icon: const Icon(AppIcons.calendarLine, size: 16),
                  label: Text(from.isEmpty ? 'From date' : from),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTo,
                  icon: const Icon(AppIcons.calendarLine, size: 16),
                  label: Text(to.isEmpty ? 'To date' : to),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TButton(
                  text: 'Apply filters',
                  icon: AppIcons.search,
                  height: 44,
                  onPressed: onApply,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear filters',
                onPressed: onClear,
                icon: const Icon(AppIcons.refresh, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  final List<dynamic> entries;

  const _EventList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return TCard(
      ambient: 'drift',
      ambientOpacity: 0.07,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Recent events', style: tSectionTitle()),
              ),
              TPill(
                text: '${entries.length} / 50',
                tone: TPillTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (entries.isEmpty)
            Text('No events match these filters.', style: tMeta()),
          for (var i = 0; i < entries.length; i++) ...[
            Builder(builder: (context) {
              final item = Map<String, dynamic>.from(entries[i] as Map);
              final type = '${item['event_type'] ?? ''}';
              final bad = type.contains('FAILED') ||
                  type.contains('DENIED') ||
                  type.contains('LOCKOUT') ||
                  type.contains('BLOCKED');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TPill(
                          text: type,
                          tone: bad ? TPillTone.bad : TPillTone.ok,
                        ),
                        const Spacer(),
                        Text(
                          tWhen(DateTime.tryParse('${item['created_at']}')),
                          style: tMeta().copyWith(fontSize: 9.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item['username'] ?? 'unknown'} · ${item['ip_address'] ?? 'no IP'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tMeta().copyWith(fontSize: 10.5),
                    ),
                    if (item['user_agent'] != null)
                      Text(
                        '${item['user_agent']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tMeta(color: kInkMuted.withValues(alpha: 0.7))
                            .copyWith(fontSize: 9),
                      ),
                  ],
                ),
              );
            }),
            if (i != entries.length - 1) Divider(height: 1, color: kHairline),
          ],
        ],
      ),
    );
  }
}
