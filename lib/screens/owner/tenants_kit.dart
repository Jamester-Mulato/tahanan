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
// TENANTS REFERENCE KIT
// ==========================================================
//
// The tenant directory in the same language as the reference home. Every
// surface, chip, ring and press response comes from `home/home_kit.dart`,
// so the tab feels like the same product rather than a second design.

class TenantsBody extends StatefulWidget {
  final void Function(TenantModel tenant) onTenantTap;
  final void Function(TenantModel tenant) onTenantLongPress;
  final void Function(UnassignedAccount account) onAssociate;
  final void Function(UnassignedAccount account) onRemoveAccount;
  final VoidCallback onInvite;
  final VoidCallback onOpenRooms;

  const TenantsBody({
    super.key,
    required this.onTenantTap,
    required this.onTenantLongPress,
    required this.onAssociate,
    required this.onRemoveAccount,
    required this.onInvite,
    required this.onOpenRooms,
  });

  @override
  State<TenantsBody> createState() => _TenantsBodyState();
}

class _TenantsBodyState extends State<TenantsBody> {
  int _filter = 0;
  bool _byRoom = false;
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
    final tenants = s.tenants;
    final unassigned = s.unassigned;
    final paid =
        tenants.where((t) => _status(t.paymentStatus) == 'Paid').length;
    final partial =
        tenants.where((t) => _status(t.paymentStatus) == 'Partial').length;
    final due =
        tenants.where((t) => _status(t.paymentStatus) == 'Unpaid').length;
    final assigned =
        tenants.where((t) => t.roomId != null || t.roomNumber != null).length;
    final ratio = tenants.isEmpty ? 0.0 : paid / tenants.length;

    final filtered = tenants.where((t) {
      final status = _status(t.paymentStatus);
      final matchesFilter = switch (_filter) {
        1 => status == 'Paid',
        2 => status == 'Partial',
        3 => status == 'Unpaid',
        4 => false,
        _ => true,
      };
      if (!matchesFilter) return false;
      if (_query.isEmpty) return true;
      return t.fullName.toLowerCase().contains(_query) ||
          t.displayEmail.toLowerCase().contains(_query) ||
          (t.roomNumber ?? '').toLowerCase().contains(_query);
    }).toList();

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
            TenantsHeader(
              tenants: tenants.length,
              assigned: assigned,
              unassigned: unassigned.length,
              onInvite: widget.onInvite,
            ),
            const SizedBox(height: 14),
            TenantsSummary(
              total: tenants.length,
              paid: paid,
              partial: partial,
              due: due,
              ratio: ratio,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search name, email, or room',
                prefixIcon: Icon(AppIcons.search, size: 19),
              ),
            ),
            const SizedBox(height: 12),
            _FilterRow(
              index: _filter,
              onChanged: (i) => setState(() => _filter = i),
            ),
            const SizedBox(height: 12),
            _ViewToggle(
              byRoom: _byRoom,
              onChanged: (value) => setState(() => _byRoom = value),
            ),
            const SizedBox(height: 16),
            HomeSectionHeader(
              eyebrow: _byRoom ? 'Grouped by room' : 'Directory',
              title: _filter == 4
                  ? 'Loose accounts'
                  : '${filtered.length} '
                      '${filtered.length == 1 ? 'tenant' : 'tenants'}',
              trailing: HomeTag(
                text: _filter == 4 ? 'Unassigned' : 'Active',
                color: HomeStyle.emerald,
                background: const Color(0xFFE9F8EF),
                dot: false,
              ),
            ),
            if (_filter == 4)
              _UnassignedList(
                accounts: unassigned,
                onAssociate: widget.onAssociate,
                onRemove: widget.onRemoveAccount,
              )
            else if (filtered.isEmpty)
              _TenantsEmpty(
                query: _query,
                onInvite: widget.onInvite,
              )
            else if (_byRoom)
              _RoomGroupedList(
                tenants: filtered,
                rooms: s.rooms,
                onTap: widget.onTenantTap,
                onLongPress: widget.onTenantLongPress,
              )
            else
              _TenantList(
                tenants: filtered,
                onTap: widget.onTenantTap,
                onLongPress: widget.onTenantLongPress,
              ),
            const SizedBox(height: 18),
            TenantsLedger(
              paid: paid,
              partial: partial,
              due: due,
            ),
            const SizedBox(height: 18),
            HomeSectionHeader(
              eyebrow: 'Recent',
              title: 'People activity',
            ),
            _Panel(
              child: HomeTimeline(
                items: _activity(s),
              ),
            ),
            const SizedBox(height: 18),
            HomeSectionHeader(
              eyebrow: 'Share access',
              title: 'Invite a tenant',
            ),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send the house key. They sign in, join the house, then you attach them to a room.',
                    style: TextStyle(
                      color: HomeStyle.inkSoft,
                      fontSize: 11.5,
                      height: 1.5,
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
                          height: 46,
                          onPressed: widget.onOpenRooms,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TButton(
                          text: 'Share house key',
                          icon: AppIcons.key,
                          height: 46,
                          onPressed: widget.onInvite,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _TenantsFootnote(),
          ], slide: 0.06),
        ),
      ),
    );
  }

  List<HomeTimelineItem> _activity(AppState s) {
    final items = <HomeTimelineItem>[];
    for (final t in s.tenants.take(2)) {
      items.add(
        HomeTimelineItem(
          icon: AppIcons.personAdd,
          title: '${t.fullName} is in the house',
          meta: t.roomNumber == null
              ? 'Awaiting a room'
              : 'Room ${t.roomNumber} · ${_status(t.paymentStatus)}',
          tag: 'Tenant',
          color: HomeStyle.emerald,
        ),
      );
    }
    for (final a in s.unassigned.take(1)) {
      items.add(
        HomeTimelineItem(
          icon: AppIcons.personAdd,
          title: '${a.displayName} joined the house',
          meta: 'Waiting to be attached to a room',
          tag: 'Loose',
          color: const Color(0xFFB45309),
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        HomeTimelineItem(
          icon: AppIcons.groupLine,
          title: 'The directory is empty',
          meta: 'Invite the first tenant with the house key.',
          tag: 'Start',
        ),
      );
    }
    return items.take(4).toList();
  }

  static String _status(String? value) {
    final v = (value ?? 'paid').toLowerCase();
    if (v == 'paid') return 'Paid';
    if (v == 'partial') return 'Partial';
    return 'Unpaid';
  }
}

