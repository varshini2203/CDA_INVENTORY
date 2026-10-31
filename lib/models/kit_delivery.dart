// lib/models/kit_delivery.dart
//
// Firestore-backed model for the "Kit Deliveries" module.
//
// A kit is a full drone package (drone, propellers, motors, bag ...) sold to
// a customer. Sometimes only part of it is handed over on the day and the
// rest is delivered later — this module tracks what is still PENDING and
// reminds the team until it has been handed over.
//
// Firestore structure:
//   kit_deliveries/                 <- collection
//     {kitId}/                      <- document (KitDelivery)
//        items:     [ {KitItem} ... ]
//        handovers: [ {KitHandover} ... ]   (history of every hand-over)

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/kit_templates.dart';

DateTime? _date(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

// ─────────────────────────────────────────────────────────────────────────────
// ONE PART OF THE KIT
// ─────────────────────────────────────────────────────────────────────────────
class KitItem {
  final String name; // "Propellers"
  final String category; // see kKitItemCategories
  final int requiredQty; // how many the customer is owed in total
  final int deliveredQty; // how many have been handed over so far

  const KitItem({
    required this.name,
    this.category = 'Other',
    required this.requiredQty,
    this.deliveredQty = 0,
  });

  int get pendingQty {
    final p = requiredQty - deliveredQty;
    return p < 0 ? 0 : p;
  }
  bool get isPending => pendingQty > 0;
  bool get isComplete => !isPending;

  KitItem copyWith({
    String? name,
    String? category,
    int? requiredQty,
    int? deliveredQty,
  }) =>
      KitItem(
        name: name ?? this.name,
        category: category ?? this.category,
        requiredQty: requiredQty ?? this.requiredQty,
        deliveredQty: deliveredQty ?? this.deliveredQty,
      );

  factory KitItem.fromMap(Map<String, dynamic> m) => KitItem(
    name: m['name']?.toString() ?? '',
    category: m['category']?.toString() ?? 'Other',
    requiredQty: _int(m['required_qty'], 1),
    deliveredQty: _int(m['delivered_qty'], 0),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'required_qty': requiredQty,
    'delivered_qty': deliveredQty,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ONE HAND-OVER EVENT (history line)
// ─────────────────────────────────────────────────────────────────────────────
class KitHandover {
  final DateTime at;
  final String by;
  final String note;

  /// part name -> quantity handed over in this event
  final Map<String, int> quantities;

  const KitHandover({
    required this.at,
    required this.by,
    this.note = '',
    required this.quantities,
  });

  int get totalQty => quantities.values.fold(0, (a, b) => a + b);

  factory KitHandover.fromMap(Map<String, dynamic> m) {
    final raw = m['quantities'];
    final q = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) => q['$k'] = _int(v));
    }
    return KitHandover(
      at: _date(m['at']) ?? DateTime.now(),
      by: m['by']?.toString() ?? '',
      note: m['note']?.toString() ?? '',
      quantities: q,
    );
  }

  Map<String, dynamic> toMap() => {
    // Plain Timestamp (not serverTimestamp) — it sits inside an array,
    // where FieldValue.serverTimestamp() is not allowed.
    'at': Timestamp.fromDate(at),
    'by': by,
    'note': note,
    'quantities': quantities,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// THE KIT
// ─────────────────────────────────────────────────────────────────────────────
class KitDelivery {
  /// Firestore document id (empty for a new, unsaved kit).
  final String id;

  // Customer
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  // Reference / location
  final String branch; // raw: 'Branch 1' / 'Branch 2'
  final String invoiceRef; // invoice / challan number (optional)

  // Dates
  final DateTime deliveredAt; // first hand-over
  final DateTime? promisedDate; // when the pending parts were promised
  final DateTime? completedAt; // when the last pending part was handed over

  // Content
  final List<KitItem> items;
  final List<KitHandover> handovers;
  final String notes;

  // Audit
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const KitDelivery({
    required this.id,
    required this.customerName,
    this.customerPhone = '',
    this.customerAddress = '',
    required this.branch,
    this.invoiceRef = '',
    required this.deliveredAt,
    this.promisedDate,
    this.completedAt,
    required this.items,
    this.handovers = const [],
    this.notes = '',
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
  });

  // ── Derived ───────────────────────────────────────────────────────────────

  List<KitItem> get pendingItems => items.where((i) => i.isPending).toList();

  bool get isComplete => items.isNotEmpty && pendingItems.isEmpty;
  bool get isPending => !isComplete;

  String get status => isComplete ? kKitComplete : kKitPending;

  int get totalRequired => items.fold(0, (a, i) => a + i.requiredQty);
  int get totalPending => items.fold(0, (a, i) => a + i.pendingQty);
  int get totalDelivered => totalRequired - totalPending;

  /// 0.0 – 1.0
  double get progress =>
      totalRequired == 0 ? 0 : totalDelivered / totalRequired;

  /// "Propellers ×4, Carry Bag ×1"
  String get pendingSummary =>
      pendingItems.map((i) => '${i.name} ×${i.pendingQty}').join(', ');

  /// The moment the reminder should fire: the promised date at the
  /// configured reminder time (kKitReminderHour). Null when there is no
  /// promised date.
  DateTime? get reminderAt {
    final p = promisedDate;
    if (p == null) return null;
    return DateTime(p.year, p.month, p.day, kKitReminderHour, kKitReminderMinute);
  }

  /// Pending AND the promised day has been reached or passed (the whole of
  /// the promised day counts as "due", it only becomes "overdue" the day
  /// after).
  bool get isDueOrOverdue {
    if (!isPending) return false;
    final p = promisedDate;
    if (p == null) return false;
    final today = DateTime.now();
    final promisedDay = DateTime(p.year, p.month, p.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return !promisedDay.isAfter(todayDay);
  }

  /// Pending and the promised day is strictly in the past.
  bool get isOverdue {
    if (!isPending) return false;
    final p = promisedDate;
    if (p == null) return false;
    final today = DateTime.now();
    final promisedDay = DateTime(p.year, p.month, p.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return promisedDay.isBefore(todayDay);
  }

  /// Whole days past the promised date (0 when not overdue).
  int get daysOverdue {
    if (!isOverdue) return 0;
    final p = promisedDate!;
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day)
        .difference(DateTime(p.year, p.month, p.day))
        .inDays;
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  KitDelivery copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? branch,
    String? invoiceRef,
    DateTime? deliveredAt,
    DateTime? promisedDate,
    DateTime? completedAt,
    List<KitItem>? items,
    List<KitHandover>? handovers,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      KitDelivery(
        id: id ?? this.id,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        customerAddress: customerAddress ?? this.customerAddress,
        branch: branch ?? this.branch,
        invoiceRef: invoiceRef ?? this.invoiceRef,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        promisedDate: promisedDate ?? this.promisedDate,
        completedAt: completedAt ?? this.completedAt,
        items: items ?? this.items,
        handovers: handovers ?? this.handovers,
        notes: notes ?? this.notes,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  // ── Firestore -> Dart ─────────────────────────────────────────────────────

  factory KitDelivery.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) =>
      KitDelivery.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  factory KitDelivery.fromMap(String id, Map<String, dynamic> d) {
    final rawItems = d['items'];
    final rawHandovers = d['handovers'];

    return KitDelivery(
      id: id,
      customerName: d['customer_name']?.toString() ?? '',
      customerPhone: d['customer_phone']?.toString() ?? '',
      customerAddress: d['customer_address']?.toString() ?? '',
      branch: d['branch']?.toString() ?? 'Branch 1',
      invoiceRef: d['invoice_ref']?.toString() ?? '',
      deliveredAt: _date(d['delivered_at']) ?? DateTime.now(),
      promisedDate: _date(d['promised_date']),
      completedAt: _date(d['completed_at']),
      items: rawItems is List
          ? rawItems
          .whereType<Map>()
          .map((m) => KitItem.fromMap(Map<String, dynamic>.from(m)))
          .toList()
          : <KitItem>[],
      handovers: rawHandovers is List
          ? rawHandovers
          .whereType<Map>()
          .map((m) => KitHandover.fromMap(Map<String, dynamic>.from(m)))
          .toList()
          : <KitHandover>[],
      notes: d['notes']?.toString() ?? '',
      createdBy: d['created_by']?.toString() ?? '',
      createdAt: _date(d['created_at']),
      updatedAt: _date(d['updated_at']),
    );
  }

  // ── Dart -> Firestore ─────────────────────────────────────────────────────
  //
  // created_at / updated_at are added by KitDeliveryService (server
  // timestamps), so they are intentionally not written from here.

  Map<String, dynamic> toFirestore() => {
    'customer_name': customerName.trim(),
    'customer_name_lower': customerName.trim().toLowerCase(),
    'customer_phone': customerPhone.trim(),
    'customer_address': customerAddress.trim(),
    'branch': branch,
    'invoice_ref': invoiceRef.trim(),
    'delivered_at': Timestamp.fromDate(deliveredAt),
    'promised_date':
    promisedDate == null ? null : Timestamp.fromDate(promisedDate!),
    'completed_at':
    completedAt == null ? null : Timestamp.fromDate(completedAt!),
    'items': items.map((i) => i.toMap()).toList(),
    'handovers': handovers.map((h) => h.toMap()).toList(),
    'notes': notes.trim(),
    // Stored redundantly so the list can be filtered / counted without
    // recomputing, and so Firestore rules / reports can use it.
    'status': status,
    'pending_qty': totalPending,
    'created_by': createdBy,
  };
}