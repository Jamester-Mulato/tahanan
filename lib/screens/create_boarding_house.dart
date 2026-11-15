import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/design_tokens.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/app_icons.dart';
import '../widgets/lottie_art.dart';
import '../widgets/tahanan_kit.dart';
import '../widgets/ui.dart';

class CreateBoardingHouseScreen extends StatefulWidget {
  const CreateBoardingHouseScreen({super.key});

  @override
  State<CreateBoardingHouseScreen> createState() =>
      _CreateBoardingHouseScreenState();
}

class _CreateBoardingHouseScreenState extends State<CreateBoardingHouseScreen> {
  int _step = 1;
  final _nameController =
      TextEditingController(text: 'Green Haven Boarding House');
  final _roomCountController = TextEditingController(text: '6');
  final _capacityController = TextEditingController(text: '3');

  List<TextEditingController> _roomNumberControllers = [];
  List<TextEditingController> _capacityControllers = [];

  BoardingHouse? _createdHouse;
  bool _submitting = false;
  String? _error;

  static const _presets = [
    (label: 'Starter', rooms: 3, beds: 2, note: 'A quiet first house'),
    (label: 'Standard', rooms: 6, beds: 3, note: 'Most boarding houses'),
    (label: 'Family', rooms: 8, beds: 3, note: 'Room to grow'),
  ];

