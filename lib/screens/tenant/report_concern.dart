import 'dart:convert';
import '../../routing/liquid_page_route.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/app_colors.dart';
import '../../core/design_tokens.dart';
import '../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/lottie_art.dart';
import '../../widgets/tahanan_kit.dart';
import '../../widgets/scroll_reveal.dart';
import '../../widgets/ui.dart';

class AttachmentItem {
  final XFile file;
  final String base64Data;
  final String mimeType;
  final bool isVideo;
  AttachmentItem({
    required this.file,
    required this.base64Data,
    required this.mimeType,
    this.isVideo = false,
  });
}

class ReportConcernScreen extends StatefulWidget {
  const ReportConcernScreen({super.key});

  @override
  State<ReportConcernScreen> createState() => _ReportConcernScreenState();
}

class _ReportConcernScreenState extends State<ReportConcernScreen> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'Maintenance';
  final _subjectCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;
  final List<AttachmentItem> _attachments = [];

  static const List<({String name, IconData icon})> _categorySpecs = [
    (name: 'Maintenance', icon: AppIcons.buildLine),
    (name: 'Utility', icon: AppIcons.boltLine),
    (name: 'Cleanliness', icon: AppIcons.cleaningLine),
    (name: 'Security', icon: AppIcons.shieldLine),
    (name: 'Noise', icon: AppIcons.volumeLine),
    (name: 'Other', icon: AppIcons.moreHorizontal),
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(bool isVideo, ImageSource source) async {
    try {
      final picker = ImagePicker();
      XFile? picked;
      if (isVideo) {
        picked = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 30),
        );
      } else {
        picked = await picker.pickImage(
          source: source,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
        );
      }

      if (picked != null) {
        if (isVideo) {
          final controller = VideoPlayerController.file(File(picked.path));
          await controller.initialize();
          final duration = controller.value.duration;
          final seconds = duration.inMilliseconds / 1000.0;
          await controller.dispose();

          if (seconds > 30.1) {
            if (mounted) {
              showTSnack(
                context,
                'Video must not exceed 30 seconds',
                error: true,
                icon: AppIcons.alert,
              );
            }
            return;
          }
        }

        final bytes = await picked.readAsBytes();
        HapticFeedback.lightImpact();
        setState(() {
          _attachments.add(AttachmentItem(
            file: picked!,
            base64Data: base64Encode(bytes),
            mimeType: picked.mimeType ?? (isVideo ? 'video/mp4' : 'image/jpeg'),
            isVideo: isVideo,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        showTSnack(
          context,
          'Could not attach media: $e',
          error: true,
          icon: AppIcons.alert,
        );
      }
    }
  }

  void _showAttachmentPicker() {
    HapticFeedback.selectionClick();
    showLiquidSheet<void>(
      context,
      (ctx) => tSheetBody(
        ctx,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Attach media',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppType.displayFamily,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add photos or a short video (up to 30 seconds).',
              textAlign: TextAlign.center,
              style: tMeta(),
            ),
            const SizedBox(height: 12),
            TSettingRow(
              icon: AppIcons.imageLine,
              label: 'Image from gallery',
              first: true,
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(false, ImageSource.gallery);
              },
            ),
            TSettingRow(
              icon: AppIcons.cameraLine,
              label: 'Take a photo',
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(false, ImageSource.camera);
              },
            ),
            TSettingRow(
              icon: AppIcons.videoLine,
              label: 'Video from gallery',
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(true, ImageSource.gallery);
              },
            ),
            TSettingRow(
              icon: AppIcons.videoLine,
              label: 'Record a video',
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(true, ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _submitting = true);

    try {
      List<Map<String, dynamic>>? attachments;
      if (_attachments.isNotEmpty) {
        attachments = _attachments
            .map((a) => {
                  'fileName': a.file.name,
                  'mimeType': a.mimeType,
                  'dataBase64': a.base64Data,
                })
            .toList();
      }

      await context.read<AppState>().createConcern(
            _category.toLowerCase(),
            _subjectCtrl.text.trim(),
            _detailsCtrl.text.trim(),
            attachments: attachments,
          );
      if (mounted) {
        HapticFeedback.mediumImpact();
        showTSnack(context, 'Concern submitted successfully');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showTSnack(
          context,
          'Failed to submit concern: $e',
          error: true,
          icon: AppIcons.alert,
        );
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TahananBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: tScreenPadding(context),
            children: revealAll([
              const TBackRow(),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF052E1C),
                      Color(0xFF0A4B30),
                      Color(0xFF0F7A44)
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E0F7A44),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: TAmbient(
                        art: 'aurora',
                        opacity: 0.5,
                        size: 360,
                        alignment: Alignment.bottomRight,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            const LottieArt('shield', size: 58),
                            const SizedBox(height: 8),
                            Text(
                              'REPORT A CONCERN',
                              textAlign: TextAlign.center,
                              style: tEyebrow().copyWith(
                                color: kLime,
                                fontSize: 9.5,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'What needs attention?',
                              textAlign: TextAlign.center,
                              style: tScreenTitle().copyWith(
                                color: Colors.white,
                                fontSize: 23,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pick a category, describe it, and attach a photo or '
                              'a short video.',
                              textAlign: TextAlign.center,
                              style: tMeta().copyWith(
                                color: const Color(0xFFD7EADF),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.55,
                children: _categorySpecs.map((spec) {
                  final selected = _category == spec.name;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _category = spec.name);
                    },
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: selected ? kMint : Colors.white,
                        borderRadius: BorderRadius.circular(kCardRadius),
                        border: Border.all(
                          color: selected ? kPrimary : kHairline,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: kCardShadow,
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: TAmbient(
                              art: 'drift',
                              opacity: selected ? 0.18 : 0.10,
                              size: 300,
                              alignment: Alignment.topRight,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TIconSquare(icon: spec.icon),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    spec.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: tLabel().copyWith(fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g. Leaky faucet in bathroom',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Add a short subject so your owner knows what is wrong.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _detailsCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Dripping since last night…',
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please provide details of the concern.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TCard(
                padding: const EdgeInsets.all(12),
                onTap: _showAttachmentPicker,
                child: Row(
                  children: [
                    TIconSquare(icon: AppIcons.addLine),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Photos & videos',
                            style: TextStyle(
                              fontFamily: AppType.displayFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.25,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('Videos up to 30 seconds', style: tMeta()),
                        ],
                      ),
                    ),
                    if (_attachments.isNotEmpty)
                      TPill(
                        text: '${_attachments.length}',
                        tone: TPillTone.ok,
                      ),
                  ],
                ),
              ),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final item = _attachments[i];
                      return SizedBox(
                        width: 84,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: item.isVideo
                                  ? Container(
                                      color: kMintDeep,
                                      child: Center(
                                        child: Icon(
                                          AppIcons.videoLine,
                                          color: kPrimary,
                                          size: 28,
                                        ),
                                      ),
                                    )
                                  : Image.memory(
                                      base64Decode(item.base64Data),
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _attachments.removeAt(i));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: kDanger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    AppIcons.closeLine,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Next: report logged, owner notified, you rate the fix.',
                style: tMeta(),
              ),
              const SizedBox(height: 14),
              TButton(
                text: 'Submit report',
                icon: AppIcons.forward,
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ], slide: 0.05),
          ),
        ),
      ),
    );
  }
}
