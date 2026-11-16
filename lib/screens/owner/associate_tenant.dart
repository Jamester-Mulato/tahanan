import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/design_tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/scroll_reveal.dart';
import '../../widgets/ui.dart';

class AssociateTenantScreen extends StatefulWidget {
  final UnassignedAccount unassigned;

  const AssociateTenantScreen({super.key, required this.unassigned});

  @override
  State<AssociateTenantScreen> createState() => _AssociateTenantScreenState();
}

class _AssociateTenantScreenState extends State<AssociateTenantScreen> {
  String? _selectedTenantOption;
  String? _selectedRoomId;
  final _newTenantNameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newTenantNameController.text = widget.unassigned.displayName;
    _selectedTenantOption = 'new';
  }

  @override
  void dispose() {
    _newTenantNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.read<AppState>();
    final h = s.selected;
    if (h == null) return;

    HapticFeedback.lightImpact();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      String tenantId;
      if (_selectedTenantOption == 'new' || _selectedTenantOption == null) {
        final name = _newTenantNameController.text.trim();
        if (name.isEmpty) {
          setState(() {
            _error = 'Please enter a tenant name.';
            _submitting = false;
          });
          return;
        }
        final createdTenant = await s.createTenantRecord(
          name,
          widget.unassigned.email,
          null,
        );
        tenantId = createdTenant.id;
      } else {
        tenantId = _selectedTenantOption!;
      }

      if (_selectedRoomId != null && _selectedRoomId!.isNotEmpty) {
        final targetRoom = s.rooms.firstWhere(
          (r) => r.id == _selectedRoomId,
          orElse: () => throw StateError('Room not found'),
        );
        if (targetRoom.isFull) {
          setState(() {
            _error =
                'Room ${targetRoom.roomNumber} is full. Please choose another room.';
            _submitting = false;
          });
          return;
        }
      }

      await s.associateTenant(
        tenantId,
        widget.unassigned.userId,
        _selectedRoomId,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        showTSnack(
          context,
          '${widget.unassigned.displayName} associated successfully',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final unassociatedTenants =
        s.tenants.where((t) => t.userId == null || t.userId!.isEmpty).toList();
    final openRooms = s.rooms.where((r) => !r.isFull).length;
    final linkingExisting =
        _selectedTenantOption != null && _selectedTenantOption != 'new';

    RoomModel? selectedRoom;
    for (final r in s.rooms) {
      if (r.id == _selectedRoomId) {
        selectedRoom = r;
        break;
      }
    }

    final existingName = unassociatedTenants
        .where((t) => t.id == _selectedTenantOption)
        .map((t) => t.fullName)
        .firstOrNull;

    return Scaffold(
      body: TahananBackground(
        child: ListView(
          padding: tScreenPadding(context, bottom: 34),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: revealAll([
            const TBackRow(),
            Center(
              child: TAvatar(
                name: widget.unassigned.displayName,
                size: 72,
                square: true,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ASSOCIATE ACCOUNT',
              textAlign: TextAlign.center,
              style: tEyebrow(),
            ),
            const SizedBox(height: 4),
            Text(
              widget.unassigned.displayName.isNotEmpty
                  ? widget.unassigned.displayName
                  : 'New member',
              textAlign: TextAlign.center,
              style: tScreenTitle().copyWith(fontSize: 26),
            ),
            const SizedBox(height: 3),
            Text(
              widget.unassigned.email,
              textAlign: TextAlign.center,
              style: tMeta(),
            ),
            const SizedBox(height: 16),
            TCard(
              ambient: 'flow',
              ambientOpacity: 0.14,
              child: Row(
                children: [
                  TIconSquare(icon: AppIcons.groupLine, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.rooms.length} rooms this house',
                          style: tCardTitle().copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$openRooms with space right now',
                          style: tMeta().copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  TPill(
                    text: '$openRooms open',
                    tone: openRooms > 0 ? TPillTone.ok : TPillTone.bad,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('How should we link this account?', style: tSectionTitle()),
            const SizedBox(height: 10),
            _ModeCard(
              icon: AppIcons.addLine,
              title: 'Create a new tenant record',
              body:
                  'Use the Google name below and start a fresh record for this account.',
              selected: !linkingExisting,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedTenantOption = 'new';
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 8),
            _ModeCard(
              icon: AppIcons.link,
              title: 'Link an existing record',
              body: unassociatedTenants.isEmpty
                  ? 'No unassigned tenant records are available yet.'
                  : 'Attach this account to a tenant record already in the house.',
              selected: linkingExisting,
              disabled: unassociatedTenants.isEmpty,
              onTap: () {
                if (unassociatedTenants.isEmpty) {
                  showTSnack(
                    context,
                    'There are no unassigned tenant records',
                    error: true,
                    icon: AppIcons.alert,
                  );
                  return;
                }
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedTenantOption = unassociatedTenants.first.id;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 12),
            if (!linkingExisting)
              TCard(
                ambient: 'drift',
                ambientOpacity: 0.12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tenant record name', style: tCardTitle()),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _newTenantNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(AppIcons.personLine, size: 19),
                      ),
                    ),
                  ],
                ),
              )
            else
              TCard(
                ambient: 'drift',
                ambientOpacity: 0.12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose the existing record', style: tCardTitle()),
                    const SizedBox(height: 4),
                    Text(
                      'The account will take over this record and its history.',
                      style: tMeta().copyWith(fontSize: 10.5),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < unassociatedTenants.length; i++) ...[
                      _ExistingRecordRow(
                        name: unassociatedTenants[i].fullName,
                        email: unassociatedTenants[i].displayEmail,
                        selected:
                            _selectedTenantOption == unassociatedTenants[i].id,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedTenantOption = unassociatedTenants[i].id;
                            _error = null;
                          });
                        },
                      ),
                      if (i != unassociatedTenants.length - 1)
                        Divider(height: 1, color: kHairline),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: Text('Assign to a room', style: tSectionTitle())),
                Text('OPTIONAL', style: tEyebrow().copyWith(fontSize: 8.5)),
              ],
            ),
            const SizedBox(height: 10),
            _RoomOptionCard(
              selected: _selectedRoomId == null,
              icon: AppIcons.calendarLine,
              title: 'Assign later',
              subtitle: 'Create the tenant record without a room',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedRoomId = null);
              },
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < s.rooms.length; i++) ...[
              _RoomOptionCard(
                selected: _selectedRoomId == s.rooms[i].id,
                disabled: s.rooms[i].isFull,
                icon: AppIcons.roomLine,
                title: 'Room ${s.rooms[i].roomNumber}',
                subtitle:
                    '${s.rooms[i].occupied} / ${s.rooms[i].capacity} beds occupied',
                ambient: i.isEven ? 'halo' : null,
                trailing: TPill(
                  text: s.rooms[i].isFull ? 'Full' : 'Open',
                  tone: s.rooms[i].isFull ? TPillTone.bad : TPillTone.ok,
                ),
                onTap: s.rooms[i].isFull
                    ? () {
                        showTSnack(
                          context,
                          'Room ${s.rooms[i].roomNumber} is already full',
                          error: true,
                          icon: AppIcons.alert,
                        );
                      }
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedRoomId = s.rooms[i].id);
                      },
              ),
              if (i != s.rooms.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 18),
            TCard(
              ambient: 'aurora',
              ambientOpacity: 0.12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            Text('Review association', style: tSectionTitle()),
                      ),
                      Icon(
                        AppIcons.shieldLine,
                        size: 18,
                        color: kPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TFactRow(
                    label: 'Google account',
                    value: widget.unassigned.email,
                  ),
                  TFactRow(
                    label: 'Tenant record',
                    value: linkingExisting
                        ? (existingName ?? 'Existing record')
                        : 'New record',
                  ),
                  TFactRow(
                    label: 'Room',
                    value: selectedRoom == null
                        ? 'Assign later'
                        : 'Room ${selectedRoom.roomNumber}',
                  ),
                  if (selectedRoom != null) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: TBedDots(
                        capacity: selectedRoom.capacity,
                        occupied: selectedRoom.occupied,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF6C9C9)),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.alert, color: kDanger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppType.caption.copyWith(
                          color: kDanger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TButton(
              text: 'Confirm association',
              icon: AppIcons.checkLine,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ], slide: 0.05),
        ),
      ),
    );
  }
}

