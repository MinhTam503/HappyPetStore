import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/utils/search_utils.dart';

Future<void> updateSearchKeywords() async {
  final firestore = FirebaseFirestore.instance;
  
  // Update pets
  final petsSnapshot = await firestore.collection('Pets').get();
  for (var doc in petsSnapshot.docs) {
    final data = doc.data();
    final name = data['name'] as String? ?? '';
    final category = data['category'] as String? ?? '';
    final breed = data['breed'] as String? ?? '';
    
    final searchKeywords = [
      generateSearchKeywords(name),
      generateSearchKeywords(category),
      generateSearchKeywords(breed),
    ].where((k) => k.isNotEmpty).toList();
    
    await doc.reference.update({
      'searchKeywords': searchKeywords,
    });
  }
  
  // Update categories
  final categoriesSnapshot = await firestore.collection('Category').get();
  for (var doc in categoriesSnapshot.docs) {
    final data = doc.data();
    final name = data['name'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    
    final searchKeywords = [
      generateSearchKeywords(name),
      generateSearchKeywords(description),
    ].where((k) => k.isNotEmpty).toList();
    
    await doc.reference.update({
      'searchKeywords': searchKeywords,
    });
  }
}