  @override
  void initState() {
    super.initState();
    _syncRoomControllers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCountController.dispose();
    _capacityController.dispose();
    for (final c in _roomNumberControllers) {
      c.dispose();
    }
    for (final c in _capacityControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncRoomControllers() {
    final count = int.tryParse(_roomCountController.text.trim()) ?? 6;
    final defaultCap = _capacityController.text.trim().isEmpty
        ? '3'
        : _capacityController.text.trim();
    final clampedCount = count.clamp(1, 50);

    for (final c in _roomNumberControllers) {
      c.dispose();
    }
    for (final c in _capacityControllers) {
      c.dispose();
    }

    _roomNumberControllers = List.generate(
      clampedCount,
      (i) => TextEditingController(text: '${101 + i}'),
    );
    _capacityControllers = List.generate(
      clampedCount,
      (i) => TextEditingController(text: defaultCap),
    );
  }

  void _adjustIntController(
    TextEditingController ctrl,
    int delta, {
    int min = 1,
    int max = 50,
  }) {
    final current = int.tryParse(ctrl.text.trim()) ?? min;
    final next = (current + delta).clamp(min, max);
    setState(() {
      ctrl.text = '$next';
      if (ctrl == _roomCountController || ctrl == _capacityController) {
        _syncRoomControllers();
      }
    });
  }

  void _goToStep2() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the boarding house a name first.');
      return;
    }
    final count = int.tryParse(_roomCountController.text.trim()) ?? 0;
    if (count <= 0) {
      setState(() => _error = 'Enter how many rooms this house has.');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      _syncRoomControllers();
      _step = 2;
    });
  }

  Future<void> _submitCreate() async {
    HapticFeedback.lightImpact();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      final roomsData = List.generate(
        _roomNumberControllers.length,
        (i) => {
          'roomNumber': _roomNumberControllers[i].text.trim().isEmpty
              ? '${101 + i}'
              : _roomNumberControllers[i].text.trim(),
          'capacity': int.tryParse(_capacityControllers[i].text.trim()) ?? 3,
        },
      );

      final house = await context.read<AppState>().createHouse(name, roomsData);
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _createdHouse = house;
          _step = 3;
          _submitting = false;
        });
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

  void _finish() {
    HapticFeedback.lightImpact();
    final appState = context.read<AppState>();
    if (_createdHouse != null) {
      appState.selectHouse(_createdHouse!);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      1 => 'Set up your rooms',
      2 => 'Customize your rooms',
      _ => 'Your house is ready',
    };
    final subtitle = switch (_step) {
      1 =>
        'Name the house and choose a starting layout. You can refine it later.',
      2 => 'Give every room its number and bed count before opening the doors.',
      _ => 'Share the house key and your tenants can join in a minute.',
    };

    return Scaffold(
      body: TahananBackground(
        child: ListView(
          padding: tScreenPadding(context, bottom: 34),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            const TBackRow(),
            Center(
              child: Text('CREATE BOARDING HOUSE', style: tEyebrow()),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: tScreenTitle().copyWith(fontSize: 29),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: tMeta(color: kInkSoft),
              ),
            ),
            const SizedBox(height: 20),
            _StepIndicator(
              step: _step,
              onBackToFirst: _step > 1 ? () => setState(() => _step = 1) : null,
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              switchInCurve: AppCurves.emphasizedDecel,
              switchOutCurve: AppCurves.softIn,
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  1 => _buildStep1(),
                  2 => _buildStep2(),
                  _ => _buildStep3(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    final roomCount =
        (int.tryParse(_roomCountController.text.trim()) ?? 6).clamp(1, 50);
    final defaultCap =
        (int.tryParse(_capacityController.text.trim()) ?? 3).clamp(1, 20);
    final totalBeds = roomCount * defaultCap;

    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TCard(
          ambient: 'flow',
          ambientOpacity: 0.14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TIconSquare(icon: AppIcons.homeLine, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HOUSE IDENTITY',
                            style: tEyebrow().copyWith(fontSize: 9)),
                        const SizedBox(height: 2),
                        Text('What should tenants call it?',
                            style: tCardTitle()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                style: AppType.bodyStrong.copyWith(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'House name',
                  hintText: 'e.g. Green Haven Boarding House',
                  prefixIcon: Icon(AppIcons.homeLine, size: 19),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CapacityHero(
          totalBeds: totalBeds,
          roomCount: roomCount,
          bedsPerRoom: defaultCap,
        ),
        const SizedBox(height: 12),
        TCard(
          ambient: 'halo',
          ambientOpacity: 0.12,
          child: Column(
            children: [
              _StepperLine(
                icon: AppIcons.roomLine,
                label: 'Rooms',
                hint: 'Private spaces in this house',
                value: '$roomCount',
                onMinus: () => _adjustIntController(
                  _roomCountController,
                  -1,
                  min: 1,
                  max: 50,
                ),
                onPlus: () => _adjustIntController(
                  _roomCountController,
                  1,
                  min: 1,
                  max: 50,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: kHairline),
              ),
              _StepperLine(
                icon: AppIcons.seatLine,
                label: 'Beds per room',
                hint: 'Default for every room',
                value: '$defaultCap',
                onMinus: () => _adjustIntController(
                  _capacityController,
                  -1,
                  min: 1,
                  max: 20,
                ),
                onPlus: () => _adjustIntController(
                  _capacityController,
                  1,
                  min: 1,
                  max: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Text('Layout presets', style: tSectionTitle())),
            Text('TAP TO APPLY', style: tEyebrow().copyWith(fontSize: 8.5)),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _presets.length; i++) ...[
          _PresetCard(
            label: _presets[i].label,
            note: _presets[i].note,
            rooms: _presets[i].rooms,
            beds: _presets[i].beds,
            selected: roomCount == _presets[i].rooms &&
                defaultCap == _presets[i].beds,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _roomCountController.text = '${_presets[i].rooms}';
                _capacityController.text = '${_presets[i].beds}';
                _syncRoomControllers();
                _error = null;
              });
            },
          ),
          if (i != _presets.length - 1) const SizedBox(height: 8),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 18),
        TButton(
          text: 'Continue to rooms',
          icon: AppIcons.forward,
          onPressed: _goToStep2,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final totalBeds = _capacityControllers.fold<int>(
      0,
      (sum, c) => sum + (int.tryParse(c.text.trim()) ?? 3),
    );

    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CapacityHero(
          totalBeds: totalBeds,
          roomCount: _roomNumberControllers.length,
          bedsPerRoom: null,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text('Room number & beds', style: tSectionTitle())),
            Text(
              '${_roomNumberControllers.length} ROOMS',
              style: tEyebrow().copyWith(fontSize: 8.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _roomNumberControllers.length; i++) ...[
          _RoomEditorCard(
            index: i,
            roomController: _roomNumberControllers[i],
            capacity: _capacityControllers[i].text,
            onMinus: () => _adjustIntController(
              _capacityControllers[i],
              -1,
              min: 1,
              max: 20,
            ),
            onPlus: () => _adjustIntController(
              _capacityControllers[i],
              1,
              min: 1,
              max: 20,
            ),
          ),
          if (i != _roomNumberControllers.length - 1) const SizedBox(height: 8),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 18),
        TButton(
          text: 'Create boarding house',
          icon: AppIcons.checkLine,
          loading: _submitting,
          onPressed: _submitting ? null : _submitCreate,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _submitting
              ? null
              : () => setState(() {
                    _error = null;
                    _step = 1;
                  }),
          child: const Text('Back to details'),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final key = _createdHouse?.joinKey ?? 'GHBV-8X7K-2P9M';
    final houseName = _createdHouse?.name ?? _nameController.text.trim();
    final totalBeds = _capacityControllers.fold<int>(
      0,
      (sum, c) => sum + (int.tryParse(c.text.trim()) ?? 3),
    );

    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: LottieArt('check', size: 132)),
        const SizedBox(height: 4),
        Text(
          'Boarding house created',
          textAlign: TextAlign.center,
          style: tScreenTitle().copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          '$houseName is ready with ${_roomNumberControllers.length} rooms and $totalBeds beds.',
          textAlign: TextAlign.center,
          style: tMeta(color: kInkSoft),
        ),
        const SizedBox(height: 18),
        TCard(
          ambient: 'aurora',
          ambientOpacity: 0.18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: kHeroGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      AppIcons.homeLine,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(houseName,
                            style: tCardTitle().copyWith(fontSize: 17)),
                        if (_createdHouse?.domain.isNotEmpty == true)
                          Text(
                            '@${_createdHouse!.domain}',
                            style: tMeta(),
                          ),
                      ],
                    ),
                  ),
                  const TPill(text: 'LIVE', tone: TPillTone.ok),
                ],
              ),
              TKeyStrip(
                keyText: key,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: key));
                  showTSnack(
                    context,
                    'House key copied',
                    icon: AppIcons.keyLine,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TCard(
          ambient: 'drift',
          ambientOpacity: 0.12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What happens next', style: tCardTitle()),
              const SizedBox(height: 10),
              const _NextStep(
                icon: AppIcons.keyLine,
                title: 'Share the key',
                body: 'Send it to your tenants so they can join this house.',
              ),
              const _NextStep(
                icon: AppIcons.groupLine,
                title: 'Assign rooms',
                body: 'Link each tenant account to a room and bed.',
              ),
              const _NextStep(
                icon: AppIcons.walletLine,
                title: 'Track the rent',
                body: 'Mark payments and follow-ups from the dashboard.',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TButton(
          text: 'Open dashboard',
          icon: AppIcons.forward,
          onPressed: _finish,
        ),
      ],
    );
  }
}

// ==========================================================
// STEP INDICATOR
// ==========================================================

class _StepIndicator extends StatelessWidget {
  final int step;
  final VoidCallback? onBackToFirst;

  const _StepIndicator({required this.step, this.onBackToFirst});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StepCell(
            label: 'Details',
            number: 1,
            completed: step > 1,
            current: step == 1,
            onTap: onBackToFirst,
          ),
        ),
        Expanded(
          child: _StepCell(
            label: 'Rooms',
            number: 2,
            completed: step > 2,
            current: step == 2,
          ),
        ),
        Expanded(
          child: _StepCell(
            label: 'Ready',
            number: 3,
            completed: step >= 3,
            current: step == 3,
          ),
        ),
      ],
    );
  }
}

