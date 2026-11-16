import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../routing/liquid_page_route.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/ui.dart';
import 'associate_tenant.dart';
import 'tenants_kit.dart';

class TenantsScreen extends StatelessWidget {
  final void Function(int)? onNavigateTab;

  const TenantsScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    return TenantsBody(
      onTenantTap: (tenant) => TenantCalendarSheet.show(
        context,
        tenant,
        isOwner: true,
      ),
      onTenantLongPress: (tenant) => _showTenantActions(
        context,
        context.read<AppState>(),
        tenant,
      ),
      onAssociate: (account) => pushLiquidPage(
        context,
        AssociateTenantScreen(unassigned: account),
      ),
      onRemoveAccount: (account) => _confirmRemoveAccount(
        context,
        context.read<AppState>(),
        account,
      ),
      onInvite: () => _showInviteSheet(context),
      onOpenRooms: () => onNavigateTab?.call(1),
    );
  }

  void _showInviteSheet(BuildContext context) {
    final key = context.read<AppState>().selected?.joinKey ?? '';
    showLiquidSheet<void>(
      context,
      (ctx) => tSheetBody(
        ctx,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invite a tenant', style: tSectionTitle()),
            const SizedBox(height: 4),
            Text(
              'Send this key. They sign in, join the house, then you attach them to a room.',
              style: tMeta(),
            ),
            const SizedBox(height: 14),
            if (key.isEmpty)
              Text('No house key is available yet.', style: tMeta())
            else
              TKeyStrip(
                keyText: key,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: key));
                  showTSnack(ctx, 'House key copied', icon: AppIcons.keyLine);
                },
              ),
            const SizedBox(height: 14),
            TButton(
              text: 'Done',
              variant: TButtonVariant.secondary,
              height: 46,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showTenantActions(
    BuildContext context,
    AppState s,
    TenantModel t,
  ) {
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
                TAvatar(name: t.fullName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.fullName, style: tSectionTitle()),
                      const SizedBox(height: 2),
                      Text(
                        t.roomNumber == null
                            ? 'No room assigned'
                            : 'Room ${t.roomNumber}',
                        style: tMeta(),
                      ),
                    ],
                  ),
                ),
                TPill(
                  text: _statusLabel(t.paymentStatus),
                  tone: _statusTone(t.paymentStatus),
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
    TenantModel tenant,
    String status,
  ) async {
    try {
      await s.updateTenantStatus(tenant.id, status);
      if (context.mounted) {
        showTSnack(
            context, '${tenant.fullName} marked ${status.toUpperCase()}');
      }
    } catch (e) {
      if (context.mounted) {
        showTSnack(
          context,
          'Failed to update status: $e',
          error: true,
          icon: AppIcons.alert,
        );
      }
    }
  }

  Future<void> _confirmRemoveAccount(
    BuildContext context,
    AppState s,
    UnassignedAccount a,
  ) async {
    final ok = await tConfirm(
      context,
      title: 'Remove account?',
      message: '${a.email} will lose access to this boarding house.',
      confirm: 'Remove',
      danger: true,
    );

    if (ok && context.mounted) {
      try {
        await s.removeAccount(a.userId);
        if (context.mounted) {
          showTSnack(context, 'Removed ${a.email}');
        }
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

    if (ok && context.mounted) {
      try {
        await s.removeTenant(t.id);
        if (context.mounted) {
          showTSnack(context, 'Removed ${t.fullName}');
        }
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
}

String _statusLabel(String? status) {
  switch ((status ?? 'paid').toLowerCase()) {
    case 'partial':
      return 'Partial';
    case 'unpaid':
      return 'Unpaid';
    default:
      return 'Paid';
  }
}

TPillTone _statusTone(String? status) {
  switch ((status ?? 'paid').toLowerCase()) {
    case 'partial':
      return TPillTone.pending;
    case 'unpaid':
      return TPillTone.bad;
    default:
      return TPillTone.ok;
  }
}
