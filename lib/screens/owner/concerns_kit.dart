import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_motion.dart';
import '../../core/design_tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/pressable.dart';
import '../../widgets/scroll_reveal.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/ui.dart';
import 'home/home_kit.dart';
import '../../core/app_colors.dart';

// ==========================================================
// CONCERNS REFERENCE KIT
// ==========================================================

class ConcernsBody extends StatefulWidget {
  final void Function(ConcernModel concern) onConcernTap;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenTenants;

  const ConcernsBody({
    super.key,
    required this.onConcernTap,
    required this.onOpenRooms,
    required this.onOpenTenants,
  });

  @override
  State<ConcernsBody> createState() => _ConcernsBodyState();
}

class _ConcernsBodyState extends State<ConcernsBody> {
  int _filter = 0;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final all = s.concerns;
    final open = all.where((c) => _status(c) == 'Open').toList();
    final pending = all.where((c) => _status(c) == 'Pending').toList();
    final resolved = all.where((c) => _status(c) == 'Resolved').toList();

    final filtered = all.where((c) {
      final matchesFilter = switch (_filter) {
        1 => _status(c) == 'Open',
        2 => _status(c) == 'Pending',
        3 => _status(c) == 'Resolved',
        _ => true,
      };
      if (!matchesFilter) return false;
      if (_query.isEmpty) return true;
      return c.subject.toLowerCase().contains(_query) ||
          c.category.toLowerCase().contains(_query) ||
          (c.roomNumber ?? '').toLowerCase().contains(_query) ||
          (c.tenantName ?? '').toLowerCase().contains(_query);
    }).toList();

    final ratio = all.isEmpty ? 0.0 : resolved.length / all.length;

    return TahananBackground(
      child: RefreshIndicator(
        color: kPrimary,
        backgroundColor: AppColors.surface,
        onRefresh: s.refreshHouse,
        child: ListView(
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            HomeStyle.gutter,
            MediaQuery.paddingOf(context).top + 14,
            HomeStyle.gutter,
            132,
          ),
          children: revealAll([
            ConcernsHeader(
              total: all.length,
              open: open.length + pending.length,
              onOpenRooms: widget.onOpenRooms,
              onOpenTenants: widget.onOpenTenants,
            ),
            const SizedBox(height: 14),
            ConcernsSummary(
              total: all.length,
              open: open.length,
              pending: pending.length,
              resolved: resolved.length,
              ratio: ratio,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search subject, room, or category',
                prefixIcon: Icon(AppIcons.search, size: 19),
              ),
            ),
            const SizedBox(height: 12),
            _ConcernFilters(
              index: _filter,
              all: all.length,
              open: open.length,
              pending: pending.length,
              resolved: resolved.length,
              onChanged: (i) => setState(() => _filter = i),
            ),
            const SizedBox(height: 18),
            HomeSectionHeader(
              eyebrow: 'Inbox',
              title: _filter == 3
                  ? 'Resolved'
                  : _filter == 1
                      ? 'Open concerns'
                      : _filter == 2
                          ? 'Waiting'
                          : 'All concerns',
              trailing: HomeTag(
                text: '${filtered.length}',
                color: HomeStyle.emerald,
                background: const Color(0xFFE9F8EF),
                dot: false,
              ),
            ),
            if (filtered.isEmpty)
              _ConcernsEmpty(
                filter: _filter,
                onOpenRooms: widget.onOpenRooms,
              )
            else
              for (var i = 0; i < filtered.length; i++) ...[
                ScrollReveal(
                  index: i,
                  child: ConcernCard(
                    concern: filtered[i],
                    onTap: () => widget.onConcernTap(filtered[i]),
                  ),
                ),
                if (i != filtered.length - 1) const SizedBox(height: 9),
              ],
            const SizedBox(height: 18),
            ConcernInsights(concerns: all),
            const SizedBox(height: 18),
            HomeSectionHeader(
              eyebrow: 'Recent',
              title: 'Concern activity',
            ),
            _Panel(
              child: HomeTimeline(items: _activity(all)),
            ),
            const SizedBox(height: 18),
            _ConcernTriageCard(
              onOpenRooms: widget.onOpenRooms,
              onOpenTenants: widget.onOpenTenants,
            ),
            const SizedBox(height: 18),
            const _ConcernsFootnote(),
          ], slide: 0.06),
        ),
      ),
    );
  }

  List<HomeTimelineItem> _activity(List<ConcernModel> concerns) {
    final items = <HomeTimelineItem>[];
    for (final c in concerns.take(4)) {
      items.add(
        HomeTimelineItem(
          icon: _categoryIcon(c.category),
          title: c.subject,
          meta: '${c.tenantName ?? 'Tenant'} · '
              '${c.roomNumber == null ? 'No room' : 'Room ${c.roomNumber}'} · '
              '${_when(c.createdAt)}',
          tag: _status(c),
          color: _statusColor(c),
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        HomeTimelineItem(
          icon: AppIcons.checkLine,
          title: 'The desk is quiet',
          meta: 'New tenant reports will appear here.',
          tag: 'Clear',
        ),
      );
    }
    return items;
  }

  static String _status(ConcernModel c) {
    final status = c.status.toLowerCase();
    if (status == ConcernModel.statusResolved) return 'Resolved';
    if (status == ConcernModel.statusUnread) return 'Open';
    return 'Pending';
  }

  static Color _statusColor(ConcernModel c) {
    final status = _status(c);
    if (status == 'Resolved') return HomeStyle.emerald;
    if (status == 'Open') return const Color(0xFFB91C1C);
    return const Color(0xFFB45309);
  }

  static String _when(DateTime? at) {
    if (at == null) return 'just now';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${at.month}/${at.day}';
  }

  static IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'utility':
        return AppIcons.boltLine;
      case 'cleanliness':
        return AppIcons.cleaningLine;
      case 'security':
        return AppIcons.shieldLine;
      case 'noise':
        return AppIcons.volumeLine;
      case 'other':
        return AppIcons.moreHorizontal;
      default:
        return AppIcons.buildLine;
    }
  }
}

