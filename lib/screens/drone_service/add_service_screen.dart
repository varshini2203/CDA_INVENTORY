// lib/screens/drone_service/add_service_screen.dart
//
// Add (or edit, when `existing` is passed) a Drone Service booking.
// Theme matched to add_drone_entry_screen.dart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drone.dart';
import '../../models/drone_service_record.dart';
import '../../services/drone_service.dart';
import '../../services/drone_service_booking_service.dart';
import '../../constants/drone_categories.dart';
import '../../constants/drone_service_options.dart';
import '../../core/access/access_scope.dart';

class AddServiceScreen extends StatefulWidget {
  final DroneServiceRecord? existing;
  const AddServiceScreen({super.key, this.existing});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _droneNameCtrl = TextEditingController();
  final _technicianCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  final _bookingService = DroneServiceBookingService();
  final _droneService = DroneService();

  String _serviceType = kServiceTypes.first;
  String _branch = kBranchOptions.first;
  String _priority = kServicePriorities[1]; // 'Normal'
  DateTime? _scheduledAt;
  String? _linkedDroneId;
  bool _saving = false;

  List<Drone> _fleet = [];
  bool _fleetLoading = true;

  // ── Design tokens (matches Invoice / Drone In-Out pages) ────────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen = Color(0xFF00B894);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _droneNameCtrl.text = e.droneName;
      _technicianCtrl.text = e.technician;
      _notesCtrl.text = e.notes ?? '';
      _costCtrl.text = e.cost?.toString() ?? '';
      _serviceType = e.serviceType;
      _branch = e.branch;
      _priority = e.priority;
      _scheduledAt = e.scheduledAt;
      _linkedDroneId = e.droneId;
    }
    _loadFleet();
  }

  Future<void> _loadFleet() async {
    final result = await _droneService.getDrones();
    if (!mounted) return;
    setState(() {
      _fleetLoading = false;
      if (result.success) _fleet = result.data!;
    });
  }

  @override
  void dispose() {
    _droneNameCtrl.dispose();
    _technicianCtrl.dispose();
    _notesCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!requireEditAccess(context)) return;
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledAt == null) {
      _showSnack('Please pick a scheduled date & time', isError: true);
      return;
    }
    setState(() => _saving = true);

    final currentUserName = context.read<CurrentAccess>().access?.name;
    final record = DroneServiceRecord(
      id: widget.existing?.id ?? '',
      droneName: _droneNameCtrl.text.trim(),
      droneId: _linkedDroneId,
      serviceType: _serviceType,
      branch: _branch,
      status: widget.existing?.status ?? 'Scheduled',
      priority: _priority,
      scheduledAt: _scheduledAt!,
      completedAt: widget.existing?.completedAt,
      technician: _technicianCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      cost: double.tryParse(_costCtrl.text.trim()),
      createdBy: widget.existing?.createdBy ?? currentUserName,
    );

    final result = _isEdit
        ? await _bookingService.updateService(widget.existing!, record)
        : await _bookingService.addService(record);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      _showSnack(_isEdit ? 'Service updated' : 'Service scheduled', color: kGreen);
      Navigator.pop(context, true);
    } else {
      _showSnack('Error: ${result.error}', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false, Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? kCoral : (color ?? kTeal),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: Text(_isEdit ? 'Edit Service' : 'Add Service',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _sectionHeader('Drone / Asset', Icons.airplanemode_active_rounded),
            const SizedBox(height: 12),
            _fleetLoading
                ? const LinearProgressIndicator(color: kTeal)
                : _buildDroneField(),
            const SizedBox(height: 14),
            _field(
              controller: _droneNameCtrl,
              label: 'Drone / Asset Name',
              hint: 'e.g. Alpha-01 or "Battery Bank A"',
              icon: Icons.badge_outlined,
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 24),
            _sectionHeader('Service Details', Icons.build_circle_outlined),
            const SizedBox(height: 12),
            _buildServiceTypeDropdown(),
            const SizedBox(height: 14),
            _buildBranchDropdown(),
            const SizedBox(height: 14),
            _buildPrioritySelector(),
            const SizedBox(height: 24),
            _sectionHeader('Schedule', Icons.event_outlined),
            const SizedBox(height: 12),
            _DateTimePickerField(
              label: 'Scheduled Date & Time',
              value: _scheduledAt,
              accent: kTeal,
              onChanged: (dt) => setState(() => _scheduledAt = dt),
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            ),
            const SizedBox(height: 24),
            _sectionHeader('Assignment', Icons.person_pin_outlined),
            const SizedBox(height: 12),
            _field(
              controller: _technicianCtrl,
              label: 'Technician / Assigned To',
              hint: 'e.g. Ramesh Kumar',
              icon: Icons.engineering_outlined,
              validator: (v) => v == null || v.trim().isEmpty ? 'Technician is required' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _costCtrl,
              label: 'Estimated Cost (optional)',
              hint: '0.00',
              icon: Icons.currency_rupee_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 14),
            _field(
              controller: _notesCtrl,
              label: 'Notes (optional)',
              hint: 'Any additional details…',
              icon: Icons.notes_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDroneField() {
    if (_fleet.isEmpty) {
      return Text('No registered drones found — you can still type a name below.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
    }
    return DropdownButtonFormField<String>(
      value: _linkedDroneId,
      style: const TextStyle(color: kNavy, fontSize: 15),
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: 'Link to registered drone (optional)',
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: const Icon(Icons.flight_rounded, color: kTeal, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kTeal, width: 1.5)),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('None — manual entry')),
        for (final d in _fleet)
          DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.serialNumber})', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) {
        setState(() {
          _linkedDroneId = v;
          if (v != null) {
            final d = _fleet.firstWhere((e) => e.id == v);
            _droneNameCtrl.text = d.name;
            if (d.branch != null && kBranchOptions.contains(d.branch)) _branch = d.branch!;
          }
        });
      },
    );
  }

  Widget _buildServiceTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _serviceType,
      style: const TextStyle(color: kNavy, fontSize: 15),
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
      dropdownColor: Colors.white,
      decoration: _dropdownDecoration('Service Type', Icons.miscellaneous_services_rounded),
      items: kServiceTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (v) => setState(() => _serviceType = v ?? _serviceType),
    );
  }

  Widget _buildBranchDropdown() {
    return DropdownButtonFormField<String>(
      value: kBranchOptions.contains(_branch) ? _branch : kBranchOptions.first,
      style: const TextStyle(color: kNavy, fontSize: 15),
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
      dropdownColor: Colors.white,
      decoration: _dropdownDecoration('Branch', Icons.apartment_outlined),
      items: kBranchOptions.map((b) => DropdownMenuItem(value: b, child: Text(kBranchLabels[b] ?? b))).toList(),
      onChanged: (v) => setState(() => _branch = v ?? _branch),
    );
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
    prefixIcon: Icon(icon, color: kTeal, size: 20),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kTeal, width: 1.5)),
  );

  Widget _buildPrioritySelector() {
    Color colorFor(String p) {
      switch (p) {
        case 'Low': return kGreen;
        case 'High': return kAmber;
        case 'Urgent': return kCoral;
        default: return kNavy;
      }
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kServicePriorities.map((p) {
        final selected = _priority == p;
        final c = colorFor(p);
        return GestureDetector(
          onTap: () => setState(() => _priority = p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? c.withValues(alpha: 0.14) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? c : Colors.grey.shade200, width: selected ? 1.5 : 1),
            ),
            child: Text(p, style: TextStyle(color: selected ? c : Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _saving ? [] : [BoxShadow(color: kTeal.withValues(alpha: 0.3), blurRadius: 18)],
      ),
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: kTeal,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kTeal.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 20),
              const SizedBox(width: 10),
              Text(_isEdit ? 'Save Changes' : 'Schedule Service',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: kTeal),
      const SizedBox(width: 8),
      Text(title.toUpperCase(),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    ]);
  }

  Widget _field({
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
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: kTeal, fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: kTeal, size: 20),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200, width: 1)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kTeal, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCoral, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCoral, width: 1.5)),
        errorStyle: const TextStyle(color: kCoral),
      ),
    );
  }
}

// ── DATE + TIME PICKER FIELD (local — avoids depending on the unused
//    widgets/Drone entry form fields.dart, whose filename contains spaces) ──

class _DateTimePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final Color accent;

  const _DateTimePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.accent,
    this.firstDate,
    this.lastDate,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = value ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(now.year - 1),
      lastDate: lastDate ?? DateTime(now.year + 1),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: accent, surface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null) return;
    if (!context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: accent, surface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null) return;

    onChanged(DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ));
  }

  String _formatted(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          prefixIcon: Icon(Icons.calendar_month_outlined, color: accent, size: 20),
          suffixIcon: Icon(Icons.access_time, color: Colors.grey.shade400, size: 18),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accent, width: 1.5)),
        ),
        child: Text(
          value != null ? _formatted(value!) : 'Select date & time',
          style: TextStyle(
            color: value == null ? Colors.grey.shade400 : const Color(0xFF0A1628),
            fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}