import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Semantic icon system for Tahanan.
///
/// Every tile is a cheap gradient container (no blur, single soft shadow)
/// so grids of cards stay at 60fps. Icons are Material rounded glyphs chosen
/// for instant recognition — no emoji anywhere.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? background;
  final Color? borderColor;
  final double size;
  final double iconSize;
  final bool gradient;

  IconTile({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.borderColor,
    this.size = 40,
    this.iconSize = 20,
    this.gradient = true,
  });

  factory IconTile.room({double size = 42}) => IconTile(
        icon: AppIcons.room,
        size: size,
        iconSize: size * AppColors.tileIconRatio,
      );

  factory IconTile.tenant({double size = 42}) => IconTile(
        icon: AppIcons.tenant,
        color: AppColors.primaryDark,
        background: const Color(0xFFE7F8EE),
        borderColor: const Color(0xFFBFE6CC),
        size: size,
        iconSize: size * AppColors.tileIconRatio,
      );

  factory IconTile.wallet({ColorScheme? scheme, double size = 34}) => IconTile(
      icon: AppIcons.wallet,
      size: size,
      iconSize: size * AppColors.tileIconRatio);

  factory IconTile.bed({double size = 42}) => IconTile(
      icon: AppIcons.room,
      size: size,
      iconSize: size * AppColors.tileIconRatio);

  factory IconTile.concern({double size = 34}) => IconTile(
        icon: AppIcons.concern,
        size: size,
        iconSize: size * AppColors.tileIconRatio,
        color: const Color(0xFFB45309),
        background: const Color(0xFFFEF3C7),
        borderColor: const Color(0xFFF5D98B),
      );

  factory IconTile.announcement({double size = 36}) => IconTile(
        icon: AppIcons.announcement,
        size: size,
        iconSize: size * AppColors.tileIconRatio,
        color: const Color(0xFF0369A1),
        background: const Color(0xFFE0F2FE),
        borderColor: const Color(0xFFBAE6FD),
      );

  factory IconTile.key({double size = 32}) => IconTile(
      icon: AppIcons.key, size: size, iconSize: size * AppColors.tileIconRatio);

  factory IconTile.calendar({double size = 34}) => IconTile(
      icon: AppIcons.calendar,
      size: size,
      iconSize: size * AppColors.tileIconRatio);

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primary;
    final background = this.background ?? AppColors.primarySoft;
    final borderColor = this.borderColor ?? AppColors.border;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(background, Colors.white, 0.22)!,
                  background.withValues(alpha: 0.85),
                ],
              )
            : null,
        color: gradient ? null : background,
        borderRadius: BorderRadius.circular(size * AppColors.tileRadiusRatio),
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

/// Single source of truth for glyph choices across owner / tenant UIs.
///
/// ## Icon taxonomy (binding)
///
/// * **Idle / navigation states use outlined (line) glyphs** — `homeLine`,
///   `roomLine`, `groupLine`, `chatLine`, `megaphoneLine`, `keyLine`.
/// * **Active / selected states use the filled counterpart** — `home`,
///   `room`, `tenant`, `concern`, `announcement`. Bottom navigation sets
///   `activeIcon` to the filled glyph so selection cross-fades meaning,
///   not just color.
/// * **Status glyphs are always filled** (`paid`, `partial`, `unpaid`) so
///   they read at small sizes; informational glyphs (`info`, `help`) stay
///   outlined.
/// * Glyphs render at 20-24px inside tiles sized from
///   [AppColors.tileSm]/[AppColors.tileMd]/[AppColors.tileLg]; no emoji,
///   no mixed icon families.
abstract final class AppIcons {
  static const room = Icons.bed_rounded;
  static const roomAlt = Icons.meeting_room_rounded;
  static const tenant = Icons.groups_rounded;
  static const tenantSingle = Icons.person_rounded;
  static const wallet = Icons.wallet_rounded;
  static const paid = Icons.check_circle_rounded;
  static const partial = Icons.timelapse_rounded;
  static const unpaid = Icons.cancel_rounded;
  static const concern = Icons.forum_rounded;
  static const concernAlert = Icons.report_rounded;
  static const announcement = Icons.campaign_rounded;
  static const calendar = Icons.calendar_month_rounded;
  static const key = Icons.vpn_key_rounded;
  static const home = Icons.home_rounded;
  static const houses = Icons.home_work_rounded;
  static const addHouse = Icons.add_home_work_rounded;
  static const dashboard = Icons.apps_rounded;
  static const seats = Icons.event_seat_rounded;
  static const open = Icons.meeting_room_outlined;
  static const full = Icons.block_rounded;
  static const star = Icons.star_rounded;
  static const support = Icons.support_agent_rounded;
  static const shield = Icons.verified_user_rounded;
  static const bolt = Icons.bolt_rounded;
  static const sparkle = Icons.auto_awesome_rounded;
  static const chevron = Icons.chevron_right_rounded;
  static const outward = Icons.arrow_outward_rounded;
  static const logout = Icons.logout_rounded;
  static const swap = Icons.swap_horiz_rounded;
  static const search = Icons.search_rounded;
  static const image = Icons.image_rounded;
  static const video = Icons.videocam_rounded;
  static const play = Icons.play_circle_fill_rounded;
  static const copy = Icons.copy_rounded;
  static const check = Icons.check_rounded;
  static const tune = Icons.tune_rounded;

