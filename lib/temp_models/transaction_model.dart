class TransactionModel {
  int? id;
  int productId;
  String transactionType;
  int quantity;
  String remarks;

  TransactionModel({
    this.id,
    required this.productId,
    required this.transactionType,
    required this.quantity,
    required this.remarks,
  });
}