// ==========================================================
// HEADER
// ==========================================================

class TenantsHeader extends StatelessWidget {
  final int tenants;
  final int assigned;
  final int unassigned;
  final VoidCallback onInvite;

  const TenantsHeader({
    super.key,
    required this.tenants,
    required this.assigned,
    required this.unassigned,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'TENANT DIRECTORY',
          textAlign: TextAlign.center,
          style: tEyebrow(color: HomeStyle.inkFaint).copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 5),
        Text(
          'People',
          textAlign: TextAlign.center,
          style: AppType.h1.copyWith(fontSize: 26, letterSpacing: -1),
        ),
        const SizedBox(height: 4),
        Text(
          '$tenants ${tenants == 1 ? 'person' : 'people'} · '
          '$assigned in rooms · '
          '$unassigned ${unassigned == 1 ? 'loose account' : 'loose accounts'}',
          textAlign: TextAlign.center,
          style: tMeta(color: HomeStyle.inkSoft).copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 12),
        TButton(
          text: 'Invite tenant',
          icon: AppIcons.personAdd,
          height: 46,
          onPressed: onInvite,
        ),
      ],
    );
  }
}

// ==========================================================
// SUMMARY
// ==========================================================

class TenantsSummary extends StatelessWidget {
  final int total;
  final int paid;
  final int partial;
  final int due;
  final double ratio;

