import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../models/models.dart';
import '../../routing/liquid_page_route.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/heavy_motion.dart';
import '../../widgets/lottie_art.dart';
import '../../widgets/scroll_reveal.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/ui.dart';
import 'announcements.dart';
import 'home/home_kit.dart';
import 'room_detail.dart';
import '../../core/app_colors.dart';

/// A dedicated search page. Replaces the old bottom sheet, which tripped a
/// Flutter inherited-element teardown assertion when dismissed with the
/// keyboard open.
class OwnerSearchScreen extends StatefulWidget {
  const OwnerSearchScreen({super.key});

  @override
  State<OwnerSearchScreen> createState() => _OwnerSearchScreenState();
}

class _OwnerSearchScreenState extends State<OwnerSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  int _scope = 0;

  static const _scopes = ['Everything', 'Rooms', 'People', 'Notices'];

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = _query.trim().toLowerCase();
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: TahananBackground(
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: insets),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                  child: Row(
                    children: [
                      const TBackButton(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SEARCH',
                                style: tEyebrow().copyWith(fontSize: 9)),
                            Text(
                              'Find anything',
                              style: tScreenTitle().copyWith(fontSize: 23),
                            ),
                          ],
                        ),
                      ),
                      const LottieArt('drift', size: 44),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kHairline),
                      boxShadow: kCardShadow,
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => setState(
                        () => _query = value.trim().toLowerCase(),
                      ),
                      style: AppType.bodyStrong.copyWith(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Room, tenant, or notice',
                        prefixIcon: const Icon(AppIcons.search, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                  _focus.requestFocus();
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                ),
                              ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _scopes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => TPill(
                      text: _scopes[i],
                      tone: _scope == i ? TPillTone.dark : TPillTone.neutral,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      onTap: () => setState(() => _scope = i),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _results(context, s, q),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results(BuildContext context, AppState s, String q) {
    if (q.isEmpty && _scope == 0) {
      return _SearchLanding(
        key: const ValueKey('landing'),
        onPick: (value) {
          _controller.text = value;
          setState(() => _query = value.toLowerCase());
        },
      );
    }

    final rooms = (_scope == 0 || _scope == 1)
        ? s.rooms
            .where((r) => q.isEmpty || r.roomNumber.toLowerCase().contains(q))
            .toList()
        : <RoomModel>[];
    final tenants = (_scope == 0 || _scope == 2)
        ? s.tenants
            .where(
              (t) =>
                  q.isEmpty ||
                  t.fullName.toLowerCase().contains(q) ||
                  t.displayEmail.toLowerCase().contains(q) ||
                  (t.roomNumber ?? '').toLowerCase().contains(q),
            )
            .toList()
        : <TenantModel>[];
    final notices = (_scope == 0 || _scope == 3)
        ? s.announcements
            .where(
              (a) =>
                  q.isEmpty ||
                  a.title.toLowerCase().contains(q) ||
                  a.message.toLowerCase().contains(q),
            )
            .toList()
        : <AnnouncementModel>[];

    final total = rooms.length + tenants.length + notices.length;
    if (total == 0) {
      return const _NoResults(key: ValueKey('none'));
    }

    final rows = <Widget>[];
    var index = 0;

    Widget row(Widget child) {
      final widget = ScrollReveal(
        index: index,
        child: child,
      );
      index += 1;
      return widget;
    }

    if (rooms.isNotEmpty) {
      rows.add(row(_SearchLabel('ROOMS', count: rooms.length)));
      for (var i = 0; i < rooms.length; i++) {
        final r = rooms[i];
        rows.add(
          row(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ResultCard(
                icon: AppIcons.roomLine,
                title: 'Room ${r.roomNumber}',
                meta: '${r.occupied}/${r.capacity} beds · ${r.available} open',
                ambient: i.isEven ? 'flow' : null,
                onTap: () => pushLiquidPage(context, RoomDetailScreen(room: r)),
              ),
            ),
          ),
        );
      }
    }
    if (tenants.isNotEmpty) {
      rows.add(row(_SearchLabel('PEOPLE', count: tenants.length)));
      for (var i = 0; i < tenants.length; i++) {
        final t = tenants[i];
        rows.add(
          row(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ResultCard(
                icon: AppIcons.personLine,
                title: t.fullName,
                meta: t.roomNumber == null
                    ? 'Unassigned · ${t.displayEmail}'
                    : 'Room ${t.roomNumber} · ${t.displayEmail}',
                ambient: i.isEven ? 'halo' : null,
                onTap: () => TenantCalendarSheet.show(
                  context,
                  t,
                  isOwner: true,
                ),
              ),
            ),
          ),
        );
      }
    }
    if (notices.isNotEmpty) {
      rows.add(row(_SearchLabel('NOTICES', count: notices.length)));
      for (var i = 0; i < notices.length; i++) {
        final a = notices[i];
        rows.add(
          row(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ResultCard(
                icon: AppIcons.megaphoneLine,
                title: a.title,
                meta: a.publishedAt == null
                    ? 'Recently posted'
                    : tShortDate(a.publishedAt),
                ambient: i.isEven ? 'drift' : null,
                onTap: () => showLiquidSheet<void>(
                  context,
                  (ctx) => tSheetBody(
                    ctx,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tShortDate(a.publishedAt).toUpperCase(),
                          textAlign: TextAlign.center,
                          style: tEyebrow(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.title,
                          textAlign: TextAlign.center,
                          style: tSectionTitle().copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 10),
                        Text(a.message, style: tBody()),
                        const SizedBox(height: 16),
                        TButton(
                          text: 'Open notice board',
                          icon: AppIcons.forward,
                          onPressed: () {
                            Navigator.pop(ctx);
                            pushLiquidPage(
                              context,
                              const AnnouncementsScreen(isOwner: true),
                            );
                          },
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
    }

    return ListView(
      key: const ValueKey('results'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        Row(
          children: [
            Text(
              '$total ${total == 1 ? 'result' : 'results'}',
              style: tEyebrow().copyWith(fontSize: 9),
            ),
            const Spacer(),
            if (q.isNotEmpty)
              Text(
                'for "$_query"',
                style: tMeta().copyWith(fontSize: 10.5),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

// ==========================================================
// LANDING
// ==========================================================

class _SearchLanding extends StatelessWidget {
  final void Function(String) onPick;

  const _SearchLanding({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      (label: 'Room 101', icon: AppIcons.roomLine),
      (label: 'Unassigned', icon: AppIcons.personLine),
      (label: 'Rent', icon: AppIcons.walletLine),
      (label: 'Water', icon: AppIcons.megaphoneLine),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Drift(
              amplitude: 4,
              child: HomeEmpty(
                icon: AppIcons.search,
                title: 'Search everything',
                message:
                    'Rooms, people and notices live in one index. Start typing or pick a shortcut.',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in suggestions)
                  TPill(
                    text: s.label,
                    tone: TPillTone.neutral,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    onTap: () => onPick(s.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: HomeEmpty(
          icon: AppIcons.search,
          title: 'Nothing found',
          message:
              'Try a shorter word, a room number, or switch the scope above.',
        ),
      ),
    );
  }
}

// ==========================================================
// RESULT PIECES
// ==========================================================

class _SearchLabel extends StatelessWidget {
  final String text;
  final int count;

  const _SearchLabel(this.text, {required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 10),
      child: Row(
        children: [
          Text(
            text,
            style: tEyebrow().copyWith(fontSize: 9),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: tMeta(color: kInkMuted).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String meta;
  final String? ambient;
  final VoidCallback onTap;

  const _ResultCard({
    required this.icon,
    required this.title,
    required this.meta,
    required this.ambient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TCard(
      padding: const EdgeInsets.all(12),
      ambient: ambient,
      ambientOpacity: 0.12,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kMint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 19, color: kPrimary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tLabel(),
                ),
                const SizedBox(height: 1),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tMeta().copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          Icon(
            AppIcons.chevron,
            size: 18,
            color: kInkMuted,
          ),
        ],
      ),
    );
  }
}
