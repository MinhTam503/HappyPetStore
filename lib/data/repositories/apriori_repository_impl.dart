import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/breed_entities.dart';
import '../../domain/repositories/apriori_repository.dart';

class AprioriRepositoryImpl implements AprioriRepository {
  // Lazy initialization to ensure Firebase is initialized first
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  Future<List<BreedTransaction>> getBreedTransactions() async {
    try {
      print("🔍 Fetching completed orders for breed analysis...");
      
      final ordersSnapshot = await _firestore
          .collection("orders")
          .where("statusOrder", isEqualTo: "Completed")
          .get();

      print("Found ${ordersSnapshot.docs.length} completed orders");

      // Lấy tất cả product IDs từ orders
      Set<String> neededProductIds = {};
      for (var doc in ordersSnapshot.docs) {
        final items = List<Map<String, dynamic>>.from(doc["items"] ?? []);
        for (var item in items) {
          if (item["productId"] != null) {
            neededProductIds.add(item["productId"]);
          }
        }
      }

      if (neededProductIds.isEmpty) {
        print("No product IDs found in orders");
        return [];
      }

      print(" Fetching breed info for ${neededProductIds.length} pets");

      // Lấy breed info từ Pets collection
      Map<String, String> productIdToBreed = await _getProductIdToBreedMapping(neededProductIds);

      print(" Found breed info for ${productIdToBreed.length} pets");

      // Tạo breed transactions
      List<BreedTransaction> breedTransactions = [];
      
      for (var doc in ordersSnapshot.docs) {
        final items = List<Map<String, dynamic>>.from(doc["items"] ?? []);
        Set<String> breedSet = {};

        for (var item in items) {
          final breed = productIdToBreed[item["productId"]];
          if (breed != null && breed.isNotEmpty) {
            breedSet.add(breed);
          }
        }

        // Chỉ tạo transaction nếu có ít nhất 1 breed (thay vì 2)
        if (breedSet.isNotEmpty) {
          final timestamp = (doc["timestamp"] as Timestamp?)?.toDate() ?? DateTime.now();
          
          breedTransactions.add(BreedTransaction(
            orderId: doc.id,
            breeds: breedSet.toList(),
            timestamp: timestamp,
          ));
        }
      }

      print("Generated ${breedTransactions.length} breed transactions");
      return breedTransactions;
    } catch (e) {
      print(" Error in getBreedTransactions: $e");
      return [];
    }
  }

  Future<Map<String, String>> _getProductIdToBreedMapping(Set<String> productIds) async {
    Map<String, String> productIdToBreed = {};
    
    // Chia nhỏ thành chunks để tránh giới hạn whereIn
    final chunks = <List<String>>[];
    final ids = productIds.toList();
    
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    for (var chunk in chunks) {
      try {
        final petsSnapshot = await _firestore
            .collection("Pets")
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in petsSnapshot.docs) {
          final breed = doc.data()["breed"] as String?;
          if (breed != null && breed.isNotEmpty) {
            productIdToBreed[doc.id] = breed;
          }
        }
      } catch (e) {
        print(" Error fetching chunk: $e");
      }
    }

    return productIdToBreed;
  }

  @override
  Future<List<Map<String, dynamic>>> getPetsByBreeds(List<String> breeds, {int limit = 10}) async {
    try {
      if (breeds.isEmpty) return [];

      print("Fetching pets for breeds: $breeds");

      // Giới hạn số lượng breeds để tránh vượt quá giới hạn Firestore
      final limitedBreeds = breeds.take(10).toList();

      final petsSnapshot = await _firestore
          .collection("Pets")
          .where("breed", whereIn: limitedBreeds)
          .limit(limit)
          .get();

      final pets = petsSnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();

      print("Found ${pets.length} pets for suggested breeds");
      return pets;
    } catch (e) {
      print("Error in getPetsByBreeds: $e");
      return [];
    }
  }

  @override
  Future<void> saveAnalysisResult(String key, Map<String, dynamic> result) async {
    try {
      await _firestore
          .collection("analysis_cache")
          .doc(key)
          .set({
            ...result,
            'timestamp': FieldValue.serverTimestamp(),
            'ttl': DateTime.now().add(Duration(hours: 24)).millisecondsSinceEpoch,
          });
    } catch (e) {
      print("Error saving analysis cache: $e");
    }
  }

  @override
  Future<Map<String, dynamic>?> getCachedAnalysisResult(String key) async {
    try {
      final doc = await _firestore.collection("analysis_cache").doc(key).get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      final ttl = data['ttl'] as int?;
      
      // Kiểm tra TTL
      if (ttl != null && DateTime.now().millisecondsSinceEpoch > ttl) {
        // Xóa cache hết hạn
        await doc.reference.delete();
        return null;
      }
      
      return data;
    } catch (e) {
      print("Error getting analysis cache: $e");
      return null;
    }
  }
}