class _StepCell extends StatelessWidget {
  final String label;
  final int number;
  final bool completed;
  final bool current;
  final VoidCallback? onTap;

  const _StepCell({
    required this.label,
    required this.number,
    required this.completed,
    required this.current,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = completed || current;
    final cell = Column(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? kForest : Colors.white,
            border: Border.all(
              color: active ? kForest : kHairline,
              width: 1.3,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x260F7A44),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: completed
              ? const Icon(AppIcons.checkLine, size: 16, color: Colors.white)
              : Text(
                  '$number',
                  style: AppType.h3.copyWith(
                    color: active ? Colors.white : kInkMuted,
                    fontSize: 13,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption.copyWith(
            color: active ? AppColors.text : kInkMuted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
    if (onTap == null) return cell;
    return GestureDetector(onTap: onTap, child: cell);
  }
}

// ==========================================================
// HERO
// ==========================================================

class _CapacityHero extends StatelessWidget {
  final int totalBeds;
  final int roomCount;
  final int? bedsPerRoom;

  const _CapacityHero({
    required this.totalBeds,
    required this.roomCount,
    this.bedsPerRoom,
  });

  @override
  Widget build(BuildContext context) {
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
              size: 400,
              alignment: Alignment.bottomRight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL BEDS',
                        style: tEyebrow(color: kLime).copyWith(fontSize: 9),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalBeds',
                        style: AppType.display.copyWith(
                          color: Colors.white,
                          fontSize: 46,
                          height: 1,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bedsPerRoom == null
                            ? '$roomCount rooms, each with its own bed count'
                            : '$roomCount rooms × $bedsPerRoom beds',
                        style: AppType.body.copyWith(
                          color: kHeroMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 74,
                  height: 74,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const LottieArt('pulse', size: 52),
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
// STEPPER LINE
// ==========================================================

class _StepperLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _StepperLine({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TIconSquare(icon: icon, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tCardTitle().copyWith(fontSize: 14.5)),
              const SizedBox(height: 1),
              Text(hint, style: tMeta().copyWith(fontSize: 10.5)),
            ],
          ),
        ),
        _RoundStep(icon: AppIcons.removeLine, onTap: onMinus),
        SizedBox(
          width: 50,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: AppType.h2.copyWith(fontSize: 23),
          ),
        ),
        _RoundStep(icon: AppIcons.addLine, onTap: onPlus),
      ],
    );
  }
}

class _RoundStep extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundStep({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kMint,
            shape: BoxShape.circle,
            border: Border.all(color: kMintDeep),
          ),
          child: Icon(icon, size: 18, color: kPrimary),
        ),
      ),
    );
  }
}

