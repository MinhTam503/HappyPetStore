class FavoritePet {
  final String productId;
  final String name;
  final String imageUrl;
  final num price;
  final int createdAtMillis;
  final String? createdAt;

  FavoritePet({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.createdAtMillis,
    this.createdAt,
  });

  factory FavoritePet.fromMap(Map<String, dynamic> map) {
    return FavoritePet(
      productId: (map['productId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      price: map['price'] ?? 0,
      createdAtMillis: (map['createdAtMillis'] is num)
          ? (map['createdAtMillis'] as num).toInt()
          : (map['createdAt'] is String && DateTime.tryParse(map['createdAt']) != null)
              ? DateTime.parse(map['createdAt']).millisecondsSinceEpoch
              : 0,
      createdAt: map['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'createdAtMillis': createdAtMillis,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
