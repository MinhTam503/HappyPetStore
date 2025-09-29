import 'package:pet_shop/presentation/pages/web/model/pet_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Firestore_Service {

  /// Lấy 1 thú cưng theo id
  Future<Pet?> getPetById(String id) async {
    final doc = await _firestore.collection('Pets').doc(id).get();
    if (doc.exists) {
      return Pet.fromDocument(doc);
    }
    return null;
  }

  /// Lấy tất cả thú cưng
  Future<List<Pet>> getAllPets() async {
    final snapshot = await _firestore.collection('Pets').get();
    return snapshot.docs.map((doc) => Pet.fromDocument(doc)).toList();
  }
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getShopInfo() async {
    final snapshot = await _firestore.collection('ShopInfo').get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data() as Map<String, dynamic>;
    } else {
      return null;
    }
  }

  Future<void> updateMapShopInfo(String googleMapsUrl, double latitude, double longitude) async {
    final snapshot = await _firestore.collection('ShopInfo').get();
    if (snapshot.docs.isNotEmpty) {
      final docId = snapshot.docs.first.id;
      _firestore.collection('ShopInfo').doc(docId).update({
        'googleMapsUrl': googleMapsUrl,
        'latitude': latitude,
        'longitude': longitude,
      });
    }
  }

  Future<void> updateAvatarShop(String imageUrl) async {
    final snapshot = await _firestore.collection('ShopInfo').get();
    if (snapshot.docs.isNotEmpty) {
      final docId = snapshot.docs.first.id;
      _firestore.collection("ShopInfo").doc(docId).update({
        'avatar': imageUrl,
      });
    }
  }
  Future<void> updateaInfoShop(String about,String address,String name) async {
    final snapshot = await _firestore.collection('ShopInfo').get();
    if (snapshot.docs.isNotEmpty) {
      final docId = snapshot.docs.first.id;
      _firestore.collection("ShopInfo").doc(docId).update({
        'about': about,
        'address': address,
        'name': name,
      });
    }
  }
}
