import 'package:cloud_firestore/cloud_firestore.dart';

class ViewedPetModel {
  final String id;
  final String name;
  final String imageUrl;
  final String? category;
  final String? breed;
  final dynamic price;
  final DateTime viewedAt;

  const ViewedPetModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.viewedAt,
    this.category,
    this.breed,
    this.price,
  });

  Map<String, dynamic> toFirestore() => {
        'petId': id,
        'name': name,
        'imageUrl': imageUrl,
        'category': category,
        'breed': breed,
        'price': price,
        'viewedAt': FieldValue.serverTimestamp(),
        'viewedAtMillis': DateTime.now().millisecondsSinceEpoch,
      };

  static ViewedPetModel fromFirestore(String id, Map<String, dynamic> data) {
    final ts = data['viewedAt'] as Timestamp?;
    return ViewedPetModel(
      id: id,
      name: data['name'] ?? '',
      imageUrl: (data['imageUrl'] ?? '') as String,
      category: data['category'],
      breed: data['breed'],
      price: (data['price'] as num?)?.toInt(),
      viewedAt: ts is Timestamp
          ? ts.toDate()
          : DateTime.fromMillisecondsSinceEpoch(
              (data['viewedAtMillis'] ?? 0) as int),
    );
  }
}
