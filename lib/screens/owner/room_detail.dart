import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/design_tokens.dart';
import '../../models/models.dart';
import '../../routing/liquid_page_route.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/scroll_reveal.dart';
import '../../widgets/ui.dart';
import 'rooms.dart';

class RoomDetailScreen extends StatelessWidget {
  final RoomModel room;

  const RoomDetailScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final currentRoom = s.rooms.firstWhere(
      (r) => r.id == room.id,
      orElse: () => room,
    );
    final tenants = s.tenants
        .where(
          (t) =>
              t.roomId == currentRoom.id ||
              t.roomNumber == currentRoom.roomNumber,
        )
        .toList();

    return Scaffold(
      body: TahananBackground(
        child: RefreshIndicator(
          color: kPrimary,
          backgroundColor: AppColors.surface,
          onRefresh: s.refreshHouse,
          child: ListView(
            padding: tScreenPadding(context),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            children: [
              const TBackRow(),
              ScrollReveal(index: 0, child: _RoomHero(room: currentRoom)),
              const SizedBox(height: 14),
              ScrollReveal(index: 1, child: _BedMap(room: currentRoom)),
              const SizedBox(height: 14),
              ScrollReveal(
                index: 2,
                child: Row(
                  children: [
                    Expanded(
                      child:
                          Text('Tenants in this room', style: tSectionTitle()),
                    ),
                    TPill(
                      text: '${tenants.length} assigned',
                      tone: TPillTone.neutral,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (tenants.isEmpty)
                ScrollReveal(
                  index: 3,
                  child: TCard(
                    ambient: 'aurora',
                    ambientOpacity: 0.14,
                    child: const TEmpty(
                      icon: AppIcons.groupLine,
                      title: 'No tenants in this room',
                      message:
                          'Associate an account from the People tab to place someone here.',
                    ),
                  ),
                )
              else
                for (var i = 0; i < tenants.length; i++) ...[
                  ScrollReveal(
                    index: 3 + i,
                    child: _TenantTile(
                      tenant: tenants[i],
                      bed: 'Bed ${String.fromCharCode(65 + i)}',
                      index: i,
                      onTap: () => TenantCalendarSheet.show(
                        context,
                        tenants[i],
                        isOwner: true,
                      ),
                      onLongPress: () =>
                          _showTenantActions(context, s, tenants[i]),
                    ),
                  ),
                  if (i != tenants.length - 1) const SizedBox(height: 9),
                ],
              const SizedBox(height: 14),
              ScrollReveal(index: 6, child: _RentMix(tenants: tenants)),
              const SizedBox(height: 14),
              ScrollReveal(
                index: 7,
                child: TCard(
                  ambient: 'flow',
                  ambientOpacity: 0.12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Room facts', style: tSectionTitle()),
                      const SizedBox(height: 8),
                      TFactRow(
                        label: 'Room number',
                        value: currentRoom.roomNumber,
                      ),
                      TFactRow(
                        label: 'Capacity',
                        value: '${currentRoom.capacity} beds',
                      ),
                      TFactRow(
                        label: 'Occupied',
                        value: '${currentRoom.occupied} beds',
                      ),
                      TFactRow(
                        label: 'Open slots',
                        value: '${currentRoom.available}',
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: TButton(
                          text: 'Manage room',
                          variant: TButtonVariant.secondary,
                          height: 48,
                          icon: AppIcons.tune,
                          onPressed: () => RoomsScreen.showRoomManagementSheet(
                            context,
                            currentRoom,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTenantActions(BuildContext context, AppState s, TenantModel t) {
    showLiquidSheet<void>(
      context,
      (sheetCtx) => tSheetBody(
        sheetCtx,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TAvatar(name: t.fullName, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.fullName,
                          style: tSectionTitle().copyWith(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(
                        'Room ${t.roomNumber ?? '—'} · ${t.displayEmail}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tMeta(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TSettingRow(
              icon: AppIcons.calendarLine,
              label: 'Calendar & status',
              first: true,
              onTap: () {
                Navigator.pop(sheetCtx);
                TenantCalendarSheet.show(context, t, isOwner: true);
              },
            ),
            TSettingRow(
              icon: AppIcons.checkLine,
              label: 'Mark as paid',
              onTap: () {
                Navigator.pop(sheetCtx);
                _updateStatus(context, s, t, 'paid');
              },
            ),
            TSettingRow(
              icon: AppIcons.partial,
              label: 'Mark as partial',
              onTap: () {
                Navigator.pop(sheetCtx);
                _updateStatus(context, s, t, 'partial');
              },
            ),
            TSettingRow(
              icon: AppIcons.cancel,
              label: 'Mark as unpaid',
              onTap: () {
                Navigator.pop(sheetCtx);
                _updateStatus(context, s, t, 'unpaid');
              },
            ),
            TSettingRow(
              icon: AppIcons.personRemove,
              label: 'Remove from boarding house',
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmRemoveTenant(context, s, t);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    AppState s,
    TenantModel t,
    String action,
  ) async {
    try {
      await s.updateTenantStatus(t.id, action);
      if (context.mounted) {
        showTSnack(context, '${t.fullName} marked ${action.toUpperCase()}');
      }
    } catch (e) {
      if (context.mounted) {
        showTSnack(
          context,
          'Failed: $e',
          error: true,
          icon: AppIcons.alert,
        );
      }
    }
  }

  Future<void> _confirmRemoveTenant(
    BuildContext context,
    AppState s,
    TenantModel t,
  ) async {
    final ok = await tConfirm(
      context,
      title: 'Remove ${t.fullName}?',
      message:
          'This removes ${t.fullName} from this boarding house and clears their room assignment.',
      confirm: 'Remove tenant',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await s.removeTenant(t.id);
      if (context.mounted) showTSnack(context, 'Removed ${t.fullName}');
    } catch (e) {
      if (context.mounted) {
        showTSnack(
          context,
          'Failed to remove: $e',
          error: true,
          icon: AppIcons.alert,
        );
      }
    }
  }
}

// ==========================================================
// HERO
// ==========================================================

class _RoomHero extends StatelessWidget {
  final RoomModel room;

  const _RoomHero({required this.room});

  @override
  Widget build(BuildContext context) {
    final pct = room.capacity <= 0
        ? 0.0
        : (room.occupied / room.capacity).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        gradient: kHeroGradient,
        borderRadius: BorderRadius.circular(kHeroRadius),
        boxShadow: AppShadows.glow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: TAmbient(
              art: 'aurora',
              opacity: 0.55,
              size: 430,
              alignment: Alignment.topRight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              children: [
                Text(
                  'ROOM DETAIL',
                  textAlign: TextAlign.center,
                  style: tEyebrow(color: kLime).copyWith(fontSize: 9),
                ),
                const SizedBox(height: 4),
                Text(
                  'Room ${room.roomNumber}',
                  textAlign: TextAlign.center,
                  style: AppType.h1.copyWith(
                    color: Colors.white,
                    fontSize: 34,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${room.occupied} of ${room.capacity} beds filled',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(
                    color: kHeroMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: TRing(
                          value: pct,
                          label: '${(pct * 100).round()}%',
                          size: 62,
                          stroke: 6,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pct >= 1
                                  ? 'Fully occupied'
                                  : pct >= 0.5
                                      ? 'Mostly occupied'
                                      : 'Room to fill',
                              style: AppType.h3.copyWith(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${room.available} open ${room.available == 1 ? 'slot' : 'slots'} · capacity ${room.capacity}',
                              style: tMeta(color: kHeroMuted).copyWith(
                                fontSize: 10.5,
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
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// BED MAP
// ==========================================================

class _BedMap extends StatelessWidget {
  final RoomModel room;

  const _BedMap({required this.room});

  @override
  Widget build(BuildContext context) {
    return TCard(
      ambient: 'halo',
      ambientOpacity: 0.12,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Bed layout', style: tSectionTitle())),
              Text(
                '${room.occupied} OF ${room.capacity}',
                style: tEyebrow().copyWith(fontSize: 8.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < room.capacity; i++)
                _BedTile(
                  label: String.fromCharCode(65 + i),
                  occupied: i < room.occupied,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                color: kPrimary,
                label: '${room.occupied} occupied',
              ),
              const SizedBox(width: 14),
              _LegendDot(
                color: kMintDeep,
                label: '${room.available} open',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BedTile extends StatelessWidget {
  final String label;
  final bool occupied;

  const _BedTile({required this.label, required this.occupied});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: occupied ? kForest : kSurfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: occupied ? kForest : kHairline,
        ),
      ),
      child: Column(
        children: [
          Icon(
            occupied ? AppIcons.personLine : AppIcons.seatLine,
            size: 18,
            color: occupied ? kLime : kPrimary,
          ),
          const SizedBox(height: 4),
          Text(
            'Bed $label',
            style: AppType.caption.copyWith(
              color: occupied ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
          Text(
            occupied ? 'Filled' : 'Open',
            style: AppType.caption.copyWith(
              color: occupied ? kHeroMuted : kInkMuted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: tMeta().copyWith(fontSize: 10.5)),
      ],
    );
  }
}

// ==========================================================
// TENANT TILE
// ==========================================================

class _TenantTile extends StatelessWidget {
  final TenantModel tenant;
  final String bed;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TenantTile({
    required this.tenant,
    required this.bed,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final status = (tenant.paymentStatus ?? 'paid').toLowerCase();
    final tone = status == 'partial'
        ? TPillTone.pending
        : status == 'unpaid'
            ? TPillTone.bad
            : TPillTone.ok;
    return TCard(
      padding: const EdgeInsets.all(14),
      ambient: index.isEven ? 'drift' : 'flow',
      ambientOpacity: 0.12,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress,
      child: Row(
        children: [
          TAvatar(name: tenant.fullName, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tCardTitle().copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '$bed · ${tenant.displayEmail}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tMeta().copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TPill(
            text: status == 'partial'
                ? 'Partial'
                : status == 'unpaid'
                    ? 'Unpaid'
                    : 'Paid',
            tone: tone,
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// RENT MIX
// ==========================================================

class _RentMix extends StatelessWidget {
  final List<TenantModel> tenants;

  const _RentMix({required this.tenants});

  @override
  Widget build(BuildContext context) {
    final paid = tenants
        .where((t) => (t.paymentStatus ?? 'paid').toLowerCase() == 'paid')
        .length;
    final partial = tenants
        .where((t) => (t.paymentStatus ?? '').toLowerCase() == 'partial')
        .length;
    final unpaid = (tenants.length - paid - partial).clamp(0, tenants.length);

    return TCard(
      ambient: 'flow',
      ambientOpacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Rent mix', style: tSectionTitle())),
              Text(
                'THIS MONTH',
                style: tEyebrow().copyWith(fontSize: 8.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Row(
              children: [
                if (paid > 0)
                  Expanded(
                    flex: paid,
                    child: Container(height: 10, color: kPrimary),
                  ),
                if (partial > 0)
                  Expanded(
                    flex: partial,
                    child: Container(height: 10, color: kWarning),
                  ),
                if (unpaid > 0)
                  Expanded(
                    flex: unpaid,
                    child: Container(height: 10, color: kDanger),
                  ),
                if (tenants.isEmpty)
                  Expanded(
                    flex: 1,
                    child: Container(height: 10, color: kMintDeep),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MixStat(
                  value: '$paid',
                  label: 'Paid',
                  color: kPrimary,
                ),
              ),
              Expanded(
                child: _MixStat(
                  value: '$partial',
                  label: 'Partial',
                  color: kWarning,
                ),
              ),
              Expanded(
                child: _MixStat(
                  value: '$unpaid',
                  label: 'Unpaid',
                  color: kDanger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MixStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MixStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: AppType.h2.copyWith(color: color, fontSize: 21),
        ),
        const SizedBox(height: 1),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppType.caption.copyWith(
            color: kInkMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}
