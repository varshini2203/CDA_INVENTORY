import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cda_inventory/models/bill_model.dart';

/// Sorting options exposed to the Bills screen.
enum BillSortOption { dateDesc, dateAsc, amountDesc, amountAsc, vendorAZ, vendorZA }

extension BillSortOptionLabel on BillSortOption {
  String get label {
    switch (this) {
      case BillSortOption.dateDesc:
        return 'Newest first';
      case BillSortOption.dateAsc:
        return 'Oldest first';
      case BillSortOption.amountDesc:
        return 'Amount: High to Low';
      case BillSortOption.amountAsc:
        return 'Amount: Low to High';
      case BillSortOption.vendorAZ:
        return 'Vendor: A to Z';
      case BillSortOption.vendorZA:
        return 'Vendor: Z to A';
    }
  }
}

/// Manages fetching, searching, filtering, sorting, and CRUD operations for
/// bills. Images are stored as Base64 strings directly inside the
/// Firestore document — no Firebase Storage / Blaze plan required.
class BillsProvider extends ChangeNotifier {
  final CollectionReference _billsRef =
  FirebaseFirestore.instance.collection('bills');

  List<BillModel> _bills = [];
  bool _isLoading = false;
  String _errorMessage = '';

  String _searchQuery = '';
  String _selectedCategory = 'All';
  DateTimeRange? _dateRange;
  BillSortOption _sortOption = BillSortOption.dateDesc;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  DateTimeRange? get dateRange => _dateRange;
  BillSortOption get sortOption => _sortOption;
  String get searchQuery => _searchQuery;
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedCategory != 'All' || _dateRange != null;

  /// Filtered + sorted view of the bills. Search matches vendor name,
  /// bill number, category, notes, amount, or the formatted date.
  List<BillModel> get bills {
    final q = _searchQuery.trim().toLowerCase();

    var filtered = _bills.where((bill) {
      final matchesCategory =
          _selectedCategory == 'All' || bill.category == _selectedCategory;

      final matchesDate = _dateRange == null ||
          (!bill.billDate.isBefore(_dateRange!.start) &&
              !bill.billDate.isAfter(_dateRange!.end
                  .add(const Duration(hours: 23, minutes: 59, seconds: 59))));

      if (!matchesCategory || !matchesDate) return false;
      if (q.isEmpty) return true;

      final dateStr =
          '${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}';
      final amountStr = bill.amount.toStringAsFixed(2);

      return bill.vendorName.toLowerCase().contains(q) ||
          bill.billNumber.toLowerCase().contains(q) ||
          bill.category.toLowerCase().contains(q) ||
          bill.notes.toLowerCase().contains(q) ||
          amountStr.contains(q) ||
          dateStr.contains(q);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case BillSortOption.dateAsc:
          return a.billDate.compareTo(b.billDate);
        case BillSortOption.dateDesc:
          return b.billDate.compareTo(a.billDate);
        case BillSortOption.amountAsc:
          return a.amount.compareTo(b.amount);
        case BillSortOption.amountDesc:
          return b.amount.compareTo(a.amount);
        case BillSortOption.vendorAZ:
          return a.vendorName.toLowerCase().compareTo(b.vendorName.toLowerCase());
        case BillSortOption.vendorZA:
          return b.vendorName.toLowerCase().compareTo(a.vendorName.toLowerCase());
      }
    });

    return filtered;
  }

  double get totalAmount => bills.fold(0.0, (sum, b) => sum + b.amount);

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    _dateRange = range;
    notifyListeners();
  }

  void setSortOption(BillSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    _dateRange = null;
    notifyListeners();
  }

  Future<void> fetchBills() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final snapshot =
      await _billsRef.orderBy('billDate', descending: true).get();
      _bills = snapshot.docs
          .map((doc) =>
          BillModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = 'Failed to load bills. Please check your connection.';
      debugPrint('Error fetching bills: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addBill({
    required Uint8List imageBytes,
    required String vendorName,
    required String billNumber,
    required double amount,
    required DateTime billDate,
    required String category,
    String notes = '',
  }) async {
    try {
      final imageBase64 = base64Encode(imageBytes);
      final now = DateTime.now();

      final data = BillModel(
        id: '',
        vendorName: vendorName,
        billNumber: billNumber,
        amount: amount,
        billDate: billDate,
        category: category,
        imageBase64: imageBase64,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      ).toMap();

      final docRef = await _billsRef.add(data);
      _bills.insert(0, BillModel.fromMap(docRef.id, data));
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save bill.';
      debugPrint('Error adding bill: $e');
      return false;
    }
  }

  Future<bool> updateBill({
    required BillModel bill,
    Uint8List? newImageBytes,
    required String vendorName,
    required String billNumber,
    required double amount,
    required DateTime billDate,
    required String category,
    String notes = '',
  }) async {
    try {
      final imageBase64 = newImageBytes != null
          ? base64Encode(newImageBytes)
          : bill.imageBase64;

      final updated = bill.copyWith(
        vendorName: vendorName,
        billNumber: billNumber,
        amount: amount,
        billDate: billDate,
        category: category,
        imageBase64: imageBase64,
        notes: notes,
        updatedAt: DateTime.now(),
      );

      await _billsRef.doc(bill.id).update(updated.toMap());
      final index = _bills.indexWhere((b) => b.id == bill.id);
      if (index != -1) _bills[index] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update bill.';
      debugPrint('Error updating bill: $e');
      return false;
    }
  }

  Future<bool> deleteBill(BillModel bill) async {
    try {
      await _billsRef.doc(bill.id).delete();
      _bills.removeWhere((b) => b.id == bill.id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete bill.';
      debugPrint('Error deleting bill: $e');
      return false;
    }
  }
}