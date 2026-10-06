// lib/screens/drone/add_drone_entry_screen.dart
//
// Drone IN / OUT entry.
//   • The drone is chosen from a dropdown built from the fleet list
//     (DRONE_LIST.xlsx → data/seed_drones.dart). No drone is ever typed.
//   • UIN, GPS and Analog / Digital are shown automatically for the chosen
//     drone (only the ones that exist for it).
//   • The action is derived from the drone's current status:
//       drone is IN  → this entry sends it OUT
//       drone is OUT → this entry brings it IN
//   • Date & time are taken automatically (server clock) when the entry is
//     confirmed — there is no date / time picker.
//   • "Handled by" is the logged-in user — never typed.
//   • Additional products work exactly as before. Battery is not recorded.

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/drone_categories.dart';
import '../../data/seed_drones.dart';
import '../../models/drone.dart';
import '../../services/current_user_service.dart';
import '../../services/drone_reminder_service.dart';
import '../../services/drone_service.dart';

// ── Additional-products & condition option lists ──────────────────────────
const List<String> kAdditionalDroneProducts = [
  'Extra Battery',
  'Propellers Set',
  'Charger',
  'Remote Controller (Master)',
  'Remote Controller (Slave)',
  'Carrying Case',
  'Camera Gimbal',
  'Landing Gear',
  'Memory Card',
  'ND Filters',
  'FPV Goggles',
  'Monitor',
  'Anemometer',
  'LiPo Checker',
  'GPS Module',
  'VTX (Video Transmitter)',
  'Signal Booster / Range Extender',
  'Drone Backpack / Hard Case',
  'Digital Thermometer',
];

const List<String> kDroneConditions = ['Good', 'Damaged'];

const List<String> kDamageFixSuggestions = [
  'Replace propeller',
  'Recalibrate gimbal',
  'Repair frame/body',
  'Replace battery',
  'Fix motor',
  'Send for service',
];

class AddDroneEntryScreen extends StatefulWidget {
  final DroneService service;

  /// Pre-selects a drone (used by the "Send OUT / Bring IN" button on a card).
  final String? initialDroneId;

  const AddDroneEntryScreen({
    super.key,
    required this.service,
    this.initialDroneId,
  });

  @override
  State<AddDroneEntryScreen> createState() => _AddDroneEntryScreenState();
}

