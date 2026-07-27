import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:cda_inventory/models/fixed_asset.dart';
import 'package:cda_inventory/services/fixed_asset_service.dart';

class AddFixedProductScreen extends StatefulWidget {
  final FixedAsset? existing;

  const AddFixedProductScreen({
    super.key,
    this.existing,
  });

  @override
  State<AddFixedProductScreen> createState() =>
      _AddFixedProductScreenState();
}

class _AddFixedProductScreenState extends State<AddFixedProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addedByController;

  String _selectedBranch = 'CDA Admin';
  String _selectedStatus = 'Active';
  late DateTime _addedOn;

  bool _saving = false;

  static const Color _navy = Color(0xFF0A1628);
  static const Color _accent = Color(0xFF00A98F);
  static const Color _surface = Color(0xFFF0F4F8);

  static const List<String> _branches = [
    'CDA Admin',
    'CDA Ops',
  ];

  static const List<String> _statuses = [
    'Active',
    'Maintenance',
    'Retired',
  ];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final asset = widget.existing;

    _nameController = TextEditingController(
      text: asset?.name ?? '',
    );

    _quantityController = TextEditingController(
      text: asset == null ? '' : '${asset.quantity}',
    );

    _locationController = TextEditingController(
      text: asset?.location ?? '',
    );

    _descriptionController = TextEditingController(
      text: asset?.description ?? '',
    );

    _addedByController = TextEditingController(
      text: asset?.createdBy ?? '',
    );

    _addedOn = asset?.createdAt ?? DateTime.now();

    if (asset != null && _branches.contains(asset.branch)) {
      _selectedBranch = asset.branch;
    }

    if (asset != null && _statuses.contains(asset.status)) {
      _selectedStatus = asset.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _addedByController.dispose();
    super.dispose();
  }

  Future<void> _pickAddedOnDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _addedOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_addedOn),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _addedOn = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    final existingCategory = widget.existing?.category.trim();

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'quantity': int.parse(_quantityController.text.trim()),
      'branch': _selectedBranch,
      'location': _locationController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': existingCategory != null && existingCategory.isNotEmpty
          ? existingCategory
          : 'Fixed Asset',
      'status': _selectedStatus,
      'createdBy': _addedByController.text.trim(),
      'createdAt': Timestamp.fromDate(_addedOn),
    };

    try {
      if (_isEdit) {
        await FixedAssetService.updateAsset(
          widget.existing!.id,
          data,
        );
      } else {
        await FixedAssetService.addAsset(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Asset updated successfully'
                : 'Fixed asset added successfully',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Fixed Asset' : 'Add Fixed Asset',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Added By'),
                  _buildCard([
                    _field(
                      controller: _addedByController,
                      label: 'Your Name',
                      icon: Icons.person_outline_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDateField(),
                  ]),
                  const SizedBox(height: 18),
                  _sectionLabel('Asset Details'),
                  _buildCard([
                    _field(
                      controller: _nameController,
                      label: 'Asset Name',
                      icon: Icons.inventory_2_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Asset name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _quantityController,
                      label: 'Quantity',
                      icon: Icons.layers_rounded,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Quantity is required';
                        }

                        final quantity = int.tryParse(value.trim());

                        if (quantity == null || quantity < 0) {
                          return 'Enter a valid quantity';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _locationController,
                      label: 'Location / Room',
                      icon: Icons.location_on_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Location is required';
                        }
                        return null;
                      },
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _sectionLabel('Classification'),
                  _buildCard([
                    _dropdown(
                      label: 'Branch',
                      icon: Icons.business_rounded,
                      value: _selectedBranch,
                      items: _branches,
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedBranch = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _statusSelector(),
                  ]),
                  const SizedBox(height: 18),
                  _sectionLabel('Notes'),
                  _buildCard([
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoration(
                        label: 'Description (optional)',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Icon(
                        _isEdit
                            ? Icons.save_rounded
                            : Icons.add_circle_outline_rounded,
                      ),
                      label: Text(
                        _saving
                            ? 'Saving…'
                            : _isEdit
                            ? 'Save Changes'
                            : 'Add Fixed Asset',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _accent.withOpacity(0.55),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 2,
        bottom: 8,
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickAddedOnDate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: _accent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatDate(_addedOn),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.edit_rounded,
              size: 17,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      textCapitalization: keyboardType == TextInputType.number
          ? TextCapitalization.none
          : TextCapitalization.words,
      decoration: _decoration(
        label: label,
        icon: icon,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: Colors.white,
      decoration: _decoration(
        label: label,
        icon: icon,
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _statusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              'Status',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: _statuses.map((status) {
            final selected = status == _selectedStatus;
            final color = _statusColor(status);

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: status == _statuses.last ? 0 : 8,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.12)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? color
                            : Colors.grey.shade300,
                        width: selected ? 1.8 : 1,
                      ),
                    ),
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected
                            ? color
                            : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
      ),
      floatingLabelStyle: const TextStyle(
        color: _accent,
      ),
      prefixIcon: Icon(
        icon,
        color: _accent,
        size: 20,
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: _accent,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Maintenance':
        return Colors.orange.shade700;
      case 'Retired':
        return Colors.red.shade600;
      default:
        return Colors.green.shade600;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day $month $year, $hour:$minute $period';
  }
}