// ==========================================================
// MODE CARD
// ==========================================================

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    this.disabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? kMint : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? kPrimary : kHairline,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: kCardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? kForest : kMint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? kLime : kPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tCardTitle().copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(body, style: tMeta().copyWith(fontSize: 10.5)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 21,
                color: selected ? kPrimary : kInkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExistingRecordRow extends StatelessWidget {
  final String name;
  final String email;
  final bool selected;
  final VoidCallback onTap;

  const _ExistingRecordRow({
    required this.name,
    required this.email,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            TAvatar(name: name, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tLabel(),
                  ),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tMeta().copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? kPrimary : kInkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// ROOM OPTION
// ==========================================================

class _RoomOptionCard extends StatelessWidget {
  final bool selected;
  final bool disabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? ambient;
  final VoidCallback onTap;

  const _RoomOptionCard({
    required this.selected,
    this.disabled = false,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.ambient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: TCard(
          padding: const EdgeInsets.all(14),
          ambient: ambient,
          ambientOpacity: 0.12,
          color: selected ? kMint : Colors.white,
          border: Border.all(
            color: selected ? kPrimary : kHairline,
            width: selected ? 1.5 : 1,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? kForest : kMint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? kLime : kPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tLabel()),
                    const SizedBox(height: 1),
                    Text(subtitle, style: tMeta().copyWith(fontSize: 10.5)),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(AppIcons.checkLine, color: kPrimary, size: 20),
              ] else if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
