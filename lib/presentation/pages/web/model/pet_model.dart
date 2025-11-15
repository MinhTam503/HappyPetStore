import 'package:cloud_firestore/cloud_firestore.dart';

class Pet {
  final String id;
  final String name;
  final String category;
  final String imageUrl;

  final String age;
  final String breed;
  final String about;

  final String gender;
  final String weight;
  final dynamic price; // could be number or string in Firestore
  final String? color; // Màu sắc thú cưng (nullable vì dữ liệu cũ chưa có)
  final bool isAvailable;
  final String? status; // Trạng thái bán (sold, available, etc.)

  Pet({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.age,
    required this.breed,
    required this.about,
    required this.gender,
    required this.weight,
    required this.price,
    this.color, // Nullable field
    this.isAvailable = false,
    this.status, // Nullable field
  });

  factory Pet.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Pet(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      imageUrl: data['imageUrl'] ??
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT5Ubj9xSnLv0WDBYaGnpjt6CQZ8wFe9OltBQ&s',
      age: data['age'] ?? '',
      breed: data['breed'] ?? 'breed',
      about: data['about'] ?? '',
      gender: data['sex'] ?? '',
      weight: data['weight']?.toString() ?? '',
      price: data['price'],
      color: data['color'], // Nullable field từ Firestore
      isAvailable: data['isAvailable'] ?? false,
      status: data['status'], // Nullable field từ Firestore
    );
  }
}