  // Actions
  static const add = Icons.add_rounded;
  static const remove = Icons.remove_rounded;
  static const edit = Icons.edit_rounded;
  static const delete = Icons.delete_outline_rounded;
  static const close = Icons.close_rounded;
  static const clear = Icons.clear_rounded;
  static const refresh = Icons.refresh_rounded;
  static const zoomIn = Icons.zoom_in_rounded;
  static const moreVertical = Icons.more_vert_rounded;
  static const moreHorizontal = Icons.more_horiz_rounded;
  static const expand = Icons.keyboard_arrow_down_rounded;
  static const back = Icons.arrow_back_rounded;
  static const forward = Icons.arrow_forward_rounded;
  static const doneAll = Icons.done_all_rounded;

  // Status
  static const success = Icons.check_circle_rounded;
  static const checkCircleOutline = Icons.check_circle_outline_rounded;
  static const errorOutline = Icons.error_outline_rounded;
  static const info = Icons.info_outline_rounded;
  static const help = Icons.help_outline_rounded;
  static const alert = Icons.notification_important_rounded;
  static const notifications = Icons.notifications_none_rounded;
  static const reportProblem = Icons.report_problem_rounded;
  static const sad = Icons.sentiment_very_dissatisfied_rounded;
  static const cancel = Icons.cancel_rounded;
  static const lock = Icons.lock_outline_rounded;
  static const shieldOutline = Icons.shield_outlined;
  static const verifiedOutline = Icons.verified_user_outlined;
  static const starOutline = Icons.star_outline_rounded;

  // Line-art counterparts used by the reference UI.
  static const homeLine = Icons.home_outlined;
  static const roomLine = Icons.bed_outlined;
  static const groupLine = Icons.groups_outlined;
  static const chatLine = Icons.chat_bubble_outline_rounded;
  static const megaphoneLine = Icons.campaign_outlined;
  static const keyLine = Icons.vpn_key_outlined;
  static const shieldLine = Icons.shield_outlined;
  static const helpLine = Icons.help_outline_rounded;
  static const boltLine = Icons.bolt_outlined;
  static const buildLine = Icons.handyman_outlined;
  static const cleaningLine = Icons.cleaning_services_outlined;
  static const volumeLine = Icons.volume_up_outlined;
  static const walletLine = Icons.wallet_outlined;
  static const lockLine = Icons.lock_outline_rounded;
  static const swapLine = Icons.swap_horiz_rounded;
  static const articleLine = Icons.article_outlined;
  static const categoryLine = Icons.category_outlined;
  static const imageLine = Icons.image_outlined;
  static const videoLine = Icons.videocam_outlined;
  static const cameraLine = Icons.camera_alt_outlined;
  static const addLine = Icons.add_rounded;
  static const removeLine = Icons.remove_rounded;
  static const checkLine = Icons.check_rounded;
  static const closeLine = Icons.close_rounded;
  static const starLine = Icons.star_outline_rounded;
  static const roomDoorLine = Icons.meeting_room_outlined;
  static const seatLine = Icons.event_seat_outlined;
  static const calendarLine = Icons.calendar_month_outlined;
  static const personLine = Icons.person_outline_rounded;
  static const peopleLine = Icons.people_outline_rounded;

  // Content
  static const apartment = Icons.apartment_rounded;
  static const roomOutline = Icons.meeting_room_outlined;
  static const people = Icons.people_outline_rounded;
  static const personRemove = Icons.person_remove_rounded;
  static const article = Icons.article_outlined;
  static const category = Icons.category_rounded;
  static const title = Icons.title_rounded;
  static const attachment = Icons.attachment_rounded;
  static const camera = Icons.camera_alt_rounded;
  static const addPhoto = Icons.add_a_photo_outlined;
  static const photoLibrary = Icons.photo_library_rounded;
  static const videoCollection = Icons.video_collection_rounded;
  static const playOutline = Icons.play_circle_outline_rounded;
  static const brokenImage = Icons.broken_image_rounded;
  static const tap = Icons.touch_app_rounded;
  static const email = Icons.alternate_email_rounded;
  static const personAdd = Icons.person_add_alt_1_rounded;
  static const link = Icons.link_rounded;
  static const build = Icons.handyman_rounded;
  static const cleaning = Icons.cleaning_services_rounded;
  static const volume = Icons.volume_up_rounded;

  // Missing line counterparts improvised inline elsewhere; now canonical.
  static const personAddLine = Icons.person_add_alt_outlined;
  static const refreshLine = Icons.refresh_outlined;
  static const logoutLine = Icons.logout_outlined;
  static const tuneLine = Icons.tune_outlined;
  static const searchLine = Icons.search_outlined;
}
