import 'package:flutter/material.dart';
import '../../routing/liquid_page_route.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/tahanan_kit.dart';
import 'concerns_kit.dart';

class ConcernsScreen extends StatelessWidget {
  final void Function(int)? onNavigateTab;

  const ConcernsScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    return ConcernsBody(
      onConcernTap: (concern) => showEditConcernSheet(context, concern),
      onOpenRooms: () => onNavigateTab?.call(1),
      onOpenTenants: () => onNavigateTab?.call(2),
    );
  }

  static void showEditConcernSheet(BuildContext context, ConcernModel q) =>
      _showConcernSheet(context, q);
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case ConcernModel.statusResolved:
      return 'Resolved';
    case ConcernModel.statusUnread:
      return 'Unread';
    default:
      return 'Pending';
  }
}

TPillTone _statusTone(String status) {
  switch (status.toLowerCase()) {
    case ConcernModel.statusResolved:
      return TPillTone.ok;
    case ConcernModel.statusUnread:
      return TPillTone.bad;
    default:
      return TPillTone.pending;
  }
}

void _showConcernSheet(BuildContext context, ConcernModel q) {
  final responseCtrl = TextEditingController(text: q.ownerResponse ?? '');
  var status = q.status;
  var submitting = false;

  showLiquidSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => tSheetBody(
        ctx,
        SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      q.subject,
                      style: TextStyle(
                        fontSize: 20,
                        height: 26 / 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TPill(
                    text: _statusLabel(status),
                    tone: _statusTone(status),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${q.tenantName ?? 'Tenant'} · '
                '${q.roomNumber == null ? 'No room' : 'Room ${q.roomNumber}'} · '
                '${tWhen(q.createdAt)}',
                style: tMeta(),
              ),
              if (q.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: q.attachments.take(3).map((a) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AspectRatio(
                          aspectRatio: 1.4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: a.publicUrl == null
                                ? ColoredBox(
                                    color: kMintDeep,
                                    child: Icon(
                                      AppIcons.imageLine,
                                      color: kPrimary,
                                    ),
                                  )
                                : Image.network(
                                    a.publicUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => ColoredBox(
                                      color: kMintDeep,
                                      child: Icon(
                                        AppIcons.imageLine,
                                        color: kPrimary,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Text(q.details, style: tBody()),
              if (q.rating != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    TStars(rating: q.rating!, size: 18),
                    const SizedBox(width: 8),
                    Text('${q.rating!} of 5', style: tMeta()),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                decoration: BoxDecoration(
                  border: Border.all(color: kHairline),
                  borderRadius: BorderRadius.circular(16),
                  color: kSurfaceAlt,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UPDATE STATUS',
                      style: tEyebrow(color: kInkSoft),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TSolidPill(
                          text: 'Unread',
                          selected: status == ConcernModel.statusUnread,
                          onTap: () => setSheetState(
                            () => status = ConcernModel.statusUnread,
                          ),
                        ),
                        TSolidPill(
                          text: 'Pending',
                          selected: status == ConcernModel.statusPending,
                          onTap: () => setSheetState(
                            () => status = ConcernModel.statusPending,
                          ),
                        ),
                        TSolidPill(
                          text: 'Resolved',
                          selected: status == ConcernModel.statusResolved,
                          onTap: () => setSheetState(
                            () => status = ConcernModel.statusResolved,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: responseCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Your response',
                  hintText: 'e.g. Plumber scheduled for tomorrow, 9:00 AM.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TButton(
                      text: 'Mark pending',
                      variant: TButtonVariant.secondary,
                      height: 48,
                      loading: submitting,
                      onPressed: submitting
                          ? null
                          : () => _save(
                                context,
                                ctx,
                                q,
                                ConcernModel.statusPending,
                                responseCtrl.text,
                                setSheetState,
                                (v) => submitting = v,
                              ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TButton(
                      text: 'Resolve',
                      height: 48,
                      loading: submitting,
                      onPressed: submitting
                          ? null
                          : () => _save(
                                context,
                                ctx,
                                q,
                                ConcernModel.statusResolved,
                                responseCtrl.text,
                                setSheetState,
                                (v) => submitting = v,
                              ),
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

Future<void> _save(
  BuildContext context,
  BuildContext sheetContext,
  ConcernModel q,
  String status,
  String response,
  StateSetter setSheetState,
  void Function(bool) setSubmitting,
) async {
  setSheetState(() => setSubmitting(true));
  try {
    await context.read<AppState>().updateConcern(
          q.id,
          status,
          response: response.trim(),
        );
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    if (context.mounted) {
      showTSnack(context, 'Concern updated');
    }
  } catch (e) {
    setSheetState(() => setSubmitting(false));
    if (context.mounted) {
      showTSnack(
        context,
        'Failed to update: $e',
        error: true,
        icon: AppIcons.alert,
      );
    }
  }
}
