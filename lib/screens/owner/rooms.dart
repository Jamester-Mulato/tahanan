import 'package:flutter/material.dart';
import '../../routing/liquid_page_route.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/tahanan_kit.dart';
import 'room_detail.dart';
import 'rooms_kit.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoomsBody(
      onAddRoom: () => showAddRoomDialog(context),
      onOpenRoom: (room) => pushLiquidPage(
        context,
        RoomDetailScreen(room: room),
      ),
      onManageRoom: (room) => showRoomManagementSheet(context, room),
    );
  }

  static Future<void> showAddRoomDialog(BuildContext context) async {
    final numberCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '4');

    await showLiquidSheet<void>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => tSheetBody(
          ctx,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add new room',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Set a room number and starting bed capacity.',
                style: tMeta(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: numberCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Room number',
                  hintText: 'e.g. 106 or 201',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Bed capacity',
                style: tMeta(color: AppColors.text).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StepButton(
                    icon: AppIcons.removeLine,
                    onTap: () {
                      final cur = int.tryParse(capCtrl.text.trim()) ?? 4;
                      setSheetState(
                        () => capCtrl.text = '${(cur - 1).clamp(1, 20)}',
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: capCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(hintText: '4'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StepButton(
                    icon: AppIcons.addLine,
                    onTap: () {
                      final cur = int.tryParse(capCtrl.text.trim()) ?? 4;
                      setSheetState(
                        () => capCtrl.text = '${(cur + 1).clamp(1, 20)}',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TButton(
                text: 'Add room',
                icon: AppIcons.forward,
                onPressed: () async {
                  final num = numberCtrl.text.trim();
                  final cap = int.tryParse(capCtrl.text.trim()) ?? 4;
                  if (num.isEmpty) {
                    showTSnack(
                      context,
                      'Enter a room number first',
                      error: true,
                      icon: AppIcons.alert,
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await context.read<AppState>().addRoom(num, cap);
                    if (context.mounted) {
                      showTSnack(context, 'Room $num added');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showTSnack(
                        context,
                        'Failed to add room: $e',
                        error: true,
                        icon: AppIcons.alert,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showRoomManagementSheet(
    BuildContext context,
    RoomModel room,
  ) async {
    await showLiquidSheet<void>(
      context,
      (sheetCtx) => tSheetBody(
        sheetCtx,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TIconSquare(icon: AppIcons.roomLine),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Room ${room.roomNumber}', style: tSectionTitle()),
                      const SizedBox(height: 2),
                      Text(
                        '${room.occupied} occupied · ${room.capacity} capacity',
                        style: tMeta(),
                      ),
                    ],
                  ),
                ),
                TPill(
                  text: room.isFull ? 'Full' : 'Open',
                  tone: room.isFull ? TPillTone.ok : TPillTone.pending,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TSettingRow(
              icon: AppIcons.peopleLine,
              label: 'Change capacity',
              first: true,
              onTap: () {
                Navigator.pop(sheetCtx);
                _showChangeCapacityDialog(context, room);
              },
            ),
            TSettingRow(
              icon: AppIcons.edit,
              label: 'Rename room',
              onTap: () {
                Navigator.pop(sheetCtx);
                _showRenameRoomDialog(context, room);
              },
            ),
            TSettingRow(
              icon: AppIcons.info,
              label: 'View room details',
              onTap: () {
                Navigator.pop(sheetCtx);
                pushLiquidPage(
                  context,
                  RoomDetailScreen(room: room),
                );
              },
            ),
            TSettingRow(
              icon: AppIcons.delete,
              label: 'Archive room',
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmArchiveRoom(context, room);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showChangeCapacityDialog(
    BuildContext context,
    RoomModel room,
  ) async {
    final capCtrl = TextEditingController(text: '${room.capacity}');
    String? localError;

    await showLiquidDialog<void>(
      context,
      (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Change capacity · Room ${room.roomNumber}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${room.occupied} active occupants', style: tMeta()),
                const SizedBox(height: 14),
                TextField(
                  controller: capCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'New capacity',
                    hintText: 'e.g. 3',
                    errorText: localError,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Capacity cannot go below ${room.occupied}.',
                  style: tMeta(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TButton(
                        text: 'Cancel',
                        variant: TButtonVariant.secondary,
                        height: 48,
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TButton(
                        text: 'Save',
                        height: 48,
                        onPressed: () async {
                          final newCap = int.tryParse(capCtrl.text.trim());
                          if (newCap == null || newCap < 1) {
                            setDialogState(
                              () => localError = 'Enter a valid number.',
                            );
                            return;
                          }
                          if (newCap < room.occupied) {
                            setDialogState(
                              () => localError =
                                  'Room already has ${room.occupied} occupants.',
                            );
                            return;
                          }
                          Navigator.pop(dialogCtx);
                          try {
                            await context
                                .read<AppState>()
                                .updateRoomCapacity(room.id, newCap);
                            if (context.mounted) {
                              showTSnack(
                                context,
                                'Room ${room.roomNumber} capacity set to $newCap',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showTSnack(
                                context,
                                'Failed to update capacity: $e',
                                error: true,
                                icon: AppIcons.alert,
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _showRenameRoomDialog(
    BuildContext context,
    RoomModel room,
  ) async {
    final numCtrl = TextEditingController(text: room.roomNumber);

    await showLiquidDialog<void>(
      context,
      (dialogCtx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rename Room ${room.roomNumber}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: numCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Room number / name',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TButton(
                      text: 'Cancel',
                      variant: TButtonVariant.secondary,
                      height: 48,
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TButton(
                      text: 'Save',
                      height: 48,
                      onPressed: () async {
                        final newNum = numCtrl.text.trim();
                        if (newNum.isEmpty) return;
                        Navigator.pop(dialogCtx);
                        try {
                          await context
                              .read<AppState>()
                              .renameRoom(room.id, newNum);
                          if (context.mounted) {
                            showTSnack(context, 'Room renamed to "$newNum"');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showTSnack(
                              context,
                              'Failed to rename room: $e',
                              error: true,
                              icon: AppIcons.alert,
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _confirmArchiveRoom(
    BuildContext context,
    RoomModel room,
  ) async {
    if (room.occupied > 0) {
      await showLiquidDialog<void>(
        context,
        (ctx) => Dialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cannot archive room',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Room ${room.roomNumber} has ${room.occupied} active occupants. '
                  'Reassign or remove tenants first.',
                  style: tBody(color: kInkMuted),
                ),
                const SizedBox(height: 16),
                TButton(
                  text: 'OK',
                  height: 48,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final ok = await tConfirm(
      context,
      title: 'Archive Room ${room.roomNumber}?',
      message: 'Its history stays, and you can restore it later.',
      confirm: 'Archive',
      danger: true,
    );

    if (ok && context.mounted) {
      try {
        await context.read<AppState>().archiveRoom(room.id);
        if (context.mounted) {
          showTSnack(context, 'Room ${room.roomNumber} archived');
        }
      } catch (e) {
        if (context.mounted) {
          showTSnack(
            context,
            'Failed to archive room: $e',
            error: true,
            icon: AppIcons.alert,
          );
        }
      }
    }
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kMint,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: kPrimary),
        ),
      ),
    );
  }
}
