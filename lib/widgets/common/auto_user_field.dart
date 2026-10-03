// lib/widgets/common/auto_user_field.dart
//
// Read-only "Added By / Received By / Prepared By ..." field that is
// filled automatically with the logged-in user's name.
//
// The user can NOT type or edit it. The controller is kept so existing
// save code (`controller.text`) keeps working, but every save path should
// ALSO call `await CurrentUserService.getName()` so the stored value can
// never be blank or tampered with.

import 'package:flutter/material.dart';
import '../../services/current_user_service.dart';

class AutoUserField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color accent;

  /// Set true on dark-themed screens.
  final bool dark;

  /// When true and the controller already holds a name (e.g. the original
  /// creator of a record being edited), keep it instead of overwriting it
  /// with the current user. Still read-only either way.
  final bool preferExisting;

  const AutoUserField({
    super.key,
    required this.controller,
    this.label = 'Added By (auto)',
    this.icon = Icons.person_outline,
    this.accent = const Color(0xFF1565C0),
    this.dark = false,
    this.preferExisting = false,
  });

  @override
  State<AutoUserField> createState() => _AutoUserFieldState();
}

class _AutoUserFieldState extends State<AutoUserField> {
  @override
  void initState() {
    super.initState();
    if (widget.preferExisting && widget.controller.text.trim().isNotEmpty) {
      return; // keep the original creator's name
    }
    // Instant value (cache / auth displayName) so the field is never empty.
    widget.controller.text = CurrentUserService.nameSync;
    // Then the authoritative value from Firestore users/{uid}.name.
    CurrentUserService.getName().then((name) {
      if (!mounted) return;
      if (widget.controller.text != name) widget.controller.text = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final textColor = dark ? Colors.white : Colors.black87;
    final labelColor = dark ? Colors.white60 : Colors.grey.shade600;
    final border = dark ? Colors.white24 : Colors.grey.shade300;

    return TextFormField(
      controller: widget.controller,
      readOnly: true,
      enableInteractiveSelection: false,
      style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
      validator: (v) =>
      (v == null || v.trim().isEmpty) ? 'Could not detect logged-in user' : null,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: labelColor),
        floatingLabelStyle: TextStyle(color: widget.accent),
        prefixIcon: Icon(widget.icon, color: widget.accent, size: 20),
        suffixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: labelColor),
        helperText: 'Filled automatically from your login',
        helperStyle: TextStyle(color: labelColor, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        filled: true,
        fillColor: dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
