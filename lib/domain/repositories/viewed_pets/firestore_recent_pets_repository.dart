import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pet_shop/data/models/viewed_pet_model.dart';
import 'package:pet_shop/domain/repositories/viewed_pets/recent_pets_repository.dart';


class FirestoreRecentPetsRepository implements RecentPetsRepository {
  FirestoreRecentPetsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.maxItems = 50,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final int maxItems;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('User is not signed in');
    }
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> _col() =>
      _firestore.collection('users').doc(_uid).collection('recently_viewed_pets');

  @override
  Future<void> add(ViewedPetModel pet) async {
    final ref = _col().doc(pet.id);
    // Upsert: merge true để chỉ cập nhật trường cần thiết
    await ref.set(pet.toFirestore(), SetOptions(merge: true));

    // Cắt bớt nếu vượt quá maxItems (xoá các doc cũ nhất)
    await _trimIfNeeded();
  }

  Future<void> _trimIfNeeded() async {
    final snap = await _col()
        .orderBy('viewedAtMillis', descending: true)
        .get();

    if (snap.size > maxItems) {
      final toDelete = snap.docs.skip(maxItems).toList();
      final batches = <WriteBatch>[];
      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (final d in toDelete) {
        batch.delete(d.reference);
        count++;
        if (count == 400) { // an toàn dưới limit 500/commit
          batches.add(batch);
          batch = _firestore.batch();
          count = 0;
        }
      }
      batches.add(batch);
      for (final b in batches) {
        await b.commit();
      }
    }
  }

  @override
  Future<List<ViewedPetModel>> getAll({int limit = 50}) async {
    final snap = await _col()
        .orderBy('viewedAtMillis', descending: true)
        .limit(limit)
        .get();

    return snap.docs
        .map((d) => ViewedPetModel.fromFirestore(d.id, d.data()))
        .toList();
  }

  @override
  Future<void> remove(String id) => _col().doc(id).delete();

  @override
  Future<void> clear() async {
    final q = await _col().limit(500).get();
    final batch = _firestore.batch();
    for (final d in q.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
