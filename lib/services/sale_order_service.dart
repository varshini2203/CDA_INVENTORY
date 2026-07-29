// lib/services/sale_order_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale_order.dart';
import 'activity_log_service.dart';

class SaleOrderService {
  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('sale_orders');

  static List<SaleOrder>? _cache;
  static void clearCache() => _cache = null;

  static const String _codeChars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static final Random _rand = Random();

  static Future<List<SaleOrder>> fetchOrders({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    final snap = await _col.get();
    final orders = snap.docs
        .map((d) => SaleOrder.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
        .toList()
      ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
    _cache = orders;
    return orders;
  }

  static Future<String> generateOrderNo() async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final code = List.generate(4, (_) => _codeChars[_rand.nextInt(_codeChars.length)]).join();
    return 'SO-$code-$ts';
  }

  static Future<SaleOrder> createOrder(SaleOrder order) async {
    final data = order.toFirestore()..['created_at'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    clearCache();
    ActivityLogService.logAdd(
      module: 'Sale Orders',
      itemName: order.orderNo,
      data: {
        'customer': order.customer?.name,
        'amount': order.grandTotal,
        'branch': order.branch,
        'status': order.status,
      },
    );
    return order.copyWith(id: ref.id);
  }

  static Future<void> updateOrder(SaleOrder order) async {
    if (order.id == null) return;
    final existingDoc = await _col.doc(order.id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(order.id).update(order.toFirestore());
    clearCache();
    ActivityLogService.logEdit(
      module: 'Sale Orders',
      itemName: order.orderNo,
      before: {'status': before['status'], 'amount': before['grand_total']},
      after: {'status': order.status, 'amount': order.grandTotal},
    );
  }

  static Future<void> updateStatus(String id, String status) async {
    final doc = await _col.doc(id).get();
    final before = doc.data() ?? {};
    await _col.doc(id).update({'status': status});
    clearCache();
    ActivityLogService.logEdit(
      module: 'Sale Orders',
      itemName: (before['order_no'] as String?) ?? id,
      before: {'status': before['status']},
      after: {'status': status},
    );
  }

  static Future<void> deleteOrder(String id) async {
    final doc = await _col.doc(id).get();
    final before = doc.data();
    await _col.doc(id).delete();
    clearCache();
    ActivityLogService.logDelete(
      module: 'Sale Orders',
      itemName: (before?['order_no'] as String?) ?? id,
      data: before,
    );
  }
}