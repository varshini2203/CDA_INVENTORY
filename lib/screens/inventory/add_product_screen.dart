// lib/screens/inventory/add_product_screen.dart

import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController addedByController = TextEditingController(); // 🆕

  String selectedCategory = "ONFIELD";
  int selectedBranch = 1; // 1 = CDA Admin, 2 = CDA Ops
  bool isLoading = false;

  static const Map<int, String> branchLabels = {1: 'CDA Admin', 2: 'CDA Ops'};

  static const List<String> categories = [
    "ONFIELD",
    "RPTO",
    "STATIONARY",
    "ELECTRICAL",
    "TOOL KITS",
    "LAB ROOM",
    "CHARGING STATION",
    "NAVIN KIT",
    "FPV DRONES",
    "REMOTE CONTROLLER",
    "ADDITIONAL DRONE SPARE",
    "3D PRINTER",
    "HOUSEKEEPING SUPPLIES",
    "MANAGER ROOM",
    "INSTRUCTOR ROOM",
    "CORRIDOR THINGS",
    "REST ROOM THING",
  ];

  static const Map<String, IconData> categoryIcons = {
    "ONFIELD": Icons.flight_takeoff,
    "RPTO": Icons.verified_user,
    "STATIONARY": Icons.edit_note,
    "ELECTRICAL": Icons.electrical_services,
    "TOOL KITS": Icons.construction,
    "LAB ROOM": Icons.science,
    "CHARGING STATION": Icons.battery_charging_full,
    "NAVIN KIT": Icons.backpack,
    "FPV DRONES": Icons.videocam,
    "REMOTE CONTROLLER": Icons.sports_esports,
    "ADDITIONAL DRONE SPARE": Icons.build_circle,
    "3D PRINTER": Icons.print,
    "HOUSEKEEPING SUPPLIES": Icons.cleaning_services,
    "MANAGER ROOM": Icons.meeting_room,
    "INSTRUCTOR ROOM": Icons.school,
    "CORRIDOR THINGS": Icons.door_sliding,
    "REST ROOM THING": Icons.wc,
  };

  Future<void> addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // ── Firestore: returns InventoryItem with auto-generated String id ──
      await InventoryService().addProduct(
        name: nameController.text.trim(),
        category: selectedCategory,
        location: locationController.text.trim(),
        quantity: int.parse(quantityController.text.trim()),
        description: descriptionController.text.trim(),
        branch: selectedBranch,             // 🆕 which branch this item belongs to
        addedBy: addedByController.text.trim(),   // 🆕 who added this item
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text("Product Added Successfully"),
          ]),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    addedByController.dispose();   // 🆕
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text("Add New Item",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0D1B4B),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel("Item Details"),
              _buildCard([
                _field(
                  controller: nameController,
                  label: "Product Name",
                  icon: Icons.inventory_2_outlined,
                  validator: (v) => v!.isEmpty ? "Enter product name" : null,
                ),
                const SizedBox(height: 14),
                _categoryDropdown(),
              ]),

              const SizedBox(height: 16),
              _sectionLabel("Classification"),
              _buildCard([_branchButtons()]),

              const SizedBox(height: 16),
              _sectionLabel("Location & Stock"),
              _buildCard([
                _field(
                  controller: locationController,
                  label: "Storage Location",
                  icon: Icons.location_on_outlined,
                  validator: (v) => v!.isEmpty ? "Enter location" : null,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: quantityController,
                  label: "Quantity",
                  icon: Icons.numbers_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v!.isEmpty) return "Enter quantity";
                    if (int.tryParse(v) == null) return "Must be a number";
                    return null;
                  },
                ),
              ]),

              const SizedBox(height: 16),
              _sectionLabel("Added By"),   // 🆕 new section
              _buildCard([
                _field(
                  controller: addedByController,
                  label: "Your Name",
                  icon: Icons.person_outline,
                  validator: (v) => v!.isEmpty ? "Enter your name" : null,
                ),
              ]),

              const SizedBox(height: 16),
              _sectionLabel("Additional Info"),
              _buildCard([
                _field(
                  controller: descriptionController,
                  label: "Description (optional)",
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                ),
              ]),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : addProduct,
                  icon: isLoading
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add_circle_outline,
                      color: Colors.white),
                  label: Text(
                    isLoading ? "Saving…" : "ADD TO INVENTORY",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _branchButtons() {
    return Row(
      children: branchLabels.entries.map((entry) {
        final selected = selectedBranch == entry.key;
        const color = Color(0xFF1565C0);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                right: entry.key == branchLabels.keys.last ? 0 : 8),
            child: GestureDetector(
              onTap: () => setState(() => selectedBranch = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.12)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? color : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.business_rounded,
                        size: 16,
                        color: selected ? color : Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? color : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1565C0),
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelStyle: const TextStyle(color: Color(0xFF1565C0)),
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0), size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _categoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedCategory,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: "Category",
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelStyle: const TextStyle(color: Color(0xFF1565C0)),
        prefixIcon: Icon(
            categoryIcons[selectedCategory] ?? Icons.category,
            color: const Color(0xFF1565C0),
            size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: categories
          .map((cat) => DropdownMenuItem(
        value: cat,
        child: Row(
          children: [
            Icon(categoryIcons[cat] ?? Icons.category,
                size: 16, color: const Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text(cat,
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87)),
          ],
        ),
      ))
          .toList(),
      onChanged: (value) => setState(() => selectedCategory = value!),
    );
  }
}