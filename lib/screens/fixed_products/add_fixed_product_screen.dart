import 'package:flutter/material.dart';
import 'package:cda_inventory/services/fixed_asset_service.dart';

class AddFixedProductScreen extends StatefulWidget {
  const AddFixedProductScreen({super.key});

  @override
  State<AddFixedProductScreen> createState() =>
      _AddFixedProductScreenState();
}

class _AddFixedProductScreenState
    extends State<AddFixedProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController =
  TextEditingController();

  final TextEditingController quantityController =
  TextEditingController();

  final TextEditingController locationController =
  TextEditingController();

  final TextEditingController descriptionController =
  TextEditingController();

  String selectedBranch = "Branch 1";
  bool _saving = false;

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final data = {
      'name': nameController.text.trim(),
      'quantity': int.parse(quantityController.text.trim()),
      'branch': selectedBranch,
      'location': locationController.text.trim(),
      'description': descriptionController.text.trim(),
      'category': 'Fixed Asset',
      'status': 'Active',
    };

    try {
      await FixedAssetService.addAsset(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fixed Asset Added Successfully"),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        title: const Text("Add Fixed Asset"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [

              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Asset Name",
                  prefixIcon:
                  const Icon(Icons.inventory),
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Name is required"
                    : null,
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: quantityController,
                keyboardType:
                TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Quantity",
                  prefixIcon:
                  const Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Required";
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0) return "Enter a valid number";
                  return null;
                },
              ),

              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: selectedBranch,
                decoration: InputDecoration(
                  labelText: "Branch",
                  prefixIcon:
                  const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Branch 1",
                    child: Text("Branch 1"),
                  ),
                  DropdownMenuItem(
                    value: "Branch 2",
                    child: Text("Branch 2"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedBranch = value!;
                  });
                },
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: "Location",
                  prefixIcon:
                  const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Location is required"
                    : null,
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Description",
                  prefixIcon:
                  const Icon(Icons.notes),
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.save),
                  label: Text(
                    _saving ? "Saving…" : "Save Asset",
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.blue.shade900,
                    foregroundColor:
                    Colors.white,
                  ),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}