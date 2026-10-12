// lib/services/new_product_sale_service.dart
//
// Links the New Products module to Invoices (New Sale).
//
//  Sale of a New Product  -> its `quantity` (and availableQuantityForSale)
//                            in `new_products` is REDUCED right away, so the
//                            New Products list and the Invoice Item list
//                            always show the same remaining number.
//                            e.g. 5 pens, sell 3  -> both show 2.
//  Quantity reaches 0     -> the product is REMOVED from New Products.
//  Edit / delete invoice  -> the old sale is rolled back first (quantity is
//                            added back; a removed product is re-created
//                            from the snapshot saved with the sale record).
//  History button         -> reads `new_product_sales` (name, qty, customer,
//                            invoice, date + time).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'inventory_service.dart';
import 'new_product_service.dart';

/// One sellable row for the Item list (product + what is left to sell).
class SellableNewProduct {
  final NewProduct product;
  final int remaining;
  const SellableNewProduct(this.product, this.remaining);
}

/// One sale-history record.
class NewProductSale {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String invoiceId;
  final String invoiceNo;
  final String customerName;
  final DateTime? soldAt;

  const NewProductSale({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.invoiceId,
    required this.invoiceNo,
    required this.customerName,
    required this.soldAt,
  });

  factory NewProductSale.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final ts = m['soldAt'];
    return NewProductSale(
      id: d.id,
      productId: (m['productId'] ?? '').toString(),
      productName: (m['productName'] ?? '').toString(),
      quantity: (m['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
      invoiceId: (m['invoiceId'] ?? '').toString(),
      invoiceNo: (m['invoiceNo'] ?? '').toString(),
      customerName: (m['customerName'] ?? '').toString(),
      soldAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class NewProductSaleService {
  NewProductSaleService._();

  static final CollectionReference<Map<String, dynamic>> _sales =
  FirebaseFirestore.instance.collection('new_product_sales');
  static final CollectionReference<Map<String, dynamic>> _products =
  FirebaseFirestore.instance.collection('new_products');

  static int _branchId(String label) =>
      label.toLowerCase().contains('ops') ? 2 : 1;

  /// New Products that still have stock (quantity > 0), newest first.
  /// When editing an invoice, what that invoice already sold is added back
  /// so its own items stay selectable.
  static Future<List<SellableNewProduct>> getSellableProducts(
      {String? excludeInvoiceId}) async {
    final all = await NewProductService.getNewProducts(forceRefresh: true);
    final map = <String, SellableNewProduct>{
      for (final p in all)
        if (p.quantity > 0) p.productId: SellableNewProduct(p, p.quantity),
    };

    if (excludeInvoiceId != null) {
      final snap =
      await _sales.where('invoiceId', isEqualTo: excludeInvoiceId).get();
      for (final d in snap.docs) {
        final m = d.data();
        final pid = (m['productId'] ?? '').toString();
        final q = (m['quantity'] as num?)?.toInt() ?? 0;
        if (pid.isEmpty || q <= 0) continue;
        final cur = map[pid];
        if (cur != null) {
          map[pid] = SellableNewProduct(cur.product, cur.remaining + q);
        } else if (m['productSnapshot'] is Map) {
          // product was removed when it sold out -> rebuild for the list
          final p = NewProduct.fromMap(
              pid, Map<String, dynamic>.from(m['productSnapshot'] as Map));
          map[pid] = SellableNewProduct(p.copyWith(quantity: q), q);
        }
      }
    }
    return map.values.toList();
  }

  /// Applies the sale of every New-Product line of [invoice]:
  ///   • rolls back any earlier sale of the same invoice (edit case)
  ///   • reduces quantity in New Products (+ Inventory copy)
  ///   • removes the product when quantity hits 0
  ///   • writes a history record per line
  static Future<void> recordSales(Invoice invoice) async {
    final invoiceId = invoice.id;
    if (invoiceId == null) return;

    await deleteSalesForInvoice(invoiceId); // roll back previous version

    for (final li in invoice.lineItems) {
      final pid = li.newProductId;
      final qty = li.quantity;
      if (pid == null || pid.isEmpty || qty <= 0) continue;

      final ref = _products.doc(pid);
      final doc = await ref.get();
      if (!doc.exists) continue;
      final p = NewProduct.fromFirestore(doc);

      final sell = qty > p.quantity ? p.quantity : qty;
      if (sell <= 0) continue;
      final left = p.quantity - sell;

      // Snapshot (without the big base64 attachments) so a rollback can
      // re-create the product if it was removed.
      final snapshot = p.toMap()
        ..remove('productImage')
        ..remove('invoiceFile');

      if (left <= 0) {
        await ref.delete(); // sold out -> removed from New Products
      } else {
        final newAvail = (p.availableQuantityForSale - sell) < 0
            ? 0
            : p.availableQuantityForSale - sell;
        await ref.update({
          'quantity': left,
          'availableQuantityForSale': newAvail,
          if (p.stockValue > 0 && p.quantity > 0)
            'stockValue': p.stockValue * left / p.quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _sales.doc('${invoiceId}_${li.id}').set({
        'productId': pid,
        'productName': li.description,
        'quantity': sell,
        'unitPrice': li.unitPrice,
        'invoiceId': invoiceId,
        'invoiceNo': invoice.invoiceNo,
        'customerName': invoice.vendorName,
        'soldAt': FieldValue.serverTimestamp(),
        'productSnapshot': snapshot,
      });

      try {
        await InventoryService.incrementQuantityByName(
            name: p.productName, delta: -sell, branch: _branchId(p.branch));
      } catch (_) {}
    }
    NewProductService.clearCache();
  }

  /// Rolls back every sale of [invoiceId]: quantity goes back to New
  /// Products (re-creating the product if it had been removed) and the
  /// history records are deleted. Used by Edit Invoice and Delete Invoice.
  static Future<void> deleteSalesForInvoice(String invoiceId) async {
    final snap = await _sales.where('invoiceId', isEqualTo: invoiceId).get();
    if (snap.docs.isEmpty) return;

    for (final d in snap.docs) {
      final m = d.data();
      final pid = (m['productId'] ?? '').toString();
      final q = (m['quantity'] as num?)?.toInt() ?? 0;
      final name = (m['productName'] ?? '').toString();
      String branch = 'CDA Admin';

      if (pid.isNotEmpty && q > 0) {
        final ref = _products.doc(pid);
        final cur = await ref.get();
        if (cur.exists) {
          final p = NewProduct.fromFirestore(cur);
          branch = p.branch;
          await ref.update({
            'quantity': p.quantity + q,
            'availableQuantityForSale': p.availableQuantityForSale + q,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (m['productSnapshot'] is Map) {
          final data = Map<String, dynamic>.from(m['productSnapshot'] as Map);
          branch = (data['branch'] ?? branch).toString();
          data['quantity'] = q;
          data['availableQuantityForSale'] = q;
          data['createdAt'] = FieldValue.serverTimestamp();
          data['updatedAt'] = FieldValue.serverTimestamp();
          await ref.set(data); // same id -> same product comes back
        }
        try {
          await InventoryService.incrementQuantityByName(
              name: name, delta: q, branch: _branchId(branch));
        } catch (_) {}
      }
      await d.reference.delete();
    }
    NewProductService.clearCache();
  }

  /// Sale history (newest first) for the History button.
  static Future<List<NewProductSale>> getSalesHistory() async {
    final snap = await _sales.get();
    final list = snap.docs.map(NewProductSale.fromDoc).toList()
      ..sort((a, b) {
        final x = a.soldAt, y = b.soldAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    return list;
  }
}