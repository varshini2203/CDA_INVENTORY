import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

import 'package:cda_inventory/models/bill_model.dart';
import 'activity_log_service.dart';

/// Stateless data-access layer for bills. Images are stored as Base64
/// strings inside the Firestore document itself — no Firebase Storage
/// (and therefore no Blaze billing plan) required.
///
/// Note: Firestore documents are capped at 1MB. Keep bill photos
/// compressed (image_picker's `imageQuality: 85` already helps) to stay
/// safely under that limit.
class BillsService {
  BillsService._(); // static-only, no instances

  static final CollectionReference _billsRef =
  FirebaseFirestore.instance.collection('bills');

  // ── IN-MEMORY CACHE ─────────────────────────────────────────────────────
  // BillsScreen re-mounts (and re-fetches) every time the user navigates
  // back to it. Caching here means only the first visit per session reads
  // Firestore; later visits reuse the cached list until a CRUD op clears
  // it, or the user explicitly pulls to refresh.
  static List<BillModel>? _cache;
  static void clearCache() => _cache = null;

  // Firestore caps a document at 1,048,487 bytes. Base64 inflates raw
  // bytes by ~33%, so we target well under that (500KB raw → ~667KB
  // Base64) to leave comfortable headroom for the rest of the document's
  // fields. image_picker's `imageQuality` param is unreliable on Flutter
  // Web, so we re-compress/downscale here in pure Dart instead, which
  // works identically on Web, mobile, and desktop.
  static const int _maxRawBytes = 500000;
  static const int _maxDimension = 1600;

  static String _encodeForFirestore(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Not a decodable image (shouldn't happen from image_picker) — fall
      // back to encoding as-is and let Firestore reject it if it's really
      // too big, rather than silently corrupting the bytes.
      return base64Encode(bytes);
    }

    // Use a non-nullable variable from here on — reassigning a nullable
    // local across a while loop's condition/body defeats Dart's null
    // promotion, which is what caused the earlier analyzer errors.
    img.Image working = decoded;

    if (working.width > _maxDimension || working.height > _maxDimension) {
      working = img.copyResize(
        working,
        width: working.width >= working.height ? _maxDimension : null,
        height: working.height > working.width ? _maxDimension : null,
      );
    }

    var quality = 85;
    Uint8List out = Uint8List.fromList(img.encodeJpg(working, quality: quality));

    // Step down JPEG quality first...
    while (out.length > _maxRawBytes && quality > 30) {
      quality -= 10;
      out = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    // ...then shrink dimensions further if quality alone wasn't enough.
    while (out.length > _maxRawBytes && working.width > 400 && working.height > 400) {
      working = img.copyResize(working, width: (working.width * 0.8).round());
      out = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    return base64Encode(out);
  }

  /// Fetches all bills, newest bill date first.
  ///
  /// Always returns a fresh copy of the cached list, never the internal
  /// [_cache] reference itself. addBill/updateBill/deleteBill mutate
  /// [_cache] directly to keep it in sync — if a caller (e.g. BillsScreen)
  /// held onto that same list object, those internal mutations would
  /// silently double up with the caller's own explicit setState() list
  /// edits after a save, showing the same bill twice in the UI despite
  /// only one Firestore document existing.
  static Future<List<BillModel>> fetchBills({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return List<BillModel>.from(_cache!);
    final snapshot =
    await _billsRef.orderBy('billDate', descending: true).get();
    final bills = snapshot.docs
        .map((doc) =>
        BillModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
    _cache = bills;
    return List<BillModel>.from(bills);
  }

  /// Creates a new bill. Returns the created [BillModel] (with its
  /// generated id).
  static Future<BillModel> addBill({
    required Uint8List imageBytes,
    required String vendorName,
    required String billNumber,
    required double amount,
    required DateTime billDate,
    required String category,
    String notes = '',
  }) async {
    final imageBase64 = _encodeForFirestore(imageBytes);
    final now = DateTime.now();

    final bill = BillModel(
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
    );

    final docRef = await _billsRef.add(bill.toMap());
    final created = BillModel.fromMap(docRef.id, bill.toMap());
    _cache?.insert(0, created); // keep cache in sync instead of clearing it
    ActivityLogService.logAdd(
      module: 'Bills',
      itemName: billNumber.isNotEmpty ? billNumber : vendorName,
      data: {
        'vendor': vendorName,
        'amount': amount,
        'bill_date': billDate,
        'category': category,
        'notes': notes,
      },
    );
    return created;
  }

  /// Updates an existing bill. If [newImageBytes] is provided, it replaces
  /// the stored image; otherwise the existing image is kept untouched.
  static Future<BillModel> updateBill({
    required BillModel bill,
    Uint8List? newImageBytes,
    required String vendorName,
    required String billNumber,
    required double amount,
    required DateTime billDate,
    required String category,
    String notes = '',
  }) async {
    final imageBase64 =
    newImageBytes != null ? _encodeForFirestore(newImageBytes) : bill.imageBase64;

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
    final idx = _cache?.indexWhere((b) => b.id == bill.id) ?? -1;
    if (idx != -1) _cache![idx] = updated; // keep cache in sync
    ActivityLogService.logEdit(
      module: 'Bills',
      itemName: billNumber.isNotEmpty ? billNumber : vendorName,
      before: {
        'vendor': bill.vendorName,
        'bill_number': bill.billNumber,
        'amount': bill.amount,
        'bill_date': bill.billDate,
        'category': bill.category,
        'notes': bill.notes,
      },
      after: {
        'vendor': vendorName,
        'bill_number': billNumber,
        'amount': amount,
        'bill_date': billDate,
        'category': category,
        'notes': notes,
      },
    );
    return updated;
  }

  /// Deletes a bill's Firestore document.
  static Future<void> deleteBill(BillModel bill) async {
    await _billsRef.doc(bill.id).delete();
    _cache?.removeWhere((b) => b.id == bill.id); // keep cache in sync
    ActivityLogService.logDelete(
      module: 'Bills',
      itemName: bill.billNumber.isNotEmpty ? bill.billNumber : bill.vendorName,
      data: {
        'vendor': bill.vendorName,
        'amount': bill.amount,
        'category': bill.category,
      },
    );
  }
}