  const TenantsSummary({
    super.key,
    required this.total,
    required this.paid,
    required this.partial,
    required this.due,
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
              child: IgnorePointer(child: CustomPaint(painter: _TenantsAura())),
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
                          'PAYMENT HEALTH',
                          style: TextStyle(
                            color: HomeStyle.lime,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$paid of $total ${total == 1 ? 'tenant' : 'tenants'} fully paid',
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
                        const Text(
                          'Keep the ledger tidy and the house stays calm.',
                          style: TextStyle(
                            color: Color(0xFFC9E2D5),
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _SummaryNumber(value: '$paid', label: 'Paid'),
                            _SummaryLine(),
                            _SummaryNumber(value: '$partial', label: 'Partial'),
                            _SummaryLine(),
                            _SummaryNumber(value: '$due', label: 'Due'),
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

class _TenantsAura extends CustomPainter {
  const _TenantsAura();

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
  bool shouldRepaint(covariant _TenantsAura old) => false;
}

// ==========================================================
// FILTERS + VIEW
// ==========================================================

class _FilterRow extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _FilterRow({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['All', 'Paid', 'Partial', 'Due', 'Loose'];
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
          icon: switch (i) {
            1 => AppIcons.checkLine,
            2 => AppIcons.partial,
            3 => AppIcons.cancel,
            4 => AppIcons.personAdd,
            _ => null,
          },
          onTap: () => onChanged(i),
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool byRoom;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({required this.byRoom, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Group the directory',
            style: TextStyle(
              color: HomeStyle.inkFaint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        _ToggleChip(
          label: 'List',
          icon: AppIcons.articleLine,
          selected: !byRoom,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 6),
        _ToggleChip(
          label: 'By room',
          icon: AppIcons.roomLine,
          selected: byRoom,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      pressedScale: 0.96,
      highlightColor: Colors.black.withValues(alpha: 0.04),
      semanticsLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: AppMotion.settle,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? HomeStyle.forest : HomeStyle.mint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: selected ? Colors.white : HomeStyle.inkSoft,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : HomeStyle.inkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// TENANT LIST
// ==========================================================

class _TenantList extends StatelessWidget {
  final List<TenantModel> tenants;
  final void Function(TenantModel) onTap;
  final void Function(TenantModel) onLongPress;

  const _TenantList({
    required this.tenants,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tenants.length; i++) ...[
          ScrollReveal(
            index: i,
            child: TenantCard(
              tenant: tenants[i],
              onTap: () => onTap(tenants[i]),
              onLongPress: () => onLongPress(tenants[i]),
            ),
          ),
          if (i != tenants.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class TenantCard extends StatelessWidget {
  final TenantModel tenant;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TenantCard({
    super.key,
    required this.tenant,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final status = (tenant.paymentStatus ?? 'paid').toLowerCase();
    final color = status == 'paid'
        ? HomeStyle.emerald
        : status == 'partial'
            ? const Color(0xFFB45309)
            : const Color(0xFFB91C1C);
    final bg = status == 'paid'
        ? const Color(0xFFE9F8EF)
        : status == 'partial'
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2);
    final label = status == 'paid'
        ? 'Paid'
        : status == 'partial'
            ? 'Partial'
            : 'Unpaid';

    return PressableSurface(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
      pressedScale: AppMotion.cardPressScale,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: tenant.fullName,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface, AppColors.surface2],
          ),
          borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
          border: Border(
            top: BorderSide(
                color: (AppColors.dark
                    ? AppColors.border.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9))),
            right: BorderSide(
                color: (AppColors.dark
                    ? AppColors.border.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9))),
            bottom: BorderSide(
                color: (AppColors.dark
                    ? AppColors.border.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9))),
            left: BorderSide(
              color: color.withValues(alpha: 0.75),
              width: 4,
            ),
          ),
          boxShadow: HomeStyle.lift,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [HomeStyle.forest, HomeStyle.emerald],
                    ),
                  ),
                  child: Text(
                    _initials(tenant.fullName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenant.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeStyle.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tenant.roomNumber == null
                        ? 'Awaiting a room · ${tenant.displayEmail}'
                        : 'Room ${tenant.roomNumber} · ${tenant.displayEmail}',
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              AppIcons.chevron,
              size: 18,
              color: HomeStyle.inkFaint,
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'T';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _RoomGroupedList extends StatelessWidget {
  final List<TenantModel> tenants;
  final List<RoomModel> rooms;
  final void Function(TenantModel) onTap;
  final void Function(TenantModel) onLongPress;

  const _RoomGroupedList({
    required this.tenants,
    required this.rooms,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TenantModel>>{};
    for (final t in tenants) {
      final key = t.roomNumber ?? 'No room';
      groups.putIfAbsent(key, () => []).add(t);
    }
    final keys = groups.keys.toList()..sort((a, b) => a.compareTo(b));

    return Column(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          ScrollReveal(
            index: i,
            child: _RoomGroup(
              roomNumber: keys[i],
              tenants: groups[keys[i]]!,
              capacity: _capacityFor(keys[i]),
              onTap: onTap,
              onLongPress: onLongPress,
            ),
          ),
          if (i != keys.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  int _capacityFor(String roomNumber) {
    for (final r in rooms) {
      if (r.roomNumber == roomNumber) return r.capacity;
    }
    return 0;
  }
}

class _RoomGroup extends StatelessWidget {
  final String roomNumber;
  final List<TenantModel> tenants;
  final int capacity;
  final void Function(TenantModel) onTap;
  final void Function(TenantModel) onLongPress;

  const _RoomGroup({
    required this.roomNumber,
    required this.tenants,
    required this.capacity,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Row(
            children: [
              Icon(
                AppIcons.roomLine,
                size: 14,
                color: HomeStyle.emerald,
              ),
              const SizedBox(width: 5),
              Text(
                'Room $roomNumber',
                style: TextStyle(
                  color: HomeStyle.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                capacity == 0
                    ? '${tenants.length} in room'
                    : '${tenants.length}/$capacity beds',
                style: TextStyle(
                  color: HomeStyle.inkFaint,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < tenants.length; i++) ...[
          TenantCard(
            tenant: tenants[i],
            onTap: () => onTap(tenants[i]),
            onLongPress: () => onLongPress(tenants[i]),
          ),
          if (i != tenants.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ==========================================================
// UNASSIGNED
// ==========================================================

class _UnassignedList extends StatelessWidget {
  final List<UnassignedAccount> accounts;
  final void Function(UnassignedAccount) onAssociate;
  final void Function(UnassignedAccount) onRemove;

  const _UnassignedList({
    required this.accounts,
    required this.onAssociate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const _Panel(
        child: HomeEmpty(
          icon: AppIcons.shieldLine,
          title: 'No loose accounts',
          message: 'Everyone who joined is already attached to a tenant.',
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < accounts.length; i++) ...[
          ScrollReveal(
            index: i,
            child: UnassignedAccountCard(
              account: accounts[i],
              onAssociate: () => onAssociate(accounts[i]),
              onRemove: () => onRemove(accounts[i]),
            ),
          ),
          if (i != accounts.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class UnassignedAccountCard extends StatelessWidget {
  final UnassignedAccount account;
  final VoidCallback onAssociate;
  final VoidCallback onRemove;

  const UnassignedAccountCard({
    super.key,
    required this.account,
    required this.onAssociate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
        border: Border.all(color: HomeStyle.hairline),
        boxShadow: HomeStyle.lift,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.personAdd,
                  size: 18,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName.isEmpty
                          ? 'New account'
                          : account.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HomeStyle.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
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
              HomeTag(
                text: 'Unassigned',
                color: const Color(0xFFB45309),
                background: const Color(0xFFFEF3C7),
                dot: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TButton(
                  text: 'Associate',
                  icon: AppIcons.link,
                  height: 42,
                  onPressed: onAssociate,
                ),
              ),
              const SizedBox(width: 8),
              PressableSurface(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(12),
                pressedScale: 0.94,
                highlightColor: Colors.black.withValues(alpha: 0.05),
                semanticsLabel: 'Remove account',
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    AppIcons.personRemove,
                    size: 18,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// LEDGER
// ==========================================================

class TenantsLedger extends StatelessWidget {
  final int paid;
  final int partial;
  final int due;

  const TenantsLedger({
    super.key,
    required this.paid,
    required this.partial,
    required this.due,
  });

  @override
  Widget build(BuildContext context) {
    final total = paid + partial + due;
    final ratio = total == 0 ? 0.0 : paid / total;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYMENT RHYTHM',
            style: TextStyle(
              color: HomeStyle.inkFaint,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'How the house is paying',
            style: TextStyle(
              color: HomeStyle.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              HomeRing(
                value: ratio,
                size: 64,
                stroke: 7,
                center: HomeCount(
                  value: (ratio * 100).round(),
                  format: (v) => '${v.round()}%',
                  style: TextStyle(
                    color: HomeStyle.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _LedgerRow(
                      label: 'Paid in full',
                      value: paid,
                      color: HomeStyle.emerald,
                    ),
                    const SizedBox(height: 7),
                    _LedgerRow(
                      label: 'Partially paid',
                      value: partial,
                      color: const Color(0xFFB45309),
                    ),
                    const SizedBox(height: 7),
                    _LedgerRow(
                      label: 'Still due',
                      value: due,
                      color: const Color(0xFFB91C1C),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _LedgerRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: HomeStyle.inkSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ==========================================================
// EMPTY / PANEL / FOOTNOTE
// ==========================================================

class _TenantsEmpty extends StatelessWidget {
  final String query;
  final VoidCallback onInvite;

  const _TenantsEmpty({required this.query, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          HomeEmpty(
            icon: AppIcons.groupLine,
            title: query.isEmpty ? 'No tenants yet' : 'No matching tenants',
            message: query.isEmpty
                ? 'Invite the first person with the house key.'
                : 'Try a different name, email, or room.',
          ),
          const SizedBox(height: 12),
          TButton(
            text: 'Share house key',
            icon: AppIcons.key,
            height: 46,
            onPressed: onInvite,
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
        border: Border.all(color: HomeStyle.hairline),
        boxShadow: HomeStyle.lift,
      ),
      child: child,
    );
  }
}

class _TenantsFootnote extends StatelessWidget {
  const _TenantsFootnote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(AppIcons.tap, size: 13, color: HomeStyle.inkFaint),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Tap a person for their ledger. Long-press for status and removal.',
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
