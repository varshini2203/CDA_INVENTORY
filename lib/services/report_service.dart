// lib/services/report_service.dart
//
// Firestore-backed reporting service. Pulls drone flight history (from the
// `drones/{id}/history` sub-collections), stock transactions, and invoices
// for a given month, and exposes both the raw rows (for the detail report
// screens) and an aggregated MonthlySummary (for the Reports dashboard).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/stock.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MONTHLY SUMMARY
// ─────────────────────────────────────────────────────────────────────────────

class MonthlySummary {
  final int droneInCount;
  final int droneOutCount;
  final int stockInCount;
  final int stockOutCount;
  final int stockInQty;
  final int stockOutQty;
  final int invoiceCount;
  final double invoiceTotal;

  MonthlySummary({
    required this.droneInCount,
    required this.droneOutCount,
    required this.stockInCount,
    required this.stockOutCount,
    required this.stockInQty,
    required this.stockOutQty,
    required this.invoiceCount,
    required this.invoiceTotal,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DRONE REPORT ROW
// One row per drone in/out event within the selected month, flattened out
// of each drone's `history` sub-collection with the parent drone's name and
// model attached for display.
// ─────────────────────────────────────────────────────────────────────────────

class DroneReportRow {
  final String droneId;
  final String droneName;
  final String droneModel;
  final String pilot;
  final String status; // 'IN' | 'OUT'
  final String? notes;
  final DateTime? timestamp;
  final String? branch; // raw value: 'Branch 1' (CDA Admin) or 'Branch 2' (CDA Ops)

  DroneReportRow({
    required this.droneId,
    required this.droneName,
    required this.droneModel,
    required this.pilot,
    required this.status,
    this.notes,
    this.timestamp,
    this.branch,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class ReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── IN-MEMORY REPORT CACHE ──────────────────────────────────────────────
  // Reports are read-heavy and the same month is frequently re-requested:
  // once by the Reports Dashboard (to build the summary) and again by each
  // individual report screen the user drills into (Drone In/Out, Stock
  // History, Invoices). Without caching that's the same Firestore data
  // fetched twice, and for the drone report specifically, each month costs
  // "1 + number of drones" reads (a sub-collection read per drone) — so
  // re-fetching it is expensive.
  //
  // Cache key = "year-month". Callers that need fresh data (e.g. pull-to-
  // refresh) pass forceRefresh:true.
  static final Map<String, List<DroneReportRow>> _droneCache = {};
  static final Map<String, List<StockTransaction>> _stockCache = {};
  static final Map<String, List<Invoice>> _invoiceCache = {};

  static String _key(int year, int month) => '$year-$month';

  /// Clears all cached report data.
  static void clearCache() {
    _droneCache.clear();
    _stockCache.clear();
    _invoiceCache.clear();
    _allInvoicesCache = null;
    _droneMeta = null;
  }

  // ── MONTHLY SUMMARY (aggregates the three reports below) ───────────────────

  static Future<MonthlySummary> fetchMonthlySummary(
      int year, int month, {bool forceRefresh = false}) async {
    final drones = await fetchDroneInOutReport(year, month, forceRefresh: forceRefresh);
    final stock = await fetchStockHistoryReport(year, month, forceRefresh: forceRefresh);
    final invoices = await fetchInvoiceReport(year, month, forceRefresh: forceRefresh);

    final droneInCount = drones.where((d) => d.status == 'IN').length;
    final droneOutCount = drones.where((d) => d.status == 'OUT').length;

    final stockIn = stock.where((t) => t.type == 'IN').toList();
    final stockOut = stock.where((t) => t.type == 'OUT').toList();
    final stockInQty = stockIn.fold<int>(0, (s, t) => s + t.quantity);
    final stockOutQty = stockOut.fold<int>(0, (s, t) => s + t.quantity);

    final invoiceTotal = invoices.fold<double>(0, (s, i) => s + i.displayAmount);

    return MonthlySummary(
      droneInCount: droneInCount,
      droneOutCount: droneOutCount,
      stockInCount: stockIn.length,
      stockOutCount: stockOut.length,
      stockInQty: stockInQty,
      stockOutQty: stockOutQty,
      invoiceCount: invoices.length,
      invoiceTotal: invoiceTotal,
    );
  }

  // ── DRONE IN/OUT REPORT ──────────────────────────────────────────────────
  // Previously: 1 read for the full `drones` collection, THEN a separate
  // `history` sub-collection query PER drone inside a for-loop (an N+1
  // pattern — "1 + number of drones" reads for every single month
  // requested, even for drones with zero activity that month).
  //
  // Now: a single Firestore `collectionGroup('history')` query fetches the
  // matching history documents across EVERY drone's `history` sub-collection
  // in one round trip, filtered directly by the timestamp range. Drone
  // metadata (name/model, needed only for display) is fetched once via
  // [_droneMetaCache] and reused for the lifetime of the app session
  // instead of being re-read on every month requested.
  //
  // Requires a Firestore composite index on the `history` collection group
  // for `timestamp` (Firestore will prompt with a direct console link the
  // first time this runs, if the index doesn't already exist).

  static Future<List<DroneReportRow>> fetchDroneInOutReport(
      int year, int month, {bool forceRefresh = false}) async {
    final key = _key(year, month);
    if (!forceRefresh && _droneCache.containsKey(key)) {
      return _droneCache[key]!;
    }

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    // One query across every drone's `history` sub-collection, instead of
    // one query per drone.
    final historySnapshot = await _db
        .collectionGroup('history')
        .where(
      'timestamp',
      isGreaterThanOrEqualTo: Timestamp.fromDate(start),
    )
        .where(
      'timestamp',
      isLessThan: Timestamp.fromDate(end),
    )
        .get();

    // Drone name/model lookup — fetched once per app session (see
    // [_droneMetaCache]), not once per month requested.
    final droneMeta = await _droneMetaCache(forceRefresh: forceRefresh);

    final rows = historySnapshot.docs.map((historyDoc) {
      final historyData = historyDoc.data();
      // `history` docs live at drones/{droneId}/history/{historyId}, so the
      // parent drone's id is the id of the grandparent document.
      final droneId = historyDoc.reference.parent.parent!.id;
      final droneData = droneMeta[droneId];

      return DroneReportRow(
        droneId: droneId,
        droneName: droneData?['name']?.toString() ?? 'Unknown Drone',
        droneModel: droneData?['model']?.toString() ?? '',
        pilot: historyData['pilot']?.toString() ?? 'Unknown',
        status: historyData['status']?.toString() ?? '',
        notes: historyData['notes']?.toString(),
        timestamp:
        (historyData['timestamp'] as Timestamp?)?.toDate(),
        branch: droneData?['branch']?.toString(),
      );
    }).toList();

    // Sort newest first
    rows.sort((a, b) {
      final ta = a.timestamp?.millisecondsSinceEpoch ?? 0;
      final tb = b.timestamp?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });

    _droneCache[key] = rows;
    return rows;
  }

  // ── DRONE METADATA CACHE ─────────────────────────────────────────────────
  // Backs [fetchDroneInOutReport]'s display fields (name/model). The drone
  // list itself barely changes, so it's fetched once per app session and
  // reused across every month/report request instead of being re-read
  // every time a report is generated.
  static Map<String, Map<String, dynamic>>? _droneMeta;

  static Future<Map<String, Map<String, dynamic>>> _droneMetaCache(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _droneMeta != null) return _droneMeta!;
    final dronesSnapshot = await _db.collection('drones').get();
    _droneMeta = {
      for (final droneDoc in dronesSnapshot.docs) droneDoc.id: droneDoc.data(),
    };
    return _droneMeta!;
  }

  // ── STOCK HISTORY REPORT ─────────────────────────────────────────────────

  static Future<List<StockTransaction>> fetchStockHistoryReport(
      int year, int month, {bool forceRefresh = false}) async {
    final key = _key(year, month);
    if (!forceRefresh && _stockCache.containsKey(key)) {
      return _stockCache[key]!;
    }

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final snap = await _db
        .collection('stock_transactions')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('created_at', isLessThan: Timestamp.fromDate(end))
        .get();

    final list = snap.docs.map(StockTransaction.fromFirestore).toList();

    list.sort((a, b) {
      final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });

    _stockCache[key] = list;
    return list;
  }

  // ── DRONE / STOCK REPORTS — DATE-RANGE VARIANTS ─────────────────────────
  // Used by the Reports Dashboard, which lets the admin pick an arbitrary
  // date range (up to several years wide) rather than a single month.
  // Previously the dashboard looped every month spanned by the range and
  // called fetchDroneInOutReport()/fetchStockHistoryReport() once PER
  // month — for drones that meant re-issuing the collectionGroup query
  // once per month instead of once for the whole range; for stock it meant
  // one full query per month instead of one query total. These two methods
  // fetch the exact range in a single Firestore round trip instead.
  //
  // Not cached the same way as the per-month methods above (the range is
  // arbitrary and user-picked, so a "year-month" cache key doesn't apply);
  // the per-drone metadata lookup they rely on IS still cached via
  // [_droneMetaCache], so repeated range queries in the same session still
  // avoid re-reading the `drones` collection itself.

  static Future<List<DroneReportRow>> fetchDroneInOutReportRange(
      DateTime start, DateTime end, {bool forceRefresh = false}) async {
    final historySnapshot = await _db
        .collectionGroup('history')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .get();

    final droneMeta = await _droneMetaCache(forceRefresh: forceRefresh);

    final rows = historySnapshot.docs.map((historyDoc) {
      final historyData = historyDoc.data();
      final droneId = historyDoc.reference.parent.parent!.id;
      final droneData = droneMeta[droneId];

      return DroneReportRow(
        droneId: droneId,
        droneName: droneData?['name']?.toString() ?? 'Unknown Drone',
        droneModel: droneData?['model']?.toString() ?? '',
        pilot: historyData['pilot']?.toString() ?? 'Unknown',
        status: historyData['status']?.toString() ?? '',
        notes: historyData['notes']?.toString(),
        timestamp: (historyData['timestamp'] as Timestamp?)?.toDate(),
        branch: droneData?['branch']?.toString(),
      );
    }).toList();

    rows.sort((a, b) {
      final ta = a.timestamp?.millisecondsSinceEpoch ?? 0;
      final tb = b.timestamp?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });

    return rows;
  }

  static Future<List<StockTransaction>> fetchStockHistoryReportRange(
      DateTime start, DateTime end) async {
    final snap = await _db
        .collection('stock_transactions')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('created_at', isLessThan: Timestamp.fromDate(end))
        .get();

    final list = snap.docs.map(StockTransaction.fromFirestore).toList();
    list.sort((a, b) {
      final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    return list;
  }

  /// Every invoice in the collection, fetched once and cached (the same
  /// [_allInvoicesCache] used by [fetchInvoiceReport]). Exposed directly so
  /// callers like the Reports Dashboard can filter across an arbitrary
  /// date range in memory instead of looping [fetchInvoiceReport] once per
  /// month — though note that loop was already cheap after the first call,
  /// since [fetchInvoiceReport] only pays for one real Firestore read no
  /// matter how many months are requested.
  static Future<List<Invoice>> fetchAllInvoices({bool forceRefresh = false}) async {
    if (forceRefresh) _allInvoicesCache = null;
    if (_allInvoicesCache == null) {
      final snap = await _db.collection('invoices').get();
      _allInvoicesCache = snap.docs
          .map((d) => Invoice.fromFirestore(
          d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    }
    return _allInvoicesCache!;
  }

  // ── INVOICE REPORT ───────────────────────────────────────────────────────
  // Invoice.purchaseDate is stored as a "dd-MM-yyyy" string rather than a
  // Timestamp, so filtering happens client-side after parsing that string.
  // (If invoice volume grows large, consider adding a real Timestamp field
  // to the invoice document and filtering server-side instead.)

  // Every call previously re-read the ENTIRE invoices collection, then
  // filtered client-side (purchaseDate is a string, not a Timestamp, so
  // Firestore can't filter it server-side). Calling this once per month in
  // a date-range loop meant re-downloading every invoice N times over. Now
  // the full collection is fetched once and cached; per-month filtering
  // happens purely in memory afterwards.
  static List<Invoice>? _allInvoicesCache;

  static Future<List<Invoice>> fetchInvoiceReport(
      int year, int month, {bool forceRefresh = false}) async {
    if (forceRefresh) _allInvoicesCache = null;
    final key = _key(year, month);
    if (!forceRefresh && _invoiceCache.containsKey(key)) {
      return _invoiceCache[key]!;
    }

    if (_allInvoicesCache == null) {
      final snap = await _db.collection('invoices').get();
      _allInvoicesCache = snap.docs
          .map((d) => Invoice.fromFirestore(
          d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    }
    final all = _allInvoicesCache!;

    final result = all.where((inv) {
      final parts = inv.purchaseDate.split('-');
      if (parts.length != 3) return false;
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      return y == year && m == month;
    }).toList()
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

    _invoiceCache[key] = result;
    return result;
  }
}