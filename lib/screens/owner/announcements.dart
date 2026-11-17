import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/design_tokens.dart';
import '../../models/models.dart';
import '../../routing/liquid_page_route.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/lottie_art.dart';
import '../../widgets/pressable.dart';
import '../../widgets/scroll_reveal.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/ui.dart';

class AnnouncementsScreen extends StatefulWidget {
  final bool isOwner;
  final VoidCallback? onBack;

  const AnnouncementsScreen({
    super.key,
    this.isOwner = true,
    this.onBack,
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _search = TextEditingController();
  String _query = '';
  int _filter = 0;

  static const _filters = ['All', 'This month', 'Earlier'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final all = s.announcements;
    final now = DateTime.now();
    final thisMonth = all
        .where(
          (a) =>
              a.publishedAt != null &&
              a.publishedAt!.year == now.year &&
              a.publishedAt!.month == now.month,
        )
        .toList();

    final q = _query.trim().toLowerCase();
    final filtered = all.where((a) {
      final matchesQuery = q.isEmpty ||
          a.title.toLowerCase().contains(q) ||
          a.message.toLowerCase().contains(q);
      if (!matchesQuery) return false;
      if (_filter == 1) {
        return a.publishedAt != null &&
            a.publishedAt!.year == now.year &&
            a.publishedAt!.month == now.month;
      }
      if (_filter == 2) {
        return a.publishedAt == null ||
            a.publishedAt!.year != now.year ||
            a.publishedAt!.month != now.month;
      }
      return true;
    }).toList();

    final featured =
        _filter == 0 && q.isEmpty && all.isNotEmpty ? all.first : null;
    final archive = featured == null
        ? filtered
        : filtered.where((a) => a.id != featured.id).toList();

    return Material(
      type: MaterialType.transparency,
      child: TahananBackground(
        child: RefreshIndicator(
          color: kPrimary,
          backgroundColor: AppColors.surface,
          onRefresh: s.refreshHouse,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final extra = kIsWeb && constraints.maxWidth > 940
                  ? (constraints.maxWidth - 900) / 2
                  : 0.0;
              final base = tScreenPadding(context);
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  base.left + extra,
                  base.top,
                  base.right + extra,
                  base.bottom,
                ),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  const TBackRow(),
                  ScrollReveal(
                    index: 0,
                    child: TLightHeader(
                      icon: AppIcons.megaphoneLine,
                      eyebrow: 'Notice board',
                      title: 'Announcements',
                      subtitle: widget.isOwner
                          ? 'One clear place for everything the house needs to know.'
                          : 'Updates from your landlord, newest first.',
                      stats: [
                        TStatData('${all.length}', 'Total'),
                        TStatData('${thisMonth.length}', 'This month'),
                        TStatData(widget.isOwner ? 'Owner' : 'Tenant', 'View'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ScrollReveal(
                    index: 1,
                    child: _SearchField(
                      controller: _search,
                      value: _query,
                      onChanged: (value) => setState(() => _query = value),
                      onClear: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  ScrollReveal(
                    index: 2,
                    child: TSegmented(
                      tabs: _filters,
                      selectedIndex: _filter,
                      onSelect: (i) => setState(() => _filter = i),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (featured != null) ...[
                    ScrollReveal(
                      index: 3,
                      child: _FeaturedNotice(
                        announcement: featured,
                        onTap: () => _openNotice(context, featured),
                        onAction: () => _noticeActions(context, featured),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  ScrollReveal(
                    index: 4,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            featured != null || archive.isNotEmpty
                                ? 'Notice archive'
                                : 'Notices',
                            style: tSectionTitle(),
                          ),
                        ),
                        if (filtered.isNotEmpty)
                          TPill(
                            text: '${filtered.length}',
                            tone: TPillTone.neutral,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isEmpty)
                    ScrollReveal(
                      index: 5,
                      child: TCard(
                        ambient: 'aurora',
                        ambientOpacity: 0.14,
                        child: TEmpty(
                          icon: q.isEmpty
                              ? AppIcons.megaphoneLine
                              : Icons.search_off_rounded,
                          title: q.isEmpty
                              ? 'No announcements yet'
                              : 'No notices match "$_query"',
                          message: q.isNotEmpty
                              ? 'Try a shorter word, or clear the search to see everything.'
                              : widget.isOwner
                                  ? 'Publish news, reminders or maintenance notices and they will land here.'
                                  : 'When the owner posts an update it will appear here.',
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < archive.length; i++) ...[
                      ScrollReveal(
                        index: 5 + i,
                        child: _NoticeCard(
                          announcement: archive[i],
                          index: i,
                          onTap: () => _openNotice(context, archive[i]),
                          onAction: () => _noticeActions(context, archive[i]),
                        ),
                      ),
                      if (i != archive.length - 1) const SizedBox(height: 10),
                    ],
                  if (widget.isOwner) ...[
                    const SizedBox(height: 16),
                    ScrollReveal(
                      index: 12,
                      child: TButton(
                        text: 'New announcement',
                        icon: AppIcons.addLine,
                        onPressed: () => _composer(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openNotice(BuildContext context, AnnouncementModel a) {
    if (widget.isOwner) {
      _noticeActions(context, a);
    } else {
      _detail(context, a);
    }
  }

  void _noticeActions(BuildContext context, AnnouncementModel a) {
    showLiquidSheet<void>(
      context,
      (sheetCtx) => tSheetBody(
        sheetCtx,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kMint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  AppIcons.megaphoneLine,
                  color: kPrimary,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              a.title,
              textAlign: TextAlign.center,
              style: tSectionTitle().copyWith(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              tWhen(a.publishedAt),
              textAlign: TextAlign.center,
              style: tMeta(),
            ),
            const SizedBox(height: 16),
            TSettingRow(
              icon: AppIcons.articleLine,
              label: 'Read full notice',
              first: true,
              onTap: () {
                Navigator.pop(sheetCtx);
                _detail(context, a);
              },
            ),
            if (widget.isOwner) ...[
              TSettingRow(
                icon: AppIcons.edit,
                label: 'Edit announcement',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _composer(context, existing: a);
                },
              ),
              TSettingRow(
                icon: AppIcons.delete,
                label: 'Delete announcement',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _delete(context, a);
                },
              ),
            ] else
              TSettingRow(
                icon: AppIcons.copy,
                label: 'Copy announcement',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Clipboard.setData(
                    ClipboardData(text: '${a.title}\n\n${a.message}'),
                  );
                  showTSnack(context, 'Announcement copied');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _detail(BuildContext context, AnnouncementModel a) {
    showLiquidSheet<void>(
      context,
      (ctx) => tSheetBody(
        ctx,
        SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: kHeroGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    AppIcons.megaphoneLine,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'NOTICE · ${tShortDate(a.publishedAt).toUpperCase()}',
                textAlign: TextAlign.center,
                style: tEyebrow(),
              ),
              const SizedBox(height: 6),
              Text(
                a.title,
                textAlign: TextAlign.center,
                style: tScreenTitle().copyWith(fontSize: 24),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSurfaceAlt,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kHairline),
                ),
                child: Text(a.message, style: tBody().copyWith(fontSize: 14)),
              ),
              const SizedBox(height: 16),
              TButton(
                text: 'Mark as acknowledged',
                icon: AppIcons.checkLine,
                onPressed: () {
                  Navigator.pop(ctx);
                  showTSnack(context, 'Announcement acknowledged');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, AnnouncementModel a) async {
    final ok = await tConfirm(
      context,
      title: 'Delete announcement?',
      message: 'This removes "${a.title}" for everyone in the house.',
      confirm: 'Delete',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<AppState>().deleteAnnouncement(a.id);
      if (context.mounted) showTSnack(context, 'Announcement deleted');
    } catch (e) {
      if (context.mounted) {
        showTSnack(
          context,
          'Failed to delete: $e',
          error: true,
          icon: AppIcons.alert,
        );
      }
    }
  }

  void _composer(BuildContext context, {AnnouncementModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final msgCtrl = TextEditingController(text: existing?.message ?? '');
    var submitting = false;
    String? error;

    const templates = [
      (
        label: 'Water',
        title: 'Water interruption',
        message:
            'Water service will be interrupted tomorrow from 9:00 AM to 12:00 PM while the line is repaired. Please store enough water tonight.',
      ),
      (
        label: 'Rent',
        title: 'Rent reminder',
        message:
            'A gentle reminder that rent for this month is due on the 5th. Please settle through the usual channel and message me once done.',
      ),
      (
        label: 'Repairs',
        title: 'Scheduled maintenance',
        message:
            'The electrician will visit on Saturday morning to check the hallway outlets. Please keep the common area clear.',
      ),
      (
        label: 'Rules',
        title: 'Quiet hours',
        message:
            'Quiet hours start at 10:00 PM. Please keep music and conversations low so everyone can rest.',
      ),
    ];

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
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: kHeroGradient,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      AppIcons.megaphoneLine,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  existing == null ? 'New announcement' : 'Edit announcement',
                  textAlign: TextAlign.center,
                  style: tSectionTitle().copyWith(fontSize: 21),
                ),
                const SizedBox(height: 4),
                Text(
                  existing == null
                      ? 'Everyone in this boarding house will see it immediately.'
                      : 'Changes are visible to the whole house right away.',
                  textAlign: TextAlign.center,
                  style: tMeta(),
                ),
                const SizedBox(height: 16),
                if (existing == null) ...[
                  Text('QUICK TEMPLATES', style: tEyebrow()),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in templates)
                        TPill(
                          text: t.label,
                          tone: TPillTone.neutral,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            titleCtrl.text = t.title;
                            msgCtrl.text = t.message;
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: titleCtrl,
                  autofocus: existing == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Water interruption notice',
                  ),
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: msgCtrl,
                  maxLines: 6,
                  minLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText: 'Write the details here…',
                    alignLabelWithHint: true,
                    helperText: '${msgCtrl.text.characters.length} characters',
                  ),
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: 16),
                _ComposerPreview(
                  title: titleCtrl.text.trim(),
                  message: msgCtrl.text.trim(),
                  isEditing: existing != null,
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TButton(
                  text: existing == null
                      ? 'Publish announcement'
                      : 'Save changes',
                  icon: AppIcons.forward,
                  loading: submitting,
                  onPressed: submitting
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          final msg = msgCtrl.text.trim();
                          if (title.isEmpty || msg.isEmpty) {
                            setSheetState(
                              () => error = 'Add both a title and a message.',
                            );
                            return;
                          }
                          setSheetState(() {
                            submitting = true;
                            error = null;
                          });
                          try {
                            final s = context.read<AppState>();
                            if (existing == null) {
                              await s.createAnnouncement(title, msg);
                            } else {
                              await s.updateAnnouncement(
                                existing.id,
                                title,
                                msg,
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              showTSnack(
                                context,
                                existing == null
                                    ? 'Announcement published'
                                    : 'Announcement updated',
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setSheetState(() {
                                submitting = false;
                                error = 'Could not save: $e';
                              });
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// SEARCH
// ==========================================================

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kHairline),
        boxShadow: kCardShadow,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppType.bodyStrong.copyWith(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search notices',
          prefixIcon: const Icon(AppIcons.search, size: 19),
          suffixIcon: value.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

// ==========================================================
// FEATURED NOTICE
// ==========================================================

class _FeaturedNotice extends StatelessWidget {
  final AnnouncementModel announcement;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const _FeaturedNotice({
    required this.announcement,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kHeroRadius),
      pressedScale: 0.99,
      child: Container(
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
                size: 420,
                alignment: Alignment.bottomRight,
              ),
            ),
            Positioned(
              right: -34,
              top: -44,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'LATEST',
                          style: AppType.eyebrow.copyWith(
                            color: kDeep,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tShortDate(announcement.publishedAt),
                        style: tMeta(color: kHeroMuted),
                      ),
                      const Spacer(),
                      const LottieArt('pulse', size: 34),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    announcement.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.h2.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    announcement.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(
                      color: const Color(0xFFD7EADF),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onTap,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Read notice',
                                style: AppType.bodyStrong.copyWith(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: kLime,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Notice options',
                        onPressed: onAction,
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                        ),
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

// ==========================================================
// NOTICE CARD
// ==========================================================

class _NoticeCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const _NoticeCard({
    required this.announcement,
    required this.index,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final art = index.isEven ? 'flow' : 'halo';
    return TCard(
      padding: EdgeInsets.zero,
      ambient: art,
      ambientOpacity: 0.13,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kMint, kMintDeep],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white),
              ),
              child: Icon(
                AppIcons.megaphoneLine,
                size: 21,
                color: kPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tShortDate(announcement.publishedAt).toUpperCase(),
                    style: tEyebrow().copyWith(fontSize: 9),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    announcement.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tCardTitle().copyWith(fontSize: 15.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    announcement.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tMeta(color: kInkSoft),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Notice options',
              onPressed: onAction,
              icon: Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: kInkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// COMPOSER PREVIEW
// ==========================================================

class _ComposerPreview extends StatelessWidget {
  final String title;
  final String message;
  final bool isEditing;

  const _ComposerPreview({
    required this.title,
    required this.message,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = title.isNotEmpty || message.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        gradient: kHeroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: TAmbient(
              art: 'flow',
              opacity: 0.35,
              size: 280,
              alignment: Alignment.bottomRight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'PREVIEW · EDITED' : 'PREVIEW · LIVE',
                  style: tEyebrow(color: kLime).copyWith(fontSize: 9),
                ),
                const SizedBox(height: 6),
                Text(
                  title.isEmpty ? 'Your title appears here' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.h3.copyWith(
                    color: title.isEmpty
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.isEmpty
                      ? 'The message preview will fill in as you type.'
                      : message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(
                    color: hasContent
                        ? const Color(0xFFD7EADF)
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 11.5,
                    height: 1.45,
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