// ==========================================================
// ROOM EDITOR
// ==========================================================

class _RoomEditorCard extends StatelessWidget {
  final int index;
  final TextEditingController roomController;
  final String capacity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _RoomEditorCard({
    required this.index,
    required this.roomController,
    required this.capacity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return TCard(
      padding: const EdgeInsets.all(12),
      ambient: index.isEven ? 'drift' : 'flow',
      ambientOpacity: 0.12,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: kHeroGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${index + 1}',
              style: AppType.h3.copyWith(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: 'Room',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MiniStepButton(icon: AppIcons.removeLine, onTap: onMinus),
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  capacity,
                  textAlign: TextAlign.center,
                  style: AppType.h2.copyWith(fontSize: 20),
                ),
                Text(
                  'beds',
                  textAlign: TextAlign.center,
                  style: tMeta().copyWith(fontSize: 8.5),
                ),
              ],
            ),
          ),
          _MiniStepButton(icon: AppIcons.addLine, onTap: onPlus),
        ],
      ),
    );
  }
}

class _MiniStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kMint,
          shape: BoxShape.circle,
          border: Border.all(color: kMintDeep),
        ),
        child: Icon(icon, size: 16, color: kPrimary),
      ),
    );
  }
}

// ==========================================================
// PRESET
// ==========================================================

class _PresetCard extends StatelessWidget {
  final String label;
  final String note;
  final int rooms;
  final int beds;
  final bool selected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.label,
    required this.note,
    required this.rooms,
    required this.beds,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kMint : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? kPrimary : kHairline,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: kCardShadow,
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
                AppIcons.roomLine,
                size: 20,
                color: selected ? kLime : kPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: tCardTitle().copyWith(fontSize: 14.5)),
                  const SizedBox(height: 1),
                  Text(note, style: tMeta().copyWith(fontSize: 10.5)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$rooms',
                  style: AppType.h2.copyWith(
                    fontSize: 20,
                    color: selected ? kPrimary : AppColors.text,
                  ),
                ),
                Text(
                  '$rooms rooms · $beds beds',
                  style: tMeta().copyWith(fontSize: 9),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
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
// MISC
// ==========================================================

class _NextStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool last;

  const _NextStep({
    required this.icon,
    required this.title,
    required this.body,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TIconSquare(icon: icon, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tLabel()),
                const SizedBox(height: 1),
                Text(body, style: tMeta().copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              message,
              style: AppType.caption.copyWith(
                color: kDanger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
