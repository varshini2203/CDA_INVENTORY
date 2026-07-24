class FixedAsset {
  final int id;
  final String name;
  final int quantity;
  final String location;

  FixedAsset({
    required this.id,
    required this.name,
    required this.quantity,
    required this.location,
  });

  factory FixedAsset.fromJson(Map<String, dynamic> json) {
    return FixedAsset(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'],
      location: json['location'],
    );
  }
}