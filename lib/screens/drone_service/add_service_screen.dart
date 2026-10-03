// lib/screens/drone_service/add_service_screen.dart
//
// Add (or edit, when `existing` is passed) a Drone Service booking.
// Theme matched to add_drone_entry_screen.dart.
//
// CHANGE: the "Schedule" section (Scheduled Date & Time picker) has been
// removed from the form per request. `scheduledAt` is still a required
// field on DroneServiceRecord, so on save we fall back to the existing
// record's scheduledAt (when editing) or DateTime.now() (when creating),
// instead of asking the user to pick it.

import 'package:flutter/material.dart';
import '../../models/drone.dart';
import '../../models/drone_service_record.dart';
import '../../services/drone_service.dart';
import '../../services/current_user_service.dart';
import '../../widgets/common/auto_user_field.dart';
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
  final _addedByCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  // Free-text service name when the user picks "Other" in the Service
  // Type dropdown instead of one of the fixed kServiceTypes options.
  final _customServiceTypeCtrl = TextEditingController();

  final _bookingService = DroneServiceBookingService();
  final _droneService = DroneService();

  String _serviceType = kServiceTypes.first;
  String _branch = kBranchOptions.first;
  String _priority = kServicePriorities[1]; // 'Normal'
  String? _linkedDroneId;
  bool _saving = false;

  // ── Drone In/Out tracking state ──────────────────────────────────────
  DateTime? _checkedInAt;
  DateTime? _checkedOutAt;

  // Scheduled date & time — the alert fires if the service is still open
  // after this moment. Defaults to tomorrow, same time.
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));

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
      _addedByCtrl.text = e.createdBy ?? '';
      _notesCtrl.text = e.notes ?? '';
      _costCtrl.text = e.cost?.toString() ?? '';
      // If the saved serviceType isn't one of the fixed options (i.e. it was
      // typed manually last time), select "Other" and preload the typed text.
      if (kServiceTypes.contains(e.serviceType)) {
        _serviceType = e.serviceType;
      } else {
        _serviceType = 'Other';
        _customServiceTypeCtrl.text = e.serviceType;
      }
      _branch = e.branch;
      _priority = e.priority;
      _linkedDroneId = e.droneId;
      _checkedInAt = e.checkedInAt;
      _checkedOutAt = e.checkedOutAt;
      _scheduledAt = e.scheduledAt;
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
    _addedByCtrl.dispose();
    _notesCtrl.dispose();
    _costCtrl.dispose();
    _customServiceTypeCtrl.dispose();
    super.dispose();
  }

  // ── Check In / Check Out actions ─────────────────────────────────────
  void _checkIn() {
    setState(() => _checkedInAt = DateTime.now());
    _showSnack('Marked as checked in', color: kGreen);
  }

  void _checkOut() {
    if (_checkedInAt == null) {
      _showSnack('Check in first before checking out', isError: true);
      return;
    }
    setState(() => _checkedOutAt = DateTime.now());
    _showSnack('Marked as checked out', color: kGreen);
  }

  void _undoCheckIn() {
    setState(() {
      _checkedInAt = null;
      _checkedOutAt = null; // can't be checked out without being checked in
    });
  }

  void _undoCheckOut() {
    setState(() => _checkedOutAt = null);
  }

  // ── Manual date/time override for Check In / Check Out ────────────────
  // The timestamps are auto-filled with DateTime.now() when the Check
  // In / Check Out buttons are tapped. These let the user open a
  // date + time picker afterwards to correct/backdate the value.
  Future<void> _editCheckedInAt() async {
    final picked = await _pickDateTime(initial: _checkedInAt ?? DateTime.now());
    if (picked == null) return;
    setState(() => _checkedInAt = picked);
  }

  Future<void> _editCheckedOutAt() async {
    if (_checkedInAt == null) {
      _showSnack('Check in first before setting a check-out time', isError: true);
      return;
    }
    final picked = await _pickDateTime(initial: _checkedOutAt ?? DateTime.now());
    if (picked == null) return;
    setState(() => _checkedOutAt = picked);
  }

  Future<DateTime?> _pickDateTime({required DateTime initial}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: kTeal)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: kTeal)),
        child: child!,
      ),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!requireEditAccess(context)) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Logged-in user's name — never typed manually.
    final currentUserName = await CurrentUserService.getName();
    final effectiveScheduledAt = _scheduledAt;

    // When "Other" is picked, save the manually typed name instead of the
    // literal word "Other" so it reads correctly everywhere (reports,
    // history, edit screen re-population, etc).
    final effectiveServiceType = _serviceType == 'Other'
        ? _customServiceTypeCtrl.text.trim()
        : _serviceType;

    final record = DroneServiceRecord(
      id: widget.existing?.id ?? '',
      droneName: _droneNameCtrl.text.trim(),
      droneId: _linkedDroneId,
      serviceType: effectiveServiceType,
      branch: _branch,
      status: widget.existing?.status ?? 'Scheduled',
      priority: _priority,
      scheduledAt: effectiveScheduledAt,
      completedAt: widget.existing?.completedAt,
      technician: _technicianCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      cost: double.tryParse(_costCtrl.text.trim()),
      createdBy: (widget.existing?.createdBy?.trim().isNotEmpty ?? false)
          ? widget.existing!.createdBy
          : currentUserName,
      checkedInAt: _checkedInAt,
      checkedOutAt: _checkedOutAt,
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
            _sectionHeader('Drone In / Out', Icons.compare_arrows_rounded),
            const SizedBox(height: 12),
            _buildInOutSection(),
            const SizedBox(height: 24),
            _sectionHeader('Service Details', Icons.build_circle_outlined),
            const SizedBox(height: 12),
            _buildServiceTypeDropdown(),
            if (_serviceType == 'Other') ...[
              const SizedBox(height: 14),
              _field(
                controller: _customServiceTypeCtrl,
                label: 'Enter Service Detail',
                hint: 'e.g. Landing Gear Repair',
                icon: Icons.edit_note_rounded,
                validator: (v) => _serviceType == 'Other' && (v == null || v.trim().isEmpty)
                    ? 'Please type the service detail'
                    : null,
              ),
            ],
            const SizedBox(height: 14),
            _buildBranchDropdown(),
            const SizedBox(height: 14),
            _buildPrioritySelector(),
            const SizedBox(height: 24),
            _sectionHeader('Schedule', Icons.event_outlined),
            const SizedBox(height: 12),
            _buildScheduleField(),
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
            AutoUserField(
              controller: _addedByCtrl,
              label: 'Added By (auto)',
              accent: kTeal,
              preferExisting: _isEdit,
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

  // ── Drone In/Out card: status pill + Check In / Check Out buttons ────
  Widget _buildInOutSection() {
    final isCheckedOut = _checkedOutAt != null;
    final isCheckedIn = _checkedInAt != null && !isCheckedOut;
    final notCheckedIn = _checkedInAt == null;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    if (isCheckedOut) {
      statusColor = kNavy;
      statusLabel = 'Checked Out';
      statusIcon = Icons.logout_rounded;
    } else if (isCheckedIn) {
      statusColor = kGreen;
      statusLabel = 'Checked In';
      statusIcon = Icons.login_rounded;
    } else {
      statusColor = Colors.grey.shade500;
      statusLabel = 'Not Checked In';
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime dt) => '${two(dt.day)}/${two(dt.month)}/${dt.year}  ${two(dt.hour)}:${two(dt.minute)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Text(statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ]),
            ),
          ]),
          if (_checkedInAt != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.login_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('In: ${fmt(_checkedInAt!)}', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
              const Spacer(),
              InkWell(
                onTap: _editCheckedInAt,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_calendar_rounded, size: 13, color: kTeal),
                    const SizedBox(width: 4),
                    Text('Edit', style: TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _undoCheckIn,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('Undo', style: TextStyle(fontSize: 12, color: kCoral, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
          if (_checkedOutAt != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.logout_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('Out: ${fmt(_checkedOutAt!)}', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
              const Spacer(),
              InkWell(
                onTap: _editCheckedOutAt,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_calendar_rounded, size: 13, color: kTeal),
                    const SizedBox(width: 4),
                    Text('Edit', style: TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _undoCheckOut,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('Undo', style: TextStyle(fontSize: 12, color: kCoral, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: notCheckedIn ? _checkIn : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  side: BorderSide(color: notCheckedIn ? kGreen : Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('Check In (Now)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
            _manualTimeIconButton(
              color: kGreen,
              enabled: notCheckedIn,
              tooltip: 'Set check-in time manually',
              onTap: _editCheckedInAt,
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (isCheckedIn) ? _checkOut : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kNavy,
                  side: BorderSide(color: isCheckedIn ? kNavy : Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Check Out (Now)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
            _manualTimeIconButton(
              color: kNavy,
              enabled: isCheckedIn,
              tooltip: 'Set check-out time manually',
              onTap: _editCheckedOutAt,
            ),
          ]),
        ],
      ),
    );
  }

  // Small square icon button placed beside "Check In (Now)" / "Check Out
  // (Now)" that opens the date + time picker so the value can be entered
  // manually instead of defaulting to the current time.
  Widget _manualTimeIconButton({
    required Color color,
    required bool enabled,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: enabled ? color : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.edit_calendar_rounded, size: 18, color: enabled ? color : Colors.grey.shade400),
          ),
        ),
      ),
    );
  }

  Future<void> _pickScheduled() async {
    final picked = await _pickDateTime(initial: _scheduledAt);
    if (picked != null) setState(() => _scheduledAt = picked);
  }

  Widget _buildScheduleField() {
    final overdue = _scheduledAt.isBefore(DateTime.now());
    String two(int n) => n.toString().padLeft(2, '0');
    final label =
        '${two(_scheduledAt.day)}/${two(_scheduledAt.month)}/${_scheduledAt.year}  ${two(_scheduledAt.hour)}:${two(_scheduledAt.minute)}';
    return InkWell(
      onTap: _pickScheduled,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: overdue ? kCoral : Colors.grey.shade200),
        ),
        child: Row(children: [
          Icon(Icons.event_available_rounded, color: overdue ? kCoral : kTeal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Scheduled date & time',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(color: kNavy, fontSize: 15, fontWeight: FontWeight.w600)),
              if (overdue)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('This time has already passed — it will show as overdue.',
                      style: TextStyle(fontSize: 11, color: kCoral)),
                ),
            ]),
          ),
          Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.grey.shade500),
        ]),
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
      // Without this, the dropdown sizes itself to its widest item instead
      // of the available field width, so a long "name (serial)" pair
      // renders past the field edge and Flutter draws the yellow/black
      // overflow warning stripes instead of the ellipsis below.
      isExpanded: true,
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
          DropdownMenuItem(
            value: d.id,
            child: Text(
              '${d.name} (${d.serialNumber})',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
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