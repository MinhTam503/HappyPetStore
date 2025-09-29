import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/data/models/viewed_pet_model.dart';
import 'package:pet_shop/domain/repositories/viewed_pets/recent_pets_repository.dart';

class RecentPetsRepositoryImpl implements RecentPetsRepository {
  final FirebaseFirestore _firestore;
  final UserManager _userManager;

  RecentPetsRepositoryImpl({
    FirebaseFirestore? firestore,
    UserManager? userManager,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _userManager = userManager ?? UserManager();

  @override
  Future<void> add(ViewedPetModel pet) async {
    try {
      await _userManager.initialize();
      final userId = await _userManager.getUserIdentifier();
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final viewedPetRef = _firestore
          .collection('ViewedPets')
          .doc(userId)
          .collection('pets')
          .doc(pet.id);

      // Kiểm tra xem pet đã tồn tại chưa
      final docSnapshot = await viewedPetRef.get();
      
      if (docSnapshot.exists) {
        // Nếu đã tồn tại, chỉ cập nhật thời gian xem
        await viewedPetRef.update({
          'viewedAt': FieldValue.serverTimestamp(),
          'viewedAtMillis': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // Nếu chưa tồn tại, tạo mới document
        await viewedPetRef.set(pet.toFirestore());
      }
    } catch (e) {
      print('Error adding viewed pet: $e');
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final userId = await _userManager.getUserIdentifier();
      if (userId == null) return;

      final snapshot = await _firestore
          .collection('ViewedPets')
          .doc(userId)
          .collection('pets')
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing viewed pets: $e');
      rethrow;
    }
  }

  @override
  Future<List<ViewedPetModel>> getAll({int limit = 10}) async {
    try {
      final userId = await _userManager.getUserIdentifier();
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('ViewedPets')
          .doc(userId)
          .collection('pets')
          .orderBy('viewedAtMillis', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ViewedPetModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error getting viewed pets: $e');
      return [];
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      final userId = await _userManager.getUserIdentifier();
      if (userId == null) return;

      await _firestore
          .collection('ViewedPets')
          .doc(userId)
          .collection('pets')
          .doc(id)
          .delete();
    } catch (e) {
      print('Error removing viewed pet: $e');
      rethrow;
    }
  }
}