class _AddDroneEntryScreenState extends State<AddDroneEntryScreen>
    with SingleTickerProviderStateMixin {
  final _notesCtrl = TextEditingController();
  final _customProductCtrl = TextEditingController();
  final _fixSuggestionCtrl = TextEditingController();

  List<Drone> _drones = [];
  // Fleet-list drones that have no Firestore document yet (e.g. it was deleted).
  // They are still shown in the dropdown and are restored on first use.
  final Set<String> _virtualIds = {};
  bool _submitted = false; // set once a movement is saved — blocks repeats
  bool _loading = true;
  String? _error;

  String? _selectedId;
  String? _purpose;
  String _condition = kDroneConditions.first;
  final Set<String> _selectedProducts = {};
  final List<String> _customProducts = [];

  String _handledBy = CurrentUserService.nameSync;
  DateTime _now = DateTime.now();
  Timer? _clock;
  bool _saving = false;

  late AnimationController _droneAnim;

  // ── Design tokens (matches Invoice pages) ──────────────────────────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kNavyLight = Color(0xFF162944);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kPurple = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _droneAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
    // Live clock — display only. The saved time is the server time at confirm.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    CurrentUserService.getName().then((n) {
      if (mounted) setState(() => _handledBy = n);
    });
    _loadDrones();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _notesCtrl.dispose();
    _customProductCtrl.dispose();
    _fixSuggestionCtrl.dispose();
    _droneAnim.dispose();
    super.dispose();
  }

  Future<void> _loadDrones() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.service.getDrones(forceRefresh: true);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error;
      });
      return;
    }
    // Always show the WHOLE fleet list (DRONE_LIST.xlsx). A fleet drone with no
    // Firestore document is added as a placeholder and created when first used.
    final byKey = <String, Drone>{
      for (final d in result.data!) droneNameKey(d.name): d,
    };
    final list = <Drone>[];
    _virtualIds.clear();
    for (final e in kDroneMasterList) {
      final existing = byKey[e.key];
      if (existing != null) {
        list.add(existing);
      } else {
        _virtualIds.add(e.docId);
        list.add(Drone(
          id: e.docId,
          name: e.name,
          model: '',
          serialNumber: '',
          status: 'IN',
          uin: e.uin,
          gps: e.gps,
          linkType: e.linkType,
          category: e.group,
          inMasterList: true,
        ));
      }
    }
    // Keep the order of the fleet list: group by group, row by row.
    int rank(Drone d) {
      final i = kDroneMasterList.indexWhere((e) => e.key == droneNameKey(d.name));
      return i < 0 ? kDroneMasterList.length : i;
    }
    list.sort((a, b) => rank(a).compareTo(rank(b)));
    setState(() {
      _loading = false;
      _drones = list;
    });
    if (widget.initialDroneId != null &&
        list.any((d) => d.id == widget.initialDroneId)) {
      _selectDrone(widget.initialDroneId);
    }
  }

  int _groupRank(String? g) {
    final i = kDroneGroups.indexOf(g ?? '');
    return i < 0 ? kDroneGroups.length : i;
  }

  Drone? get _selected {
    for (final d in _drones) {
      if (d.id == _selectedId) return d;
    }
    return null;
  }

  /// The status this entry will set — always the opposite of the current one.
  String? get _nextStatus {
    final d = _selected;
    if (d == null) return null;
    return d.status == 'IN' ? 'OUT' : 'IN';
  }

  void _selectDrone(String? id) {
    if (id == null || id.startsWith('__')) return;
    final d = _drones.firstWhere((x) => x.id == id);
    setState(() {
      _selectedId = id;
      _purpose = d.status == 'IN' ? kDronePurposes.first : null;
      _selectedProducts
        ..clear()
      // Coming back IN: tick what went out so it can be checked off.
        ..addAll(d.status == 'OUT' ? d.additionalProducts : const []);
      for (final p in d.additionalProducts) {
        if (!kAdditionalDroneProducts.contains(p) &&
            !_customProducts.contains(p)) {
          _customProducts.add(p);
        }
      }
      _condition = kDroneConditions.first;
      _fixSuggestionCtrl.clear();
    });
  }

  void _addCustomProduct() {
    final text = _customProductCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_customProducts.contains(text) &&
          !kAdditionalDroneProducts.contains(text)) {
        _customProducts.add(text);
      }
      _selectedProducts.add(text);
      _customProductCtrl.clear();
    });
  }

  void _appendFixSuggestion(String suggestion) {
    final current = _fixSuggestionCtrl.text.trim();
    if (current.isEmpty) {
      _fixSuggestionCtrl.text = suggestion;
    } else if (!current.contains(suggestion)) {
      _fixSuggestionCtrl.text = '$current, $suggestion';
    }
    _fixSuggestionCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _fixSuggestionCtrl.text.length),
    );
  }

  bool get _canSubmit {
    if (_saving || _selected == null) return false;
    if (_nextStatus == 'OUT' && (_purpose == null || _purpose!.isEmpty)) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    final drone = _selected;
    final next = _nextStatus;
    if (drone == null || next == null || !_canSubmit) return;
    if (_submitted) return; // one tap = one movement, never repeated
    // Explicit confirmation — a stray tap can never record an IN / OUT.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark ${drone.name} $next?'),
        content: Text(next == 'OUT'
            ? 'This starts a NEW OUT record for this drone.'
            : 'This closes the current record. It cannot be edited afterwards.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Confirm $next')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _submitted = true;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final products = _selectedProducts.toList();
    final noteParts = <String>[
      if (_notesCtrl.text.trim().isNotEmpty) _notesCtrl.text.trim(),
      if (products.isNotEmpty) 'Accessories: ${products.join(', ')}',
      'Condition: $_condition',
      if (_condition == 'Damaged' && _fixSuggestionCtrl.text.trim().isNotEmpty)
        'Suggested fix: ${_fixSuggestionCtrl.text.trim()}',
    ];

    // Restore a fleet drone whose document is missing, then use its real id.
    var droneId = drone.id;
    if (_virtualIds.contains(droneId)) {
      try {
        await seedDrones(FirebaseFirestore.instance);
        DroneService.clearCache();
        final fresh = await widget.service.getDrones(forceRefresh: true);
        final match = (fresh.data ?? const <Drone>[])
            .where((d) => droneNameKey(d.name) == droneNameKey(drone.name));
        if (match.isNotEmpty) droneId = match.first.id;
      } catch (_) {}
    }

    final result = await widget.service.updateStatus(
      droneId,
      next,
      note: noteParts.join('\n'),
      purpose: next == 'OUT' ? _purpose : null,
      additionalProducts: products,
      condition: _condition,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      DroneReminderService.instance.scheduleReminder(
        droneId: droneId,
        droneName: drone.name,
        newStatus: next,
        actionTime: DateTime.now(),
        purpose: next == 'OUT' ? _purpose : null,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(next == 'IN' ? Icons.flight_land : Icons.flight_takeoff,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text('${drone.name} marked $next — handled by $_handledBy',
                  style: const TextStyle(color: Colors.white)),
            ),
          ]),
          backgroundColor: next == 'IN' ? kTeal : kAmber,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context, true);
    } else {
      _submitted = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result.error}',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: kCoral,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Color get _conditionColor => _condition == 'Damaged' ? kCoral : kGreen;

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator(color: kTeal)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: kCoral, size: 44),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDrones,
              style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_drones.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.flight_rounded, color: Colors.grey.shade300, size: 52),
            const SizedBox(height: 12),
            const Text('Drone list is empty',
                style: TextStyle(
                    color: kNavy, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Load the fleet list from the Drone IN / OUT page first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    final drone = _selected;
    final next = _nextStatus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _buildSectionHeader('Select Drone', Icons.flight_rounded),
          const SizedBox(height: 12),
          _buildDroneDropdown(),
          if (drone != null) ...[
            const SizedBox(height: 14),
            _buildDroneDetails(drone),
            const SizedBox(height: 14),
            _buildActionBanner(drone, next!),
          ],
          const SizedBox(height: 24),
          _buildSectionHeader('Auto Recorded', Icons.verified_user_outlined),
          const SizedBox(height: 12),
          _buildAutoCard(next),
          if (drone != null) ...[
            if (next == 'OUT') ...[
              const SizedBox(height: 24),
              _buildSectionHeader('Purpose', Icons.flag_outlined),
              const SizedBox(height: 12),
              _buildPurposeDropdown(),
            ],
            const SizedBox(height: 24),
            _buildSectionHeader(
                'Additional Products', Icons.inventory_2_outlined),
            const SizedBox(height: 12),
            _buildAdditionalProductsPicker(),
            const SizedBox(height: 24),
            _buildSectionHeader(
                'Condition', Icons.health_and_safety_outlined),
            const SizedBox(height: 12),
            _buildConditionSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Remarks', Icons.notes_outlined),
            const SizedBox(height: 12),
            _buildRemarksField(),
            const SizedBox(height: 28),
            _buildSubmitButton(next!),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: kNavy,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kNavy, kNavyLight],
                ),
              ),
              child: CustomPaint(painter: _SubtleGridPainter()),
            ),
            AnimatedBuilder(
              animation: _droneAnim,
              builder: (_, __) {
                final t = _droneAnim.value;
                final x = 0.7 + math.sin(t * 2 * math.pi) * 0.15;
                final y = 0.4 + math.cos(t * 2 * math.pi * 0.6) * 0.25;
                return Positioned(
                  right: MediaQuery.of(context).size.width * (1 - x),
                  top: 130 * y,
                  child: Opacity(
                    opacity: 0.25,
                    child: Transform.rotate(
                      angle: math.sin(t * 2 * math.pi) * 0.1,
                      child: const Icon(Icons.flight_rounded,
                          color: kTeal, size: 32),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 20,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Drone IN / OUT Entry',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2)),
                  const SizedBox(height: 4),
                  Text('Pick a drone from the fleet list',
                      style: TextStyle(
                          color: kTeal.withOpacity(0.85), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kNavy, size: 16),
        const SizedBox(width: 8),
        Text(title.toUpperCase(),
            style: const TextStyle(
                color: kNavy,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
      ],
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2)),
    ],
  );

  // ── Drone dropdown (grouped, from the fleet list) ──────────────────────────

  Widget _buildDroneDropdown() {
    final items = <DropdownMenuItem<String>>[];
    final selectedBuilders = <Widget>[];
    String? lastGroup;

    for (final d in _drones) {
      final group = d.category ?? 'Other';
      if (group != lastGroup) {
        lastGroup = group;
        items.add(DropdownMenuItem<String>(
          value: '__group_$group',
          enabled: false,
          child: Text(group.toUpperCase(),
              style: const TextStyle(
                  color: kPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6)),
        ));
        selectedBuilders.add(const SizedBox.shrink());
      }
      final isOut = d.status == 'OUT';
      items.add(DropdownMenuItem<String>(
        value: d.id,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: isOut ? kAmber : kTeal, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(d.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: kNavy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(d.status,
                style: TextStyle(
                    color: isOut ? kAmber : kTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ));
      selectedBuilders.add(Text(d.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: kNavy, fontSize: 14, fontWeight: FontWeight.w700)));
    }

    return Container(
      decoration: _cardDecoration,
      child: DropdownButtonFormField<String>(
        value: _selectedId,
        isExpanded: true,
        menuMaxHeight: 420,
        dropdownColor: Colors.white,
        hint: Text('Choose a drone',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        decoration: InputDecoration(
          labelText: 'Drone',
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: const Icon(Icons.airplanemode_active,
              color: kTeal, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(right: 12),
        ),
        selectedItemBuilder: (_) => selectedBuilders,
        items: items,
        onChanged: _selectDrone,
      ),
    );
  }

  // ── Auto-listed details for the chosen drone ───────────────────────────────

  Widget _buildDroneDetails(Drone d) {
    final tiles = <Widget>[
      if (d.category != null)
        _InfoTile(
            icon: Icons.category_outlined,
            label: 'TYPE',
            value: d.category!,
            color: kNavy),
      if (d.uin != null)
        _InfoTile(
            icon: Icons.fingerprint,
            label: 'UIN',
            value: d.uin!,
            color: kPurple),
      if (d.gps != null)
        _InfoTile(
            icon: Icons.gps_fixed_rounded,
            label: 'GPS',
            value: d.gps!,
            color: kGreen),
      if (d.linkType != null)
        _InfoTile(
            icon: d.linkType == 'Digital'
                ? Icons.settings_input_antenna_rounded
                : Icons.podcasts_rounded,
            label: 'VIDEO LINK',
            value: d.linkType!,
            color: d.linkType == 'Digital' ? kTeal : kAmber),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: kNavy, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(d.name,
                    style: const TextStyle(
                        color: kNavy,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tiles.isEmpty)
            Text('No UIN, GPS or Analog / Digital details on record.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5))
          else
            Wrap(spacing: 8, runSpacing: 8, children: tiles),
        ],
      ),
    );
  }

  Widget _buildActionBanner(Drone d, String next) {
    final color = next == 'OUT' ? kAmber : kTeal;
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    final since = d.status == 'OUT' ? d.checkedOutAt : d.checkedInAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(next == 'OUT' ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded,
              color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(next == 'OUT' ? 'This entry sends the drone OUT' : 'This entry brings the drone IN',
                    style: TextStyle(
                        color: color,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  'Currently ${d.status}'
                      '${since != null ? ' since ${fmt.format(since)}' : ''}'
                      '${d.status == 'OUT' && (d.pilotName ?? '').isNotEmpty ? ' · with ${d.pilotName}' : ''}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Handled by + date/time (automatic, read-only) ──────────────────────────

  Widget _buildAutoCard(String? next) {
    final label = next == 'OUT'
        ? 'OUT time'
        : next == 'IN'
        ? 'IN time'
        : 'Date & time';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        children: [
          _autoRow(Icons.person_outline_rounded, 'Handled by', _handledBy),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 12),
          _autoRow(Icons.calendar_today_outlined, 'Date',
              DateFormat('EEE, dd MMM yyyy').format(_now)),
          const SizedBox(height: 12),
          _autoRow(Icons.access_time_rounded, label,
              DateFormat('hh:mm:ss a').format(_now)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Name and time are set automatically when you confirm. They cannot be edited.',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _autoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: kTeal),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: kNavy, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ── Purpose ────────────────────────────────────────────────────────────────

  Widget _buildPurposeDropdown() {
    return Container(
      decoration: _cardDecoration,
      child: DropdownButtonFormField<String>(
        value: _purpose,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: const TextStyle(color: kNavy, fontSize: 15),
        decoration: InputDecoration(
          labelText: 'Purpose',
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(Icons.flag_outlined,
              color: Colors.grey.shade500, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(right: 16),
        ),
        items: kDronePurposes
            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
            .toList(),
        onChanged: (v) => setState(() => _purpose = v),
      ),
    );
  }

  // ── Additional products (same list & behaviour as before) ──────────────────

  Widget _buildAdditionalProductsPicker() {
    final allOptions = [
      ...kAdditionalDroneProducts,
      ..._customProducts.where((p) => !kAdditionalDroneProducts.contains(p)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rtl_outlined,
                  color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 8),
              Text('Included accessories (optional)',
                  style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allOptions.map((product) {
              final selected = _selectedProducts.contains(product);
              return FilterChip(
                label: Text(product),
                selected: selected,
                showCheckmark: false,
                labelStyle: TextStyle(
                    color: selected ? kTeal : Colors.grey.shade600,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5),
                backgroundColor: const Color(0xFFF7F9FB),
                selectedColor: kTeal.withOpacity(0.12),
                side: BorderSide(
                    color: selected
                        ? kTeal.withOpacity(0.5)
                        : Colors.grey.shade200),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedProducts.add(product);
                  } else {
                    _selectedProducts.remove(product);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customProductCtrl,
                  style: const TextStyle(color: kNavy, fontSize: 14),
                  onSubmitted: (_) => _addCustomProduct(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Add another product…',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: const Color(0xFFF7F9FB),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kTeal, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _addCustomProduct,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kTeal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          if (_selectedProducts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${_selectedProducts.length} item${_selectedProducts.length == 1 ? '' : 's'} selected',
              style: const TextStyle(
                  color: kTeal, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  // ── Condition ──────────────────────────────────────────────────────────────

  Widget _buildConditionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _condition == 'Damaged'
                    ? kCoral.withOpacity(0.4)
                    : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _condition,
            dropdownColor: Colors.white,
            style: const TextStyle(color: kNavy, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Condition',
              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              prefixIcon: Icon(
                  _condition == 'Damaged'
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: _conditionColor,
                  size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.only(right: 16),
            ),
            items: kDroneConditions
                .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c,
                    style: TextStyle(
                        color: c == 'Damaged' ? kCoral : kGreen,
                        fontWeight: FontWeight.w600))))
                .toList(),
            onChanged: (v) => setState(() => _condition = v ?? _condition),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _condition != 'Damaged'
              ? const SizedBox.shrink()
              : Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCoral.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kCoral.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build_circle_outlined,
                          color: kCoral, size: 16),
                      const SizedBox(width: 8),
                      Text('Suggested fix',
                          style: TextStyle(
                              color: kCoral.withOpacity(0.9),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kDamageFixSuggestions.map((s) {
                      return InkWell(
                        onTap: () =>
                            setState(() => _appendFixSuggestion(s)),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border:
                            Border.all(color: kCoral.withOpacity(0.3)),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  color: kCoral,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fixSuggestionCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: kNavy, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                      'e.g. Replace bent propeller, recalibrate gimbal',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                        BorderSide(color: kCoral.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                        BorderSide(color: kCoral.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                        const BorderSide(color: kCoral, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Remarks ────────────────────────────────────────────────────────────────

  Widget _buildRemarksField() {
    return Container(
      decoration: _cardDecoration,
      child: TextField(
        controller: _notesCtrl,
        maxLines: 3,
        style: const TextStyle(color: kNavy, fontSize: 15),
        decoration: InputDecoration(
          labelText: 'Remarks (optional)',
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon:
          Icon(Icons.notes, color: Colors.grey.shade500, size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Widget _buildSubmitButton(String next) {
    final color = next == 'OUT' ? kAmber : kTeal;
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _canSubmit ? _save : null,
        icon: _saving
            ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : Icon(next == 'OUT'
            ? Icons.flight_takeoff_rounded
            : Icons.flight_land_rounded),
        label: Text(_saving ? 'Saving…' : 'Confirm $next',
            style:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.35),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ── Small detail chip used in the drone details card ─────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtleGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D4AA).withOpacity(0.05)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}