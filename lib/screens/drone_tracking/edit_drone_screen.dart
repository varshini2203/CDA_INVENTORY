// lib/screens/drone/edit_drone_screen.dart
// Firestore version — identical UI logic, theme matched to Invoice pages.

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/drone.dart';
import '../../services/drone_service.dart';
import '../../constants/drone_categories.dart';

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
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _pilotCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _notesCtrl;
  late String _status;
  late String _category;
  late String _branch;
  late double _battery;
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
    _nameCtrl = TextEditingController(text: d.name);
    _modelCtrl = TextEditingController(text: d.model);
    _serialCtrl = TextEditingController(text: d.serialNumber);
    _pilotCtrl = TextEditingController(text: d.pilotName ?? '');
    _hoursCtrl =
        TextEditingController(text: d.flightHours.toString());
    _notesCtrl = TextEditingController(text: d.notes ?? '');
    _status = d.status;
    _category =
    (d.category != null && kDroneCategories.contains(d.category))
        ? d.category!
        : kDroneCategories.first;
    _branch = (d.branch != null && kBranchOptions.contains(d.branch))
        ? d.branch!
        : kBranchOptions.first;
    _battery = d.batteryLevel.toDouble().clamp(0, 100);
    _maintenanceDue = d.maintenanceDue;

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
      initialDate: _maintenanceDue ??
          DateTime.now().add(const Duration(days: 30)),
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

  Color get _batteryColor {
    if (_battery <= 20) return kCoral;
    if (_battery <= 50) return kAmber;
    return kGreen;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = widget.drone.copyWith(
      name: _nameCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      serialNumber: _serialCtrl.text.trim(),
      status: _status,
      pilotName: _pilotCtrl.text.trim().isEmpty
          ? null
          : _pilotCtrl.text.trim(),
      category: _category,
      batteryLevel: _battery.round(),
      flightHours:
      double.tryParse(_hoursCtrl.text.trim()) ??
          widget.drone.flightHours,
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      maintenanceDue: _maintenanceDue,
      branch: _branch,
    );

    final result = await widget.service.updateDrone(updated);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Drone updated successfully!',
                style: TextStyle(color: Colors.white)),
          ]),
          backgroundColor: kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
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
                padding:
                const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // Firestore doc ID badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: kAmber.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kAmber.withOpacity(0.12),
                            borderRadius:
                            BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.fingerprint,
                              color: kAmber, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Doc ID: ${widget.drone.id}',
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kAmber.withOpacity(0.12),
                            borderRadius:
                            BorderRadius.circular(6),
                          ),
                          child: const Text('EDITING',
                              style: TextStyle(
                                  color: kAmber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                        'Identity', Icons.badge_outlined),
                    const SizedBox(height: 12),
                    _buildField(
                        controller: _nameCtrl,
                        label: 'Drone Name',
                        icon: Icons.airplanemode_active,
                        validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Drone name is required'
                            : null),
                    const SizedBox(height: 14),
                    _buildField(
                        controller: _modelCtrl,
                        label: 'Model',
                        icon: Icons.category_outlined,
                        validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Model is required'
                            : null),
                    const SizedBox(height: 14),
                    _buildField(
                        controller: _serialCtrl,
                        label: 'Serial Number',
                        icon: Icons.tag,
                        validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Serial number is required'
                            : null),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                        'Assignment', Icons.person_pin_outlined),
                    const SizedBox(height: 12),
                    _buildField(
                        controller: _pilotCtrl,
                        label: 'used by (optional)',
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
                        icon: Icons.timer_outlined,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true)),
                    const SizedBox(height: 14),
                    _buildBatterySlider(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                        'Schedule', Icons.event_outlined),
                    const SizedBox(height: 12),
                    _buildMaintenancePicker(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                        'purpose', Icons.notes_outlined),
                    const SizedBox(height: 12),
                    _buildField(
                        controller: _notesCtrl,
                        label: 'purpose (optional)',
                        hint: 'aim',
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
      expandedHeight: 140,
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
                final x =
                    0.72 + math.sin(t * 2 * math.pi) * 0.12;
                final y =
                    0.35 + math.cos(t * 2 * math.pi * 0.7) * 0.2;
                return Positioned(
                  right: MediaQuery.of(context).size.width * (1 - x),
                  top: 140 * y,
                  child: Opacity(
                    opacity: 0.22,
                    child: Transform.rotate(
                      angle: math.sin(t * 2 * math.pi) * 0.08,
                      child: const Icon(Icons.flight_rounded,
                          color: kAmber, size: 30),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 20,
              bottom: 16,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Edit · ${widget.drone.name}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(widget.drone.model,
                      style: TextStyle(
                          color: kAmber.withOpacity(0.85),
                          fontSize: 13),
                      overflow: TextOverflow.ellipsis),
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
            child:
            Container(height: 1, color: Colors.grey.shade200)),
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
          labelStyle:
          TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: const Icon(Icons.workspaces_outline,
              color: kAmber, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(right: 16),
        ),
        items: kDroneCategories
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) =>
            setState(() => _category = v ?? _category),
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
          labelStyle:
          TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: const Icon(Icons.location_city_outlined,
              color: kAmber, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(right: 16),
        ),
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
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _batteryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _batteryColor.withOpacity(0.3)),
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
                  ? kAmber.withOpacity(0.4)
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
                color: kAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.build_outlined,
                  color: kAmber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maintenance Date',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12)),
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
              Text('STATUS',
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
                  accentColor: kAmber,
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
                  accentColor: kAmber,
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
              color: kAmber.withOpacity(0.3),
              blurRadius: 18,
              spreadRadius: 0),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: kAmber,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kAmber.withOpacity(0.4),
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
              Icon(Icons.save_outlined, size: 20),
              SizedBox(width: 10),
              Text('Save Changes',
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
      cursorColor: kAmber,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
        TextStyle(color: Colors.grey.shade600, fontSize: 14),
        floatingLabelStyle:
        const TextStyle(color: kAmber, fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon:
        Icon(icon, color: kAmber, size: 20),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: kAmber, width: 1.5),
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

class _StatusOption extends StatelessWidget {
  final String label, description;
  final IconData icon;
  final Color color, accentColor;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption(
      {required this.label,
        required this.description,
        required this.icon,
        required this.color,
        required this.accentColor,
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