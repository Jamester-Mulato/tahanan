import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

/// The rooms tab, expressed in the same visual language as the reference
/// home: dark occupancy summary, hairline cards, outlined icons, instant
/// press feedback and a calm two-column room grid.
class RoomsBody extends StatefulWidget {
  final VoidCallback onAddRoom;
  final void Function(RoomModel room) onOpenRoom;
  final void Function(RoomModel room) onManageRoom;

  const RoomsBody({
    super.key,
    required this.onAddRoom,
    required this.onOpenRoom,
    required this.onManageRoom,
  });

  @override
  State<RoomsBody> createState() => _RoomsBodyState();
}

class _RoomsBodyState extends State<RoomsBody> {
  int _filter = 0; // 0 all, 1 open, 2 full
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
    final rooms = s.rooms;
    final totalBeds = rooms.fold<int>(0, (sum, r) => sum + r.capacity);
    final occupied = rooms.fold<int>(0, (sum, r) => sum + r.occupied);
    final open = (totalBeds - occupied).clamp(0, totalBeds);
    final occupancy = totalBeds == 0 ? 0.0 : occupied / totalBeds;

    final filtered = rooms.where((r) {
      final matchesQuery =
          _query.isEmpty || r.roomNumber.toLowerCase().contains(_query);
      final matchesFilter = switch (_filter) {
        1 => !r.isFull,
        2 => r.isFull,
        _ => true,
      };
      return matchesQuery && matchesFilter;
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
          children: [
            ScrollReveal(
              index: 0,
              child: RoomsHeader(
                rooms: rooms.length,
                beds: totalBeds,
                onAdd: widget.onAddRoom,
              ),
            ),
            const SizedBox(height: 14),
            ScrollReveal(
              index: 1,
              child: RoomsSummary(
                rooms: rooms.length,
                totalBeds: totalBeds,
                occupied: occupied,
                open: open,
                occupancy: occupancy,
              ),
            ),
            const SizedBox(height: 16),
            ScrollReveal(
              index: 2,
              child: TextField(
                controller: _search,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Find a room by number',
                  prefixIcon: Icon(AppIcons.search, size: 19),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ScrollReveal(
              index: 3,
              child: HomeSegmented(
                labels: const ['All', 'Open', 'Full'],
                index: _filter,
                onChanged: (i) => setState(() => _filter = i),
              ),
            ),
            const SizedBox(height: 18),
            ScrollReveal(
              index: 4,
              child: HomeSectionHeader(
                eyebrow: 'Inventory',
                title: '${filtered.length} '
                    '${filtered.length == 1 ? 'room' : 'rooms'}',
                trailing: HomeTag(
                  text: _filter == 0
                      ? 'Everything'
                      : _filter == 1
                          ? 'With space'
                          : 'Full houses',
                  color: HomeStyle.emerald,
                  background: const Color(0xFFE9F8EF),
                  dot: false,
                ),
              ),
            ),
            if (filtered.isEmpty)
              _RoomsEmpty(onAdd: widget.onAddRoom)
            else
              RoomGrid(
                rooms: filtered,
                onTap: widget.onOpenRoom,
                onLongPress: widget.onManageRoom,
              ),
            const SizedBox(height: 18),
            const _RoomsFootnote(),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// HEADER
// ==========================================================

class RoomsHeader extends StatelessWidget {
  final int rooms;
  final int beds;
  final VoidCallback onAdd;

  const RoomsHeader({
    super.key,
    required this.rooms,
    required this.beds,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ROOMS & BEDS',
          textAlign: TextAlign.center,
          style: tEyebrow(color: HomeStyle.inkFaint).copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 5),
        Text(
          'Your rooms',
          textAlign: TextAlign.center,
          style: AppType.h1.copyWith(
            fontSize: 26,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$rooms ${rooms == 1 ? 'room' : 'rooms'} · '
          '$beds ${beds == 1 ? 'bed' : 'beds'} in the house',
          textAlign: TextAlign.center,
          style: tMeta(color: HomeStyle.inkSoft).copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 12),
        TButton(
          text: 'Add room',
          icon: AppIcons.addLine,
          height: 46,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

// ==========================================================
// SUMMARY
// ==========================================================

class RoomsSummary extends StatelessWidget {
  final int rooms;
  final int totalBeds;
  final int occupied;
  final int open;
  final double occupancy;

  const RoomsSummary({
    super.key,
    required this.rooms,
    required this.totalBeds,
    required this.occupied,
    required this.open,
    required this.occupancy,
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
              child: IgnorePointer(child: CustomPaint(painter: _RoomsAura())),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIVE OCCUPANCY',
                          style: TextStyle(
                            color: HomeStyle.lime,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$occupied of $totalBeds beds filled',
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
                          '$open ${open == 1 ? 'bed' : 'beds'} ready across '
                          '$rooms ${rooms == 1 ? 'room' : 'rooms'}.',
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
                            _SummaryStat(value: '$rooms', label: 'Rooms'),
                            _SummaryDivider(),
                            _SummaryStat(value: '$totalBeds', label: 'Beds'),
                            _SummaryDivider(),
                            _SummaryStat(value: '$open', label: 'Open'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  HomeRing(
                    value: occupancy,
                    size: 86,
                    stroke: 8,
                    track: Colors.white.withValues(alpha: 0.14),
                    colors: [HomeStyle.lime, Color(0xFF7DE2A2)],
                    center: HomeCount(
                      value: (occupancy * 100).round(),
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

class _SummaryStat extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _SummaryDivider extends StatelessWidget {
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

class _RoomsAura extends CustomPainter {
  const _RoomsAura();

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
  bool shouldRepaint(covariant _RoomsAura old) => false;
}

// ==========================================================
// GRID
// ==========================================================

class RoomGrid extends StatelessWidget {
  final List<RoomModel> rooms;
  final void Function(RoomModel room) onTap;
  final void Function(RoomModel room) onLongPress;

  const RoomGrid({
    super.key,
    required this.rooms,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop web gets more columns; the Android layout stays at two.
        final columns = !kIsWeb
            ? 2
            : constraints.maxWidth >= 1080
                ? 4
                : constraints.maxWidth >= 760
                    ? 3
                    : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < rooms.length; i++)
              SizedBox(
                width: width,
                child: ScrollReveal(
                  index: 5 + i,
                  child: RoomGridCard(
                    room: rooms[i],
                    onTap: () => onTap(rooms[i]),
                    onLongPress: () => onLongPress(rooms[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class RoomGridCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const RoomGridCard({
    super.key,
    required this.room,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = room.capacity <= 0 ? 0.0 : room.occupied / room.capacity;
    final pct = (fraction * 100).round();
    final full = room.isFull;

    return PressableSurface(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
      pressedScale: 0.985,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      semanticsLabel:
          'Room ${room.roomNumber}, ${room.occupied} of ${room.capacity} beds',
      child: Container(
        padding: const EdgeInsets.all(14),
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
            Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: full
                      ? [HomeStyle.emerald, HomeStyle.lime]
                      : [HomeStyle.forest, HomeStyle.emerald],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Room ${room.roomNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeStyle.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                HomeTag(
                  text: full ? 'Full' : '${room.available} open',
                  color: full ? HomeStyle.forest : HomeStyle.emerald,
                  background: full ? HomeStyle.lime : const Color(0xFFE9F8EF),
                  dot: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                HomeRing(
                  value: fraction,
                  size: 52,
                  stroke: 6,
                  center: Text(
                    '$pct%',
                    style: TextStyle(
                      color: full ? HomeStyle.forest : HomeStyle.emerald,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${room.occupied}/${room.capacity}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HomeStyle.ink,
                          fontSize: 17,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'beds',
                        style: TextStyle(
                          color: HomeStyle.inkFaint,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TBedDots(
                        capacity: room.capacity,
                        occupied: room.occupied,
                        size: 7,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              full
                  ? 'Full house'
                  : '${room.available} ${room.available == 1 ? 'bed' : 'beds'} available',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: HomeStyle.inkFaint,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// EMPTY / FOOTNOTE
// ==========================================================

class _RoomsEmpty extends StatelessWidget {
  final VoidCallback onAdd;

  const _RoomsEmpty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(HomeStyle.cardRadius),
        border: Border.all(color: HomeStyle.hairline),
      ),
      child: Column(
        children: [
          const HomeEmpty(
            icon: AppIcons.roomLine,
            title: 'No rooms in this view',
            message: 'Add a room or clear the filter to see the whole house.',
          ),
          const SizedBox(height: 12),
          TButton(
            text: 'Add room',
            icon: AppIcons.addLine,
            height: 46,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _RoomsFootnote extends StatelessWidget {
  const _RoomsFootnote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(AppIcons.tap, size: 13, color: HomeStyle.inkFaint),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Long-press a room to change capacity, rename, or archive.',
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
