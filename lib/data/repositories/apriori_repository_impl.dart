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
      
      // Try both status field names
      QuerySnapshot? ordersSnapshot;
      try {
        ordersSnapshot = await _firestore
            .collection("orders")
            .where("statusOrder", isEqualTo: "Completed")
            .get();
        print("📊 Found ${ordersSnapshot.docs.length} orders with statusOrder=Completed");
      } catch (e) {
        print("❌ Error with statusOrder field: $e");
        try {
          ordersSnapshot = await _firestore
              .collection("orders")
              .where("status", isEqualTo: "completed")
              .get();
          print("📊 Found ${ordersSnapshot.docs.length} orders with status=completed");
        } catch (e2) {
          print("❌ Error with status field: $e2");
          return [];
        }
      }

      if (ordersSnapshot.docs.isEmpty) {
        print("❌ No completed orders found");
        return [];
      }

      // Debug: Show sample order structure
      if (ordersSnapshot.docs.isNotEmpty) {
        final sampleDoc = ordersSnapshot.docs.first;
        print("📋 Sample order structure: ${sampleDoc.data()}");
      }

      // Lấy tất cả product IDs từ orders
      Set<String> neededProductIds = {};
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(data["items"] ?? []);
        print("🛒 Order ${doc.id} has ${items.length} items");
        
        for (var item in items) {
          if (item["productId"] != null) {
            neededProductIds.add(item["productId"]);
          } else if (item["petId"] != null) {
            neededProductIds.add(item["petId"]);
          }
        }
      }

      if (neededProductIds.isEmpty) {
        print("❌ No product/pet IDs found in orders");
        return [];
      }

      print("🔍 Fetching breed info for ${neededProductIds.length} pets");

      // Lấy breed info từ Pets collection
      Map<String, String> productIdToBreed = await _getProductIdToBreedMapping(neededProductIds);

      print("✅ Found breed info for ${productIdToBreed.length} pets");

      // Tạo breed transactions
      List<BreedTransaction> breedTransactions = [];
      
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(data["items"] ?? []);
        Set<String> breedSet = {};

        for (var item in items) {
          String? petId = item["productId"] ?? item["petId"];
          final breed = productIdToBreed[petId];
          if (breed != null && breed.isNotEmpty) {
            breedSet.add(breed);
          }
        }

        // Chỉ tạo transaction nếu có ít nhất 1 breed (thay vì 2)
        if (breedSet.isNotEmpty) {
          DateTime timestamp;
          try {
            // Handle different timestamp formats
            final timestampField = data["timestamp"];
            if (timestampField is Timestamp) {
              timestamp = timestampField.toDate();
            } else if (timestampField is String) {
              // Try to parse string timestamp
              timestamp = DateTime.tryParse(timestampField) ?? DateTime.now();
            } else {
              timestamp = DateTime.now();
            }
          } catch (e) {
            print("⚠️ Error parsing timestamp for order ${doc.id}: $e");
            timestamp = DateTime.now();
          }
          
          breedTransactions.add(BreedTransaction(
            orderId: doc.id,
            breeds: breedSet.toList(),
            timestamp: timestamp,
          ));
          print("✅ Created transaction for order ${doc.id} with breeds: ${breedSet.toList()}");
        } else {
          print("⚠️ No breeds found for order ${doc.id}");
        }
      }

      print("🎉 Generated ${breedTransactions.length} breed transactions");
      return breedTransactions;
    } catch (e) {
      print("❌ Error in getBreedTransactions: $e");
      return [];
    }
  }

  Future<Map<String, String>> _getProductIdToBreedMapping(Set<String> productIds) async {
    Map<String, String> productIdToBreed = {};
    
    print("🔍 Getting breed mapping for ${productIds.length} product IDs");
    
    // Chia nhỏ thành chunks để tránh giới hạn whereIn
    final chunks = <List<String>>[];
    final ids = productIds.toList();
    
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    print("📦 Split into ${chunks.length} chunks");

    for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
      final chunk = chunks[chunkIndex];
      print("🔄 Processing chunk ${chunkIndex + 1}/${chunks.length} with ${chunk.length} IDs");
      
      try {
        // Try with "Pets" collection first
        QuerySnapshot? petsSnapshot;
        try {
          petsSnapshot = await _firestore
              .collection("Pets")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          print("📊 Found ${petsSnapshot.docs.length} pets in 'Pets' collection");
        } catch (e) {
          print("❌ Error with 'Pets' collection: $e");
          // Try with "pets" collection
          try {
            petsSnapshot = await _firestore
                .collection("pets")
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            print("📊 Found ${petsSnapshot.docs.length} pets in 'pets' collection");
          } catch (e2) {
            print("❌ Error with 'pets' collection: $e2");
            continue;
          }
        }

        if (petsSnapshot.docs.isNotEmpty) {
          for (var doc in petsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final breed = data["breed"] as String?;
            if (breed != null && breed.isNotEmpty) {
              productIdToBreed[doc.id] = breed;
              print("✅ Mapped ${doc.id} -> $breed");
            } else {
              print("⚠️ No breed found for pet ${doc.id}");
            }
          }
        }
      } catch (e) {
        print("❌ Error fetching chunk ${chunkIndex + 1}: $e");
      }
    }

    print("🎉 Final breed mapping: ${productIdToBreed.length} pets mapped");
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
          .map((doc) {
            final data = doc.data();
            final petMap = {
              ...data,
              'id': doc.id,
            };
            print("🐕 Pet data: $petMap");
            return petMap;
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
