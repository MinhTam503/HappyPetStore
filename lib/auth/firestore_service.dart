import 'package:cloud_firestore/cloud_firestore.dart';

class Firestore_Service {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getShopInfo() async {
    final snapshot = await _firestore.collection('ShopInfo').get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data() as Map<String, dynamic>;
    } else {
      return null;
    }
  }

  Future<void> updateMapShopInfo(String googleMapsUrl) async {
    final snapshot = await _firestore.collection('ShopInfo').get();
    if (snapshot.docs.isNotEmpty) {
      final docId = snapshot.docs.first.id;
      _firestore.collection('ShopInfo').doc(docId).update({
        'googleMapsUrl': googleMapsUrl,
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
