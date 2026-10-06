// lib/screens/drone/edit_drone_screen.dart
//
// Edit the details of a fleet drone. The drone itself (name, group) comes from
// the fleet list and cannot be renamed here; IN / OUT status and its date &
// time can only change through a Drone IN / OUT entry. Battery is not tracked.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/drone.dart';
import '../../services/drone_service.dart';

class EditDroneScreen extends StatefulWidget {
  final DroneService service;
  final Drone drone;
  const EditDroneScreen(
      {super.key, required this.service, required this.drone});

  @override
  State<EditDroneScreen> createState() => _EditDroneScreenState();
}

class _EditDroneScreenState extends State<EditDroneScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _uinCtrl;
  late final TextEditingController _gpsCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _notesCtrl;
  String? _linkType; // null | 'Analog' | 'Digital'
  DateTime? _maintenanceDue;
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
    final d = widget.drone;
    _uinCtrl = TextEditingController(text: d.uin ?? '');
    _gpsCtrl = TextEditingController(text: d.gps ?? '');
    _hoursCtrl = TextEditingController(text: d.flightHours.toString());
    _notesCtrl = TextEditingController(text: d.notes ?? '');
    _linkType = d.linkType;
    _maintenanceDue = d.maintenanceDue;
    _droneAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
  }

  @override
  void dispose() {
    _uinCtrl.dispose();
    _gpsCtrl.dispose();
    _hoursCtrl.dispose();
    _notesCtrl.dispose();
    _droneAnim.dispose();
    super.dispose();
  }

  Future<void> _pickMaintenanceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
      _maintenanceDue ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: kAmber,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _maintenanceDue = picked);
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final d = widget.drone;
    final updated = Drone(
      id: d.id,
      name: d.name,
      model: d.model,
      serialNumber: d.serialNumber,
      status: d.status, // unchanged — only IN / OUT entries change status
      uin: _nullIfEmpty(_uinCtrl.text),
      droneClass: d.droneClass,
      pilotName: d.pilotName,
      category: d.category,
      gps: _nullIfEmpty(_gpsCtrl.text),
      linkType: _linkType,
      inMasterList: d.inMasterList,
      hasMovement: d.hasMovement,
      additionalProducts: d.additionalProducts,
      condition: d.condition,
      flightHours: double.tryParse(_hoursCtrl.text.trim()) ?? d.flightHours,
      notes: _nullIfEmpty(_notesCtrl.text),
      maintenanceDue: _maintenanceDue,
      lastUpdated: d.lastUpdated,
      branch: d.branch,
      purpose: d.purpose,
      checkedOutAt: d.checkedOutAt,
      checkedInAt: d.checkedInAt,
      addedBy: d.addedBy,
      updatedBy: d.updatedBy,
      reminderAcknowledged: d.reminderAcknowledged,
    );

    final result = await widget.service.updateDrone(updated);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Drone updated successfully!',
                style: TextStyle(color: Colors.white)),
          ]),
          backgroundColor: kGreen,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context, true);
    } else {
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

  @override
  Widget build(BuildContext context) {
    final d = widget.drone;
    return Scaffold(
      backgroundColor: kSurface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildSectionHeader('Fleet Drone', Icons.flight_rounded),
                    const SizedBox(height: 12),
                    _buildReadOnly(d),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                        'Details', Icons.settings_input_antenna_rounded),
                    const SizedBox(height: 12),
                    _buildField(
                        controller: _uinCtrl,
                        label: 'UIN (if registered)',
                        hint: 'e.g. UIN-UB202502479TC',
                        icon: Icons.fingerprint),
                    const SizedBox(height: 14),
                    _buildField(
                        controller: _gpsCtrl,
                        label: 'GPS module',
                        hint: 'e.g. M10',
                        icon: Icons.gps_fixed_rounded),
                    const SizedBox(height: 14),
                    _buildLinkDropdown(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                        'Metrics', Icons.monitor_heart_outlined),
                    const SizedBox(height: 12),
                    _buildField(
                        controller: _hoursCtrl,
                        label: 'Flight Hours',
                        hint: '0.0',
                        icon: Icons.timer_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true)),
                    const SizedBox(height: 14),
                    _buildMaintenancePicker(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Notes', Icons.notes_outlined),
                    const SizedBox(height: 12),
                    _buildField(
                        controller: _notesCtrl,
                        label: 'Notes (optional)',
                        hint: 'Anything worth remembering',
                        icon: Icons.notes,
                        maxLines: 3),
                    const SizedBox(height: 28),
                    _buildSubmitButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                    child: const Icon(Icons.flight_rounded,
                        color: kTeal, size: 32),
                  ),
                );
              },
            ),
            Positioned(
              left: 20,
              bottom: 16,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Edit Drone',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2)),
                  const SizedBox(height: 4),
                  Text(widget.drone.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildReadOnly(Drone d) {
    final isIn = d.status == 'IN';
    final color = isIn ? kTeal : kAmber;
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(d.name,
                    style: const TextStyle(
                        color: kNavy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(d.status,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          if (d.category != null) ...[
            const SizedBox(height: 4),
            Text(d.category!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
          if (d.checkedOutAt != null || d.checkedInAt != null) ...[
            const SizedBox(height: 10),
            if (d.checkedOutAt != null)
              Text('Out: ${fmt.format(d.checkedOutAt!)}',
                  style: const TextStyle(
                      color: kCoral,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            if (d.checkedInAt != null)
              Text('In: ${fmt.format(d.checkedInAt!)}',
                  style: const TextStyle(
                      color: kGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Name, status and IN / OUT time change only through a Drone IN / OUT entry.',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkDropdown() {
    return Container(
      decoration: _cardDecoration,
      child: DropdownButtonFormField<String?>(
        value: _linkType,
        dropdownColor: Colors.white,
        style: const TextStyle(color: kNavy, fontSize: 15),
        decoration: InputDecoration(
          labelText: 'Video link',
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(Icons.podcasts_rounded,
              color: Colors.grey.shade500, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(right: 16),
        ),
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('Not specified')),
          DropdownMenuItem<String?>(value: 'Analog', child: Text('Analog')),
          DropdownMenuItem<String?>(value: 'Digital', child: Text('Digital')),
        ],
        onChanged: (v) => setState(() => _linkType = v),
      ),
    );
  }

  Widget _buildMaintenancePicker() {
    final has = _maintenanceDue != null;
    return InkWell(
      onTap: _pickMaintenanceDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: _cardDecoration,
        child: Row(
          children: [
            Icon(Icons.build_outlined,
                color: has ? kAmber : Colors.grey.shade500, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  has
                      ? 'Maintenance due: ${DateFormat('dd MMM yyyy').format(_maintenanceDue!)}'
                      : 'Maintenance due date (optional)',
                  style: TextStyle(
                      color: has ? kNavy : Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: has ? FontWeight.w700 : FontWeight.w500)),
            ),
            if (has)
              InkWell(
                onTap: () => setState(() => _maintenanceDue = null),
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded),
        label: Text(_saving ? 'Saving…' : 'Save Changes',
            style:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kTeal.withOpacity(0.4),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: _cardDecoration,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(color: kNavy, fontSize: 15),
        cursorColor: kTeal,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}