// ==========================================================
// HEADER
// ==========================================================

class ConcernsHeader extends StatelessWidget {
  final int total;
  final int open;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenTenants;

  const ConcernsHeader({
    super.key,
    required this.total,
    required this.open,
    required this.onOpenRooms,
    required this.onOpenTenants,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CONCERNS DESK',
          textAlign: TextAlign.center,
          style: tEyebrow(color: HomeStyle.inkFaint).copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 5),
        Text(
          'Concerns',
          textAlign: TextAlign.center,
          style: AppType.h1.copyWith(fontSize: 26, letterSpacing: -1),
        ),
        const SizedBox(height: 4),
        Text(
          '$total ${total == 1 ? 'report' : 'reports'} · '
          '$open ${open == 1 ? 'needs' : 'need'} attention',
          textAlign: TextAlign.center,
          style: tMeta(color: HomeStyle.inkSoft).copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TButton(
                text: 'Rooms',
                icon: AppIcons.roomLine,
                variant: TButtonVariant.secondary,
                height: 44,
                onPressed: onOpenRooms,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TButton(
                text: 'Tenants',
                icon: AppIcons.groupLine,
                variant: TButtonVariant.secondary,
                height: 44,
                onPressed: onOpenTenants,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ==========================================================
// SUMMARY
// ==========================================================

class ConcernsSummary extends StatelessWidget {
  final int total;
  final int open;
  final int pending;
  final int resolved;
  final double ratio;

  const ConcernsSummary({
    super.key,
    required this.total,
    required this.open,
    required this.pending,
    required this.resolved,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06301D), Color(0xFF0A4B30), Color(0xFF0F7A44)],
            stops: [0, 0.58, 1],
          ),
          borderRadius: BorderRadius.circular(HomeStyle.heroRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E06301D),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _ConcernAura())),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESOLUTION RATE',
                          style: TextStyle(
                            color: HomeStyle.lime,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$resolved of $total closed',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          open == 0
                              ? 'No open concerns. The house is calm.'
                              : '$open open · $pending waiting for a reply.',
                          style: const TextStyle(
                            color: Color(0xFFC9E2D5),
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _SummaryNumber(value: '$open', label: 'Open'),
                            _SummaryLine(),
                            _SummaryNumber(value: '$pending', label: 'Waiting'),
                            _SummaryLine(),
                            _SummaryNumber(value: '$resolved', label: 'Closed'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  HomeRing(
                    value: ratio,
                    size: 86,
                    stroke: 8,
                    track: Colors.white.withValues(alpha: 0.14),
                    colors: [HomeStyle.lime, Color(0xFF7DE2A2)],
                    center: HomeCount(
                      value: (ratio * 100).round(),
                      format: (v) => '${v.round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryNumber({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC9E2D5),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _ConcernAura extends CustomPainter {
  const _ConcernAura();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);
    final center = Offset(size.width * 0.94, -size.height * 0.08);
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(center, 38.0 * i, ring);
    }

    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    final path = Path()
      ..moveTo(0, size.height * 0.82)
      ..lineTo(size.width * 0.60, 0)
      ..lineTo(size.width * 0.84, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, sheen);
  }

  @override
  bool shouldRepaint(covariant _ConcernAura old) => false;
}

// ==========================================================
// FILTERS
// ==========================================================

class _ConcernFilters extends StatelessWidget {
  final int index;
  final int all;
  final int open;
  final int pending;
  final int resolved;
  final ValueChanged<int> onChanged;

  const _ConcernFilters({
    required this.index,
    required this.all,
    required this.open,
    required this.pending,
    required this.resolved,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      'All $all',
      'Open $open',
      'Waiting $pending',
      'Closed $resolved',
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        primary: false,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, i) => HomeChip(
          label: labels[i],
          selected: i == index,
          onTap: () => onChanged(i),
        ),
      ),
    );
  }
}

// ==========================================================
// CONCERN CARD
// ==========================================================

class ConcernCard extends StatelessWidget {
  final ConcernModel concern;
  final VoidCallback onTap;

  const ConcernCard({
    super.key,
    required this.concern,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _status(concern);
    final color = _statusColor(concern);
    final bg = status == 'Resolved'
        ? const Color(0xFFE9F8EF)
        : status == 'Open'
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFFEF3C7);

    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
      pressedScale: AppMotion.cardPressScale,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: concern.subject,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
          border: Border.all(
              color: (AppColors.dark
                  ? AppColors.border.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9))),
          boxShadow: HomeStyle.lift,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _categoryIcon(concern.category),
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        concern.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HomeStyle.ink,
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${concern.tenantName ?? 'Tenant'} · '
                        '${concern.roomNumber == null ? 'No room' : 'Room ${concern.roomNumber}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HomeStyle.inkFaint,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: HomeStyle.mint,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    concern.category.toUpperCase(),
                    style: TextStyle(
                      color: HomeStyle.inkSoft,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _when(concern.createdAt),
                  style: TextStyle(
                    color: HomeStyle.inkFaint,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (concern.rating != null) ...[
                  TStars(rating: concern.rating!, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${concern.rating}/5',
                    style: TextStyle(
                      color: HomeStyle.inkFaint,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else
                  Icon(
                    AppIcons.chevron,
                    size: 17,
                    color: HomeStyle.inkFaint,
                  ),
              ],
            ),
            if (concern.ownerResponse != null &&
                concern.ownerResponse!.isNotEmpty) ...[
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: HomeStyle.mint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppIcons.shieldLine,
                      size: 13,
                      color: HomeStyle.emerald,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        concern.ownerResponse!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HomeStyle.inkSoft,
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _status(ConcernModel c) {
    final status = c.status.toLowerCase();
    if (status == ConcernModel.statusResolved) return 'Resolved';
    if (status == ConcernModel.statusUnread) return 'Open';
    return 'Pending';
  }

  static Color _statusColor(ConcernModel c) {
    final status = _status(c);
    if (status == 'Resolved') return HomeStyle.emerald;
    if (status == 'Open') return const Color(0xFFB91C1C);
    return const Color(0xFFB45309);
  }

  static String _when(DateTime? at) {
    if (at == null) return 'just now';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${at.month}/${at.day}';
  }

  static IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'utility':
        return AppIcons.boltLine;
      case 'cleanliness':
        return AppIcons.cleaningLine;
      case 'security':
        return AppIcons.shieldLine;
      case 'noise':
        return AppIcons.volumeLine;
      case 'other':
        return AppIcons.moreHorizontal;
      default:
        return AppIcons.buildLine;
    }
  }
}

// ==========================================================
// INSIGHTS
// ==========================================================

class ConcernInsights extends StatelessWidget {
  final List<ConcernModel> concerns;

  const ConcernInsights({super.key, required this.concerns});

  @override
  Widget build(BuildContext context) {
    final categories = <String, int>{};
    for (final c in concerns) {
      categories[c.category.toLowerCase()] =
          (categories[c.category.toLowerCase()] ?? 0) + 1;
    }
    final entries = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty
        ? 1
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final resolved = concerns
        .where((c) => c.status.toLowerCase() == ConcernModel.statusResolved)
        .length;
    final withReply =
        concerns.where((c) => (c.ownerResponse ?? '').trim().isNotEmpty).length;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT PEOPLE REPORT',
            style: TextStyle(
              color: HomeStyle.inkFaint,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Concern mix',
            style: TextStyle(
              color: HomeStyle.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'No reports yet. This is a good thing.',
              style: TextStyle(
                color: HomeStyle.inkFaint,
                fontSize: 11,
                height: 1.5,
              ),
            )
          else
            for (final e in entries.take(5)) ...[
              _CategoryBar(
                label: e.key,
                value: e.value,
                max: max,
              ),
              const SizedBox(height: 7),
            ],
          const SizedBox(height: 6),
          Row(
            children: [
              _InsightPill(
                icon: AppIcons.checkLine,
                value: '$resolved',
                label: 'Resolved',
              ),
              const SizedBox(width: 8),
              _InsightPill(
                icon: AppIcons.chatLine,
                value: '$withReply',
                label: 'Replied',
              ),
              const SizedBox(width: 8),
              _InsightPill(
                icon: AppIcons.reportProblem,
                value: '${concerns.length}',
                label: 'Total',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;

  const _CategoryBar({
    required this.label,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max == 0 ? 0.0 : value / max;
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: HomeStyle.inkSoft,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: HomeStyle.mintDeep,
              valueColor: AlwaysStoppedAnimation<Color>(
                HomeStyle.emerald,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 18,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: HomeStyle.ink,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InsightPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: HomeStyle.mint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: HomeStyle.emerald),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: HomeStyle.ink,
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: HomeStyle.inkFaint,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// TRIAGE / EMPTY / PANEL
// ==========================================================

class _ConcernTriageCard extends StatelessWidget {
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenTenants;

  const _ConcernTriageCard({
    required this.onOpenRooms,
    required this.onOpenTenants,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Triage faster',
            style: TextStyle(
              color: HomeStyle.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Open the room or the tenant ledger while you write a reply.',
            style: TextStyle(
              color: HomeStyle.inkSoft,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TButton(
                  text: 'Open rooms',
                  icon: AppIcons.roomLine,
                  variant: TButtonVariant.secondary,
                  height: 44,
                  onPressed: onOpenRooms,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TButton(
                  text: 'Tenants',
                  icon: AppIcons.groupLine,
                  variant: TButtonVariant.secondary,
                  height: 44,
                  onPressed: onOpenTenants,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConcernsEmpty extends StatelessWidget {
  final int filter;
  final VoidCallback onOpenRooms;

  const _ConcernsEmpty({required this.filter, required this.onOpenRooms});

  @override
  Widget build(BuildContext context) {
    final title = filter == 1
        ? 'Nothing open'
        : filter == 2
            ? 'Nothing waiting'
            : filter == 3
                ? 'No resolved concerns yet'
                : 'No concerns reported';
    final message = filter == 1
        ? 'The house is calm. Anything new will appear here.'
        : filter == 2
            ? 'Every open report has a reply.'
            : filter == 3
                ? 'Resolved reports will collect here.'
                : 'Tenant reports will appear here as they come in.';
    return _Panel(
      child: Column(
        children: [
          HomeEmpty(
            icon: filter == 1 || filter == 3
                ? AppIcons.checkLine
                : AppIcons.chatLine,
            title: title,
            message: message,
          ),
          const SizedBox(height: 12),
          TButton(
            text: 'Check the rooms',
            icon: AppIcons.roomLine,
            height: 44,
            onPressed: onOpenRooms,
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
        border: Border.all(
            color: (AppColors.dark
                ? AppColors.border.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.9))),
        boxShadow: HomeStyle.lift,
      ),
      child: child,
    );
  }
}

class _ConcernsFootnote extends StatelessWidget {
  const _ConcernsFootnote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(AppIcons.tap, size: 13, color: HomeStyle.inkFaint),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Tap a concern to reply, change status, or rate the resolution.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HomeStyle.inkFaint,
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
