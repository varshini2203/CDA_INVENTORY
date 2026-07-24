// lib/screens/drone/add_drone_entry_screen.dart
// Firestore version — identical UI logic, theme matched to Invoice pages.

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/drone_service.dart';
import '../../models/drone.dart';
import '../../constants/drone_categories.dart';

class AddDroneEntryScreen extends StatefulWidget {
  final DroneService service;
  const AddDroneEntryScreen({super.key, required this.service});

  @override
  State<AddDroneEntryScreen> createState() => _AddDroneEntryScreenState();
}

class _AddDroneEntryScreenState extends State<AddDroneEntryScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _pilotCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  String _status = 'IN';
  String _category = kDroneCategories.first;
  // Raw value stored/filtered on ('Branch 1' / 'Branch 2'); dropdown shows
  // the friendly label ('CDA Admin' / 'CDA Ops').
  String _branch = kBranchOptions.first;
  double _battery = 100;
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
    _droneAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _pilotCtrl.dispose();
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
            primary: kTeal,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _maintenanceDue = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final drone = Drone(
      id: '', // Firestore will assign the real ID
      name: _nameCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      serialNumber: _serialCtrl.text.trim(),
      status: _status,
      pilotName: _pilotCtrl.text.trim().isEmpty
          ? null
          : _pilotCtrl.text.trim(),
      category: _category,
      batteryLevel: _battery.round(),
      flightHours: double.tryParse(_hoursCtrl.text.trim()) ?? 0,
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      maintenanceDue: _maintenanceDue,
      branch: _branch,
    );

    final result = await widget.service.addDrone(drone);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Drone registered successfully!',
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

  Color get _batteryColor {
    if (_battery <= 20) return kCoral;
    if (_battery <= 50) return kAmber;
    return kGreen;
  }

  @override
  Widget build(BuildContext context) {
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
                    _buildSectionHeader('Identity', Icons.badge_outlined),
                    const SizedBox(height: 12),
                    _buildField(
                        controller: _nameCtrl,
                        label: 'Drone Name',
                        hint: 'e.g. Alpha-01',
                        icon: Icons.airplanemode_active,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Drone name is required'
                            : null),
                    const SizedBox(height: 14),
                    _buildField(
                        controller: _modelCtrl,
                        label: 'Model',
                        hint: 'e.g. DJI Phantom 4',
                        icon: Icons.category_outlined,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Model is required'
                            : null),
                    const SizedBox(height: 14),
                    _buildField(
                        controller: _serialCtrl,
                        label: 'Serial Number',
                        hint: 'e.g. SN-2024-001',
                        icon: Icons.tag,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Serial number is required'
                            : null),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                        'Assignment', Icons.person_pin_outlined),
                    const SizedBox(height: 12),
                    _buildField(
                        controller: _pilotCtrl,
                        label: 'Pilot Name (optional)',
                        hint: 'e.g. Name',
                        icon: Icons.person_outline),
                    const SizedBox(height: 14),
                    _buildCategoryDropdown(),
                    const SizedBox(height: 14),
                    _buildBranchDropdown(),
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
                    _buildBatterySlider(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Schedule', Icons.event_outlined),
                    const SizedBox(height: 12),
                    _buildMaintenancePicker(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Notes', Icons.notes_outlined),
                    const SizedBox(height: 12),
                    _buildField(
                        controller: _notesCtrl,
                        label: 'Notes (optional)',
                        hint: 'Any additional info…',
                        icon: Icons.notes,
                        maxLines: 3),
                    const SizedBox(height: 24),
                    _buildStatusSelector(),
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
                  const Text('Register New Drone',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2)),
                  const SizedBox(height: 4),
                  Text('Add a drone to the fleet',
                      style: TextStyle(
                          color: kTeal.withOpacity(0.85),
                          fontSize: 13)),
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
        Expanded(
            child: Container(height: 1, color: Colors.grey.shade200)),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _category,
        dropdownColor: Colors.white,
        style: const TextStyle(color: kNavy, fontSize: 15),
        decoration: InputDecoration(
          labelText: 'Category',
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: const Icon(Icons.workspaces_outline,
              color: kTeal, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(right: 16),
        ),
        items: kDroneCategories
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => setState(() => _category = v ?? _category),
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _branch,
        dropdownColor: Colors.white,
        style: const TextStyle(color: kNavy, fontSize: 15),
        decoration: InputDecoration(
          labelText: 'Branch',
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: const Icon(Icons.location_city_outlined,
              color: kTeal, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(right: 16),
        ),
        // Show the friendly label ('CDA Admin' / 'CDA Ops') while the value
        // stored/filtered on is the raw 'Branch 1' / 'Branch 2'.
        items: kBranchOptions
            .map((b) => DropdownMenuItem(
            value: b, child: Text(kBranchLabels[b] ?? b)))
            .toList(),
        onChanged: (v) => setState(() => _branch = v ?? _branch),
      ),
    );
  }

  Widget _buildBatterySlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.battery_charging_full,
                  color: _batteryColor, size: 18),
              const SizedBox(width: 8),
              Text('Battery Level',
                  style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _batteryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                  Border.all(color: _batteryColor.withOpacity(0.3)),
                ),
                child: Text('${_battery.round()}%',
                    style: TextStyle(
                        color: _batteryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _battery / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(_batteryColor),
              minHeight: 4,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: _batteryColor,
              overlayColor: _batteryColor.withOpacity(0.15),
              trackHeight: 0,
            ),
            child: Slider(
              value: _battery,
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (v) => setState(() => _battery = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenancePicker() {
    return InkWell(
      onTap: _pickMaintenanceDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _maintenanceDue != null
                  ? kTeal.withOpacity(0.4)
                  : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.build_outlined,
                  color: kTeal, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maintenance Date',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    _maintenanceDue == null
                        ? 'Tap to set (optional)'
                        : _maintenanceDue!
                        .toLocal()
                        .toString()
                        .split(' ')
                        .first,
                    style: TextStyle(
                        color: _maintenanceDue == null
                            ? Colors.grey.shade400
                            : kNavy,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (_maintenanceDue != null)
              GestureDetector(
                onTap: () =>
                    setState(() => _maintenanceDue = null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.close,
                      color: Colors.grey.shade600, size: 14),
                ),
              )
            else
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.toggle_on_outlined,
                  color: kNavy, size: 16),
              SizedBox(width: 8),
              Text('INITIAL STATUS',
                  style: TextStyle(
                      color: kNavy,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatusOption(
                  label: 'IN',
                  icon: Icons.flight_land,
                  color: kTeal,
                  description: 'In the hangar',
                  selected: _status == 'IN',
                  onTap: () => setState(() => _status = 'IN'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatusOption(
                  label: 'OUT',
                  icon: Icons.flight_takeoff,
                  color: kAmber,
                  description: 'On a mission',
                  selected: _status == 'OUT',
                  onTap: () => setState(() => _status = 'OUT'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _saving
            ? []
            : [
          BoxShadow(
              color: kTeal.withOpacity(0.3),
              blurRadius: 18,
              spreadRadius: 0),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: kTeal,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kTeal.withOpacity(0.4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 20),
              SizedBox(width: 10),
              Text('Register Drone',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: kNavy, fontSize: 15),
      cursorColor: kTeal,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
        TextStyle(color: Colors.grey.shade600, fontSize: 14),
        floatingLabelStyle:
        const TextStyle(color: kTeal, fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: kTeal, size: 20),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: kTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: kCoral, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: kCoral, width: 1.5),
        ),
        errorStyle: const TextStyle(color: kCoral),
      ),
    );
  }
}

// ── Status Option ─────────────────────────────────────────────────────────────

class _StatusOption extends StatelessWidget {
  final String label, description;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption(
      {required this.label,
        required this.description,
        required this.icon,
        required this.color,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : const Color(0xFFF7F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? color.withOpacity(0.5)
                  : Colors.grey.shade200,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                color:
                selected ? color : Colors.grey.shade400,
                size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? color
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(description,
                style: TextStyle(
                    color: selected
                        ? color.withOpacity(0.7)
                        : Colors.grey.shade400,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SubtleGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.5;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}