import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../models/models.dart';
import '../../routing/liquid_page_route.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/pressable.dart';
import '../../widgets/scroll_reveal.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/ui.dart';
import 'announcements.dart';
import 'concerns.dart';
import 'home/home_kit.dart';
import 'owner_search.dart';
import 'room_detail.dart';
import 'rooms.dart';
import '../../core/app_colors.dart';

/// The reference home window.
///
/// This is the visual and behavioural benchmark for every other tab: the
/// same header rhythm, hairline cards, outlined icons, emerald accents,
/// first-frame press feedback and calm section spacing. Other screens should
/// reuse the widgets in `home/home_kit.dart` rather than inventing new ones.
class OwnerHomeScreen extends StatefulWidget {
  final void Function(int)? onNavigateTab;

  const OwnerHomeScreen({super.key, this.onNavigateTab});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _segment = 0;
  final _peopleSearch = TextEditingController();
  String _peopleQuery = '';

  @override
  void dispose() {
    _peopleSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final d = s.dashboard;
    final h = s.selected;

    if (d == null || h == null) {
      return _LoadingHome(s: s);
    }

    final firstName = (s.user?.displayName ?? 'there').split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    final totalBeds = s.rooms.fold<int>(0, (sum, r) => sum + r.capacity);
    final occupiedBeds = s.rooms.fold<int>(0, (sum, r) => sum + r.occupied);
    final openBeds = (totalBeds - occupiedBeds).clamp(0, totalBeds);
    final occupancy = totalBeds == 0 ? 0.0 : occupiedBeds / totalBeds;
    final unpaid = s.tenants
        .where((t) => (t.paymentStatus ?? 'paid').toLowerCase() != 'paid')
        .length;
    final openConcerns = s.concerns
        .where((c) => c.status.toLowerCase() != ConcernModel.statusResolved)
        .length;

    final topPad = MediaQuery.paddingOf(context).top;

    return RefreshIndicator(
      color: kPrimary,
      backgroundColor: AppColors.surface,
      onRefresh: s.refreshHouse,
      child: ListView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          HomeStyle.gutter,
          topPad + 14,
          HomeStyle.gutter,
          132,
        ),
        children: [
          ScrollReveal(
            index: 0,
            child: _HomeHeader(
              greeting: greeting,
              firstName: firstName,
              houseName: h.name,
              domain: h.domain,
              unread: openConcerns,
              onAvatar: () => widget.onNavigateTab?.call(4),
              onSearch: () => _openSearch(context),
              onBell: () => _openNotifications(context),
              onHouse: () => _openHouseSheet(context),
            ),
          ),
          const SizedBox(height: 14),
          ScrollReveal(
            index: 1,
            child: HomeSearchPill(
              hint: 'Search rooms, tenants, notices',
              onTap: () => _openSearch(context),
            ),
          ),
          const SizedBox(height: 14),
          ScrollReveal(
            index: 2,
            child: HomeHero(
              eyebrow: 'Owner dashboard',
              title: '$greeting, $firstName',
              subtitle: h.name,
              badge: openConcerns == 0
                  ? 'Everything is quiet'
                  : '$openConcerns open ${openConcerns == 1 ? 'concern' : 'concerns'}',
              occupancy: occupancy,
              rooms: s.rooms.isEmpty ? d.rooms : s.rooms.length,
              tenants: s.tenants.isEmpty ? d.tenants : s.tenants.length,
              openBeds: openBeds,
              onRooms: () => widget.onNavigateTab?.call(1),
              onTenants: () => widget.onNavigateTab?.call(2),
              onConcerns: () => widget.onNavigateTab?.call(3),
            ),
          ),
          const SizedBox(height: 14),
          ScrollReveal(
            index: 3,
            child: _AttentionStrip(
              unpaid: unpaid,
              openConcerns: openConcerns,
              openBeds: openBeds,
              onConcerns: () => widget.onNavigateTab?.call(3),
              onTenants: () => widget.onNavigateTab?.call(2),
              onRooms: () => widget.onNavigateTab?.call(1),
            ),
          ),
          const SizedBox(height: 14),
          ScrollReveal(
            index: 4,
            child: Row(
              children: [
                Expanded(
                  child: HomeQuickAction(
                    icon: AppIcons.addLine,
                    label: 'Add room',
                    onTap: () => RoomsScreen.showAddRoomDialog(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: HomeQuickAction(
                    icon: AppIcons.personAdd,
                    label: 'Add tenant',
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: HomeQuickAction(
                    icon: AppIcons.megaphoneLine,
                    label: 'Post notice',
                    onTap: () => _openAnnouncements(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: HomeQuickAction(
                    icon: AppIcons.buildLine,
                    label: 'Concerns',
                    onTap: () => widget.onNavigateTab?.call(3),
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ScrollReveal(
            index: 5,
            child: HomeSegmented(
              labels: const ['Overview', 'Money', 'People'],
              index: _segment,
              onChanged: (i) => setState(() => _segment = i),
            ),
          ),
          const SizedBox(height: 18),
          ...revealAll(
            _segment == 0
                ? _overview(
                    context, s, occupancy, openBeds, unpaid, openConcerns)
                : _segment == 1
                    ? _money(context, s)
                    : _people(context, s),
            start: 6,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // OVERVIEW
  // ==========================================================

  List<Widget> _overview(
    BuildContext context,
    AppState s,
    double occupancy,
    int openBeds,
    int unpaid,
    int openConcerns,
  ) {
    final pct = (occupancy * 100).round();
    final rooms = s.rooms;
    final concerns = s.concerns
        .where((c) => c.status.toLowerCase() != ConcernModel.statusResolved)
        .take(3)
        .toList();
    final notices = s.announcements.take(2).toList();
    final paidCount = s.tenants
        .where((t) => (t.paymentStatus ?? 'paid').toLowerCase() == 'paid')
        .length;
    final partialCount = s.tenants
        .where((t) => (t.paymentStatus ?? '').toLowerCase() == 'partial')
        .length;
    final unpaidCount = (s.tenants.length - paidCount - partialCount)
        .clamp(0, s.tenants.length);
    final followUps = s.tenants
        .where((t) => (t.paymentStatus ?? 'paid').toLowerCase() != 'paid')
        .take(4)
        .toList();

    final timeline = <_TimelineEntry>[
      for (final c in s.concerns.take(6))
        _TimelineEntry(
          title: c.subject,
          at: c.createdAt ?? DateTime.now(),
          icon: AppIcons.buildLine,
          color: const Color(0xFFB45309),
        ),
      for (final a in s.announcements.take(6))
        _TimelineEntry(
          title: a.title,
          at: a.publishedAt ?? DateTime.now(),
          icon: AppIcons.megaphoneLine,
          color: HomeStyle.emerald,
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return [
      const HomeSectionHeader(eyebrow: 'The pulse', title: 'At a glance'),
      Row(
        children: [
          Expanded(
            child: HomeMetric(
              icon: AppIcons.dashboard,
              label: 'Occupancy',
              value: '$pct%',
              delta: pct >= 80 ? 'Healthy' : 'Room to grow',
              color: HomeStyle.emerald,
              onTap: () => widget.onNavigateTab?.call(1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HomeMetric(
              icon: AppIcons.seatLine,
              label: 'Open beds',
              value: '$openBeds',
              delta: openBeds == 0 ? 'Full house' : 'Ready',
              color: const Color(0xFF0F7A44),
              onTap: () => widget.onNavigateTab?.call(1),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: HomeMetric(
              icon: AppIcons.walletLine,
              label: 'Rent follow-up',
              value: '$unpaid',
              delta: unpaid == 0 ? 'All clear' : 'Unpaid',
              color: unpaid == 0 ? HomeStyle.emerald : const Color(0xFFB45309),
              onTap: () => setState(() => _segment = 1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HomeMetric(
              icon: AppIcons.chatLine,
              label: 'Open concerns',
              value: '$openConcerns',
              delta: openConcerns == 0 ? 'Quiet' : 'Attention',
              color: openConcerns == 0
                  ? HomeStyle.emerald
                  : const Color(0xFF0369A1),
              onTap: () => widget.onNavigateTab?.call(3),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _CollectionCard(
        paid: paidCount,
        partial: partialCount,
        unpaid: unpaidCount,
        onTap: () => setState(() => _segment = 1),
      ),
      const SizedBox(height: 18),
      _MoneyFollowUps(
        tenants: followUps,
        total: unpaidCount,
        onTap: () => setState(() => _segment = 1),
      ),
      const SizedBox(height: 22),
      const HomeSectionHeader(eyebrow: 'Activity', title: 'Latest updates'),
      _ActivityTimeline(entries: timeline.take(4).toList()),
      const SizedBox(height: 22),
      _PeoplePreview(
        tenants: s.tenants.take(4).toList(),
        total: s.tenants.length,
        onTap: () => widget.onNavigateTab?.call(2),
      ),
      const SizedBox(height: 22),
      HomeSectionHeader(
        eyebrow: 'Occupancy',
        title: 'Rooms',
        action: 'See all',
        onAction: () => widget.onNavigateTab?.call(1),
      ),
      if (rooms.isEmpty)
        _Panel(
          child: HomeEmpty(
            icon: AppIcons.roomLine,
            title: 'No rooms yet',
            message: 'Add the first room to start tracking occupancy.',
          ),
        )
      else
        SizedBox(
          height: 166,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: 4),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final room = rooms[i];
              return HomeRoomCard(
                room: room,
                onTap: () => pushLiquidPage(
                  context,
                  RoomDetailScreen(room: room),
                ),
              );
            },
          ),
        ),
      const SizedBox(height: 22),
      HomeSectionHeader(
        eyebrow: 'Needs attention',
        title: 'Concerns',
        action: 'View all',
        onAction: () => widget.onNavigateTab?.call(3),
      ),
      _Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: concerns.isEmpty
            ? HomeEmpty(
                icon: AppIcons.checkLine,
                title: 'No open concerns',
                message:
                    'Your tenants are all set. Anything new will land here.',
              )
            : Column(
                children: [
                  for (var i = 0; i < concerns.length; i++) ...[
                    HomeConcernRow(
                      concern: concerns[i],
                      onTap: () => ConcernsScreen.showEditConcernSheet(
                        context,
                        concerns[i],
                      ),
                    ),
                    if (i != concerns.length - 1)
                      Divider(height: 1, color: HomeStyle.hairline),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 22),
      HomeSectionHeader(
        eyebrow: 'Notice board',
        title: 'Latest notices',
        action: 'Open board',
        onAction: () => _openAnnouncements(context),
      ),
      if (notices.isEmpty)
        _Panel(
          child: HomeEmpty(
            icon: AppIcons.megaphoneLine,
            title: 'No notices yet',
            message: 'Post a notice so everyone in the house knows.',
          ),
        )
      else
        _Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < notices.length; i++) ...[
                InkWell(
                  onTap: () => _openAnnouncements(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 18,
                          color: HomeStyle.emerald,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notices[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: HomeStyle.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tShortDate(notices[i].publishedAt),
                                style: TextStyle(
                                  color: HomeStyle.inkFaint,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: HomeStyle.emerald,
                        ),
                      ],
                    ),
                  ),
                ),
                if (i != notices.length - 1)
                  Divider(height: 1, color: HomeStyle.hairline),
              ],
            ],
          ),
        ),
    ];
  }

  // ==========================================================
  // MONEY
  // ==========================================================

  List<Widget> _money(BuildContext context, AppState s) {
    final tenants = s.tenants;
    final paid = tenants
        .where((t) => (t.paymentStatus ?? 'paid').toLowerCase() == 'paid')
        .length;
    final partial = tenants
        .where((t) => (t.paymentStatus ?? '').toLowerCase() == 'partial')
        .length;
    final unpaid = (tenants.length - paid - partial).clamp(0, tenants.length);

    return [
      const HomeSectionHeader(eyebrow: 'Money', title: 'This month'),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeBars(
              values: [paid.toDouble(), partial.toDouble(), unpaid.toDouble()],
              labels: const ['Paid', 'Partial', 'Unpaid'],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Current tenant payment mix',
                style: TextStyle(
                  color: HomeStyle.inkFaint,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      HomeSectionHeader(
        eyebrow: 'Ledger',
        title: 'Tenant status',
        action: 'Open tenants',
        onAction: () => widget.onNavigateTab?.call(2),
      ),
      _Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: tenants.isEmpty
            ? const HomeEmpty(
                icon: AppIcons.groupLine,
                title: 'No tenants yet',
                message: 'Add a tenant or share the house key to get started.',
              )
            : Column(
                children: [
                  for (var i = 0; i < tenants.length; i++) ...[
                    HomePersonRow(
                      name: tenants[i].fullName,
                      meta: tenants[i].roomNumber == null
                          ? tenants[i].displayEmail
                          : 'Room ${tenants[i].roomNumber} · ${tenants[i].displayEmail}',
                      status: _paymentLabel(tenants[i].paymentStatus),
                      onTap: () => TenantCalendarSheet.show(
                        context,
                        tenants[i],
                        isOwner: true,
                      ),
                    ),
                    if (i != tenants.length - 1)
                      Divider(height: 1, color: HomeStyle.hairline),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 18),
      _Panel(
        child: Row(
          children: [
            const _MiniFact(
              icon: AppIcons.walletLine,
              value: '24',
              label: 'Months tracked',
            ),
            Container(width: 1, height: 34, color: HomeStyle.hairline),
            const _MiniFact(
              icon: AppIcons.checkCircleOutline,
              value: '100%',
              label: 'Records',
            ),
            Container(width: 1, height: 34, color: HomeStyle.hairline),
            _MiniFact(
              icon: AppIcons.partial,
              value: '${tenants.length}',
              label: 'Members',
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _people(BuildContext context, AppState s) {
    final tenants = s.tenants;
    final unassigned = s.unassigned;
    final query = _peopleQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? tenants
        : tenants
            .where(
              (t) =>
                  t.fullName.toLowerCase().contains(query) ||
                  (t.roomNumber ?? '').toLowerCase().contains(query) ||
                  t.displayEmail.toLowerCase().contains(query),
            )
            .toList();
    final grouped = <String, List<TenantModel>>{};
    for (final tenant in filtered) {
      final room = tenant.roomNumber ?? 'Unassigned';
      grouped.putIfAbsent(room, () => <TenantModel>[]).add(tenant);
    }
    final roomKeys = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    return [
      HomeSectionHeader(
        eyebrow: 'Household',
        title: 'People',
        action: 'Manage',
        onAction: () => widget.onNavigateTab?.call(2),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
          border: Border.all(
              color: (AppColors.dark
                  ? AppColors.border.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9))),
          boxShadow: HomeStyle.lift,
        ),
        child: TextField(
          controller: _peopleSearch,
          onChanged: (value) => setState(() => _peopleQuery = value),
          decoration: const InputDecoration(
            hintText: 'Search tenant, room or email',
            prefixIcon: Icon(Icons.search_rounded, size: 19),
            border: InputBorder.none,
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (tenants.isEmpty)
        _Panel(
          child: HomeEmpty(
            icon: AppIcons.groupLine,
            title: 'No tenants yet',
            message: 'Invite someone with the house key or add a record.',
          ),
        )
      else if (filtered.isEmpty)
        _Panel(
          child: HomeEmpty(
            icon: Icons.search_off_rounded,
            title: 'No matches',
            message: 'No tenant, room or email matches "$_peopleQuery".',
          ),
        )
      else
        for (final room in roomKeys) ...[
          _Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROOM ${room.toUpperCase()}',
                  style: TextStyle(
                    color: HomeStyle.emerald,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < grouped[room]!.length; i++) ...[
                  HomePersonRow(
                    name: grouped[room]![i].fullName,
                    meta: grouped[room]![i].roomNumber == null
                        ? grouped[room]![i].displayEmail
                        : 'Room ${grouped[room]![i].roomNumber} · ${grouped[room]![i].displayEmail}',
                    status: _paymentLabel(grouped[room]![i].paymentStatus),
                    onTap: () => TenantCalendarSheet.show(
                      context,
                      grouped[room]![i],
                      isOwner: true,
                    ),
                  ),
                  if (i != grouped[room]!.length - 1)
                    Divider(height: 1, color: HomeStyle.hairline),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      const SizedBox(height: 18),
      HomeSectionHeader(
        eyebrow: 'Access',
        title: 'Unassigned accounts',
        action: unassigned.isEmpty ? null : 'Review',
        onAction: () => widget.onNavigateTab?.call(2),
      ),
      _Panel(
        child: unassigned.isEmpty
            ? const HomeEmpty(
                icon: AppIcons.shieldLine,
                title: 'No loose accounts',
                message: 'Everyone who joined is already linked to a tenant.',
              )
            : Column(
                children: [
                  for (var i = 0; i < unassigned.length; i++) ...[
                    HomePersonRow(
                      name: unassigned[i].displayName,
                      meta: unassigned[i].email,
                      status: 'Unassigned',
                      statusTone: 'partial',
                      onTap: () => widget.onNavigateTab?.call(2),
                    ),
                    if (i != unassigned.length - 1)
                      Divider(height: 1, color: HomeStyle.hairline),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 18),
      _HomeKeySection(
        houseKey: s.selected?.joinKey ?? '',
        onCopy: () => _copyKey(context, s.selected?.joinKey ?? ''),
      ),
      const SizedBox(height: 22),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite someone new',
              style: TextStyle(
                color: HomeStyle.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Share the house key. They sign in with Google, join the house, then you attach them to a room.',
              style: TextStyle(
                color: HomeStyle.inkSoft,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TButton(
                    text: 'Copy house key',
                    icon: AppIcons.copy,
                    height: 46,
                    onPressed: () =>
                        _copyKey(context, s.selected?.joinKey ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TButton(
                    text: 'Open tenants',
                    variant: TButtonVariant.secondary,
                    height: 46,
                    onPressed: () => widget.onNavigateTab?.call(2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // ==========================================================
  // SHEETS
  // ==========================================================

  Future<void> _openSearch(BuildContext context) {
    return pushLiquidPage(context, const OwnerSearchScreen());
  }

  Future<void> _openNotifications(BuildContext context) async {
    final s = context.read<AppState>();
    final concerns = s.concerns
        .where((c) => c.status.toLowerCase() != ConcernModel.statusResolved)
        .take(4)
        .toList();
    final notices = s.announcements.take(2).toList();

    await showLiquidSheet<void>(context, (ctx) {
      return tSheetBody(
        ctx,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Inbox',
              style: TextStyle(
                color: HomeStyle.ink,
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Everything that needs your attention, in one place.',
              style: TextStyle(
                color: HomeStyle.inkSoft,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            if (concerns.isEmpty && notices.isEmpty)
              const HomeEmpty(
                icon: AppIcons.checkLine,
                title: 'All quiet',
                message: 'No open concerns and no fresh notices.',
              )
            else ...[
              for (final c in concerns)
                HomeConcernRow(
                  concern: c,
                  onTap: () {
                    Navigator.pop(ctx);
                    ConcernsScreen.showEditConcernSheet(context, c);
                  },
                ),
              for (final a in notices) ...[
                const SizedBox(height: 6),
                HomeNoticeCard(
                  announcement: a,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openAnnouncements(context);
                  },
                ),
              ],
            ],
          ],
        ),
      );
    });
  }

  Future<void> _openHouseSheet(BuildContext context) async {
    final s = context.read<AppState>();
    final h = s.selected;
    if (h == null) return;
    await showLiquidSheet<void>(context, (ctx) {
      return tSheetBody(
        ctx,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HomeStyle.mint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    AppIcons.homeLine,
                    size: 21,
                    color: HomeStyle.emerald,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.name,
                        style: TextStyle(
                          color: HomeStyle.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        h.domain.isEmpty ? h.role : '@${h.domain} · ${h.role}',
                        style: TextStyle(
                          color: HomeStyle.inkFaint,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            HomeKeyCard(
              houseKey: h.joinKey,
              onCopy: () => _copyKey(context, h.joinKey),
            ),
            const SizedBox(height: 14),
            TButton(
              text: 'Switch boarding house',
              icon: AppIcons.swapLine,
              variant: TButtonVariant.secondary,
              onPressed: () {
                Navigator.pop(ctx);
                s.clearSelectedHouse();
              },
            ),
          ],
        ),
      );
    });
  }

  // ==========================================================
  // ACTIONS
  // ==========================================================

  void _openAnnouncements(BuildContext context) {
    pushLiquidPage(context, const AnnouncementsScreen(isOwner: true));
  }

  void _copyKey(BuildContext context, String key) {
    if (key.isEmpty) return;
    Clipboard.setData(ClipboardData(text: key));
    HapticFeedback.selectionClick();
    showTSnack(context, 'House key copied', icon: AppIcons.keyLine);
  }

  String _paymentLabel(String? value) {
    final v = (value ?? 'paid').toLowerCase();
    if (v == 'paid') return 'Paid';
    if (v == 'partial') return 'Partial';
    return 'Unpaid';
  }
}

// ==========================================================
// HEADER
// ==========================================================

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String firstName;
  final String houseName;
  final String domain;
  final int unread;
  final VoidCallback? onAvatar;
  final VoidCallback? onSearch;
  final VoidCallback? onBell;
  final VoidCallback? onHouse;

  const _HomeHeader({
    required this.greeting,
    required this.firstName,
    required this.houseName,
    required this.domain,
    required this.unread,
    this.onAvatar,
    this.onSearch,
    this.onBell,
    this.onHouse,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PressableSurface(
          onTap: onAvatar,
          borderRadius: BorderRadius.circular(999),
          pressedScale: 0.94,
          highlightColor: Colors.black.withValues(alpha: 0.04),
          semanticsLabel: 'Open profile',
          child: Stack(
            children: [
              Container(
                width: 46,
                height: 46,
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
                  _initials(firstName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: HomeStyle.lime,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,'.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HomeStyle.emerald,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HomeStyle.ink,
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 3),
              PressableSurface(
                onTap: onHouse,
                borderRadius: BorderRadius.circular(999),
                pressedScale: 0.98,
                highlightColor: Colors.black.withValues(alpha: 0.03),
                semanticsLabel: 'Switch boarding house',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: HomeStyle.lime.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.homeLine,
                        size: 12,
                        color: HomeStyle.forest,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          domain.isEmpty ? houseName : '@$domain',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: HomeStyle.forest,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        AppIcons.expand,
                        size: 14,
                        color: HomeStyle.forest,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _HeaderAction(
          icon: AppIcons.search,
          onTap: onSearch,
          label: 'Search',
        ),
        const SizedBox(width: 4),
        _HeaderAction(
          icon: AppIcons.notifications,
          onTap: onBell,
          label: 'Inbox',
          badge: unread,
        ),
      ],
    );
  }

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'M';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final int badge;

  const _HeaderAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableSurface(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        pressedScale: 0.94,
        highlightColor: Colors.black.withValues(alpha: 0.04),
        semanticButton: false,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: HomeStyle.hairline),
            boxShadow: HomeStyle.lift,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 21, color: HomeStyle.ink),
              if (badge > 0)
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 14),
                    height: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB91C1C),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
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

// ==========================================================
// PANEL
// ==========================================================

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surface2],
        ),
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

class _MiniFact extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniFact({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 17, color: HomeStyle.emerald),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: HomeStyle.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HomeStyle.inkFaint,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeKeySection extends StatelessWidget {
  final String houseKey;
  final VoidCallback onCopy;

  const _HomeKeySection({required this.houseKey, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    if (houseKey.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeSectionHeader(
          eyebrow: 'Share access',
          title: 'House key',
        ),
        HomeKeyCard(houseKey: houseKey, onCopy: onCopy),
      ],
    );
  }
}

class _LoadingHome extends StatelessWidget {
  final AppState s;

  const _LoadingHome({required this.s});

  @override
  Widget build(BuildContext context) {
    final failed = s.error != null && !s.loading;
    return RefreshIndicator(
      color: kPrimary,
      backgroundColor: AppColors.surface,
      onRefresh: s.refreshHouse,
      child: ListView(
        primary: false,
        padding: EdgeInsets.fromLTRB(
          HomeStyle.gutter,
          MediaQuery.paddingOf(context).top + 16,
          HomeStyle.gutter,
          120,
        ),
        children: [
          Row(
            children: [
              const HomeSkeletonBlock(width: 46, height: 46, radius: 99),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    HomeSkeletonBlock(width: 90, height: 10),
                    SizedBox(height: 8),
                    HomeSkeletonBlock(width: 160, height: 22),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (failed)
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Could not load this house',
                    style: TextStyle(
                      color: HomeStyle.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.error ?? 'Please try again.',
                    style: TextStyle(
                      color: HomeStyle.inkSoft,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TButton(
                      text: 'Try again',
                      icon: AppIcons.refresh,
                      height: 46,
                      onPressed: s.refreshHouse,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            const HomeSkeletonBlock(height: 220, radius: 30),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(child: HomeSkeletonBlock(height: 64, radius: 18)),
                SizedBox(width: 10),
                Expanded(child: HomeSkeletonBlock(height: 64, radius: 18)),
                SizedBox(width: 10),
                Expanded(child: HomeSkeletonBlock(height: 64, radius: 18)),
                SizedBox(width: 10),
                Expanded(child: HomeSkeletonBlock(height: 64, radius: 18)),
              ],
            ),
            const SizedBox(height: 18),
            const HomeSkeletonBlock(width: 120, height: 18),
            const SizedBox(height: 10),
            const HomeSkeletonBlock(height: 96, radius: 22),
            const SizedBox(height: 10),
            const HomeSkeletonBlock(height: 96, radius: 22),
          ],
        ],
      ),
    );
  }
}

// ==========================================================
// NEEDS ATTENTION
// ==========================================================

class _AttentionStrip extends StatelessWidget {
  final int unpaid;
  final int openConcerns;
  final int openBeds;
  final VoidCallback onConcerns;
  final VoidCallback onTenants;
  final VoidCallback onRooms;

  const _AttentionStrip({
    required this.unpaid,
    required this.openConcerns,
    required this.openBeds,
    required this.onConcerns,
    required this.onTenants,
    required this.onRooms,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'NEEDS ATTENTION',
              style: TextStyle(
                color: HomeStyle.emerald,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: HomeStyle.mint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'LIVE',
                style: TextStyle(
                  color: HomeStyle.emerald,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _AttentionTile(
                icon: Icons.payments_outlined,
                value: '$unpaid',
                label: unpaid == 1 ? 'Unpaid tenant' : 'Unpaid tenants',
                tone: const Color(0xFFB45309),
                onTap: onTenants,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AttentionTile(
                icon: AppIcons.chatLine,
                value: '$openConcerns',
                label: openConcerns == 1 ? 'Open concern' : 'Open concerns',
                tone: const Color(0xFFB91C1C),
                onTap: onConcerns,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AttentionTile(
                icon: AppIcons.roomLine,
                value: '$openBeds',
                label: openBeds == 1 ? 'Open bed' : 'Open beds',
                tone: HomeStyle.emerald,
                onTap: onRooms,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color tone;
  final VoidCallback onTap;

  const _AttentionTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      pressedScale: 0.98,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: '$label: $value',
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface, AppColors.surface2],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: (AppColors.dark
                  ? AppColors.border.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9))),
          boxShadow: HomeStyle.lift,
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: TAmbient(
                art: 'idle',
                opacity: 0.35,
                size: 260,
                alignment: Alignment.topRight,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, size: 17, color: tone),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tone,
                        fontFamily: AppType.displayFamily,
                        fontSize: 21,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HomeStyle.inkFaint,
                        fontSize: 9,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// COLLECTION SNAPSHOT
// ==========================================================

class _CollectionCard extends StatelessWidget {
  final int paid;
  final int partial;
  final int unpaid;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.paid,
    required this.partial,
    required this.unpaid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = paid + partial + unpaid;
    final paidRatio = total == 0 ? 0.0 : paid / total;
    final partialRatio = total == 0 ? 0.0 : partial / total;
    final unpaidRatio = total == 0 ? 0.0 : unpaid / total;

    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
      pressedScale: 0.99,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel:
          'Rent collection: $paid paid, $partial partial, $unpaid unpaid',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface, AppColors.surface2],
          ),
          borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
          border: Border.all(
              color: (AppColors.dark
                  ? AppColors.border.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9))),
          boxShadow: HomeStyle.lift,
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: TAmbient(
                art: 'idle',
                opacity: 0.3,
                size: 320,
                alignment: Alignment.topRight,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'RENT COLLECTION',
                        style: TextStyle(
                          color: HomeStyle.emerald,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        total == 0
                            ? 'No tenants yet'
                            : '${(paidRatio * 100).round()}% settled',
                        style: TextStyle(
                          color: HomeStyle.inkFaint,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          if (paidRatio > 0)
                            Expanded(
                              flex: (paidRatio * 1000).round().clamp(1, 1000),
                              child: ColoredBox(
                                color: HomeStyle.emerald,
                              ),
                            ),
                          if (partialRatio > 0)
                            Expanded(
                              flex:
                                  (partialRatio * 1000).round().clamp(1, 1000),
                              child: const ColoredBox(
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          if (unpaidRatio > 0)
                            Expanded(
                              flex: (unpaidRatio * 1000).round().clamp(1, 1000),
                              child: const ColoredBox(
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          if (total == 0)
                            Expanded(
                              child: ColoredBox(color: HomeStyle.mint),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _LegendDot(
                        color: HomeStyle.emerald,
                        label: '$paid paid',
                        value: '$paid',
                      ),
                      const SizedBox(width: 14),
                      _LegendDot(
                        color: const Color(0xFFF59E0B),
                        label: '$partial partial',
                        value: '$partial',
                      ),
                      const SizedBox(width: 14),
                      _LegendDot(
                        color: const Color(0xFFDC2626),
                        label: '$unpaid unpaid',
                        value: '$unpaid',
                      ),
                    ],
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: HomeStyle.inkFaint,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// ACTIVITY TIMELINE
// ==========================================================

class _TimelineEntry {
  final String title;
  final DateTime at;
  final IconData icon;
  final Color color;

  const _TimelineEntry({
    required this.title,
    required this.at,
    required this.icon,
    required this.color,
  });
}

class _ActivityTimeline extends StatelessWidget {
  final List<_TimelineEntry> entries;

  const _ActivityTimeline({required this.entries});

  String _when(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _Panel(
        child: HomeEmpty(
          icon: Icons.timeline_rounded,
          title: 'Nothing has happened yet',
          message: 'Notices, concerns and updates will appear here.',
        ),
      );
    }

    return _Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == entries.length - 1 ? 0 : 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: entries[i].color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          entries[i].icon,
                          size: 15,
                          color: entries[i].color,
                        ),
                      ),
                      if (i != entries.length - 1)
                        Container(
                          width: 2,
                          height: 20,
                          margin: const EdgeInsets.only(top: 4),
                          color: HomeStyle.hairline,
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: HomeStyle.ink,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _when(entries[i].at),
                          style: TextStyle(
                            color: HomeStyle.inkFaint,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 420.ms, curve: Curves.easeOutCubic).slideY(
        begin: 0.04, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);
  }
}

// ==========================================================
// PEOPLE PREVIEW
// ==========================================================

class _PeoplePreview extends StatelessWidget {
  final List<TenantModel> tenants;
  final int total;
  final VoidCallback onTap;

  const _PeoplePreview({
    required this.tenants,
    required this.total,
    required this.onTap,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'T';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color _paymentColor(String? status) {
    switch ((status ?? 'paid').toLowerCase()) {
      case 'paid':
        return HomeStyle.emerald;
      case 'partial':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
      pressedScale: 0.99,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel: 'View $total tenants',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface, AppColors.surface2],
          ),
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
              children: [
                Text(
                  'PEOPLE',
                  style: TextStyle(
                    color: HomeStyle.emerald,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const Spacer(),
                Text(
                  '$total ${total == 1 ? 'tenant' : 'tenants'}',
                  style: TextStyle(
                    color: HomeStyle.inkFaint,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: HomeStyle.emerald,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (tenants.isEmpty)
              Row(
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 18,
                    color: HomeStyle.inkFaint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No tenants yet. Share the house key to invite one.',
                      style: TextStyle(
                        color: HomeStyle.inkFaint.withValues(alpha: 0.95),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              )
            else
              for (var i = 0; i < tenants.length; i++) ...[
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == tenants.length - 1 ? 0 : 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
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
                          _initials(tenants[i].fullName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenants[i].fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: HomeStyle.ink,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Room ${tenants[i].roomNumber ?? '—'}',
                              style: TextStyle(
                                color: HomeStyle.inkFaint,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _paymentColor(tenants[i].paymentStatus),
                          shape: BoxShape.circle,
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
}

// ==========================================================
// MONEY FOLLOW-UPS
// ==========================================================

class _MoneyFollowUps extends StatelessWidget {
  final List<TenantModel> tenants;
  final int total;
  final VoidCallback onTap;

  const _MoneyFollowUps({
    required this.tenants,
    required this.total,
    required this.onTap,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'T';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color _tone(String? status) => (status ?? '').toLowerCase() == 'partial'
      ? const Color(0xFFB45309)
      : const Color(0xFFB91C1C);

  String _label(String? status) =>
      (status ?? '').toLowerCase() == 'partial' ? 'Partial' : 'Unpaid';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surface2],
        ),
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
            children: [
              Text(
                'RENT FOLLOW-UPS',
                style: TextStyle(
                  color: HomeStyle.emerald,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                total == 0
                    ? 'All settled'
                    : '$total ${total == 1 ? 'tenant' : 'tenants'}',
                style: TextStyle(
                  color: HomeStyle.inkFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onTap,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: HomeStyle.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tenants.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: HomeStyle.emerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Every tenant is paid up for this month.',
                    style: TextStyle(
                      color: HomeStyle.inkFaint.withValues(alpha: 0.95),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            )
          else
            for (var i = 0; i < tenants.length; i++) ...[
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _tone(tenants[i].paymentStatus)
                                  .withValues(alpha: 0.85),
                              _tone(tenants[i].paymentStatus),
                            ],
                          ),
                        ),
                        child: Text(
                          _initials(tenants[i].fullName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenants[i].fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: HomeStyle.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Room ${tenants[i].roomNumber ?? '—'}',
                              style: TextStyle(
                                color: HomeStyle.inkFaint,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _tone(tenants[i].paymentStatus)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _label(tenants[i].paymentStatus),
                          style: TextStyle(
                            color: _tone(tenants[i].paymentStatus),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i != tenants.length - 1)
                Divider(height: 8, color: HomeStyle.hairline),
            ],
        ],
      ),
    );
  }
}
