// lib/models/invoice_line_item.dart
class InvoiceLineItem {
  final String id;
  final String description;
  final String? hsnCode;       // HSN/SAC code for GST filing (also used for Serial No.)
  final String? skuCode;       // optional SKU / internal item code
  final int quantity;
  final String unit;           // e.g. NONE, PCS, KG, BOX...
  final double unitPrice;
  final double discountPercent;
  final double taxPercent;     // per-line GST rate, e.g. 0/5/12/18/28

  InvoiceLineItem({
    required this.id,
    required this.description,
    this.hsnCode,
    this.skuCode,
    required this.quantity,
    this.unit = 'NONE',
    required this.unitPrice,
    this.discountPercent = 0,
    this.taxPercent = 0,
  });

  double get grossAmount => quantity * unitPrice;
  double get discountAmount => grossAmount * (discountPercent / 100);
  double get taxableAmount => grossAmount - discountAmount;
  double get taxAmount => taxableAmount * (taxPercent / 100);
  double get lineTotal => taxableAmount + taxAmount;

  factory InvoiceLineItem.fromMap(Map<String, dynamic> m) => InvoiceLineItem(
    id: m['id']?.toString() ?? '',
    description: m['description']?.toString() ?? '',
    hsnCode: m['hsn_code']?.toString(),
    skuCode: m['sku_code']?.toString(),
    quantity: (m['quantity'] as num?)?.toInt() ?? 0,
    unit: m['unit']?.toString() ?? 'NONE',
    unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0.0,
    discountPercent: (m['discount_percent'] as num?)?.toDouble() ?? 0.0,
    taxPercent: (m['tax_percent'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'hsn_code': hsnCode,
    'sku_code': skuCode,
    'quantity': quantity,
    'unit': unit,
    'unit_price': unitPrice,
    'discount_percent': discountPercent,
    'tax_percent': taxPercent,
  };
}