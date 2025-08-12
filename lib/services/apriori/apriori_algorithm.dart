import 'package:cloud_firestore/cloud_firestore.dart';

class AprioriAlgorithm {
  Future<List<List<String>>> getAllBreedTransactions() async {
    try {
      print("🔍 Fetching completed orders...");
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection("orders")
          .where("statusOrder", isEqualTo: "Completed")
          .get();

      print("✅ Found ${ordersSnapshot.docs.length} completed orders");

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
        print("⚠️ No product IDs found in orders");
        return [];
      }

      print("📦 Fetching breed info for ${neededProductIds.length} pets");

      // Tách ID thành nhiều phần nếu vượt quá giới hạn
      final chunks = <List<String>>[];
      final ids = neededProductIds.toList();
      for (var i = 0; i < ids.length; i += 10) {
        chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
      }

      Map<String, String> productIdToBreed = {};
      for (var chunk in chunks) {
        final petsSnapshot = await FirebaseFirestore.instance
            .collection("Pets")
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in petsSnapshot.docs) {
          final breed = doc.data()["breed"] as String?;
          if (breed != null) {
            productIdToBreed[doc.id] = breed;
          }
        }
      }

      print("🐶 Found breed info for ${productIdToBreed.length} pets");

      List<List<String>> breedTransactions = [];
      for (var doc in ordersSnapshot.docs) {
        final items = List<Map<String, dynamic>>.from(doc["items"] ?? []);
        Set<String> breedSet = {};

        for (var item in items) {
          final breed = productIdToBreed[item["productId"]];
          if (breed != null) {
            breedSet.add(breed);
          }
        }

        if (breedSet.length >= 2) {
          breedTransactions.add(breedSet.toList());
        }
      }

      print("📊 Generated ${breedTransactions.length} breed transactions");
      return breedTransactions;
    } catch (e) {
      print("❌ Error in getAllBreedTransactions: $e");
      return [];
    }
  }

  Map<String, Map<String, int>> analyzeBreedPairs(List<List<String>> transactions) {
    Map<String, Map<String, int>> pairCounts = {};

    for (var transaction in transactions) {
      for (int i = 0; i < transaction.length; i++) {
        for (int j = i + 1; j < transaction.length; j++) {
          String a = transaction[i];
          String b = transaction[j];

          // Đảm bảo a < b để tránh trùng lặp
          if (a.compareTo(b) > 0) {
            final temp = a;
            a = b;
            b = temp;
          }

          pairCounts[a] ??= {};
          pairCounts[a]![b] = (pairCounts[a]![b] ?? 0) + 1;
        }
      }
    }

    return pairCounts;
  }

  List<String> suggestBreeds(String selectedBreed, Map<String, Map<String, int>> pairCounts) {
    Map<String, int> suggestions = {};

    if (pairCounts.containsKey(selectedBreed)) {
      suggestions.addAll(pairCounts[selectedBreed]!);
    }

    for (var entry in pairCounts.entries) {
      final otherBreed = entry.key;
      final subMap = entry.value;

      if (subMap.containsKey(selectedBreed)) {
        suggestions[otherBreed] =
            (suggestions[otherBreed] ?? 0) + subMap[selectedBreed]!;
      }
    }

    final sortedSuggestions = suggestions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedSuggestions.map((e) => e.key).toList();
  }

  Future<List<Map<String, dynamic>>> getSuggestedPets(String selectedBreed) async {
    try {
      print("🔎 Getting suggestions for breed: $selectedBreed");

      final transactions = await getAllBreedTransactions();
      if (transactions.isEmpty) {
        print("⚠️ No transactions available");
        return [];
      }

      // Phân tích các cặp giống thường đi chung
      final pairCounts = analyzeBreedPairs(transactions);

      // Lấy danh sách giống liên quan đến selectedBreed, theo tần suất cao nhất
      final suggestedBreeds = suggestBreeds(selectedBreed, pairCounts);

      if (suggestedBreeds.isEmpty) {
        print("❗ No breeds found related to $selectedBreed");
        return [];
      }

      print("💡 Suggested breeds for $selectedBreed: $suggestedBreeds");

      final petsSnapshot = await FirebaseFirestore.instance
          .collection("Pets")
          .where("breed", whereIn: suggestedBreeds.take(10).toList()) // giới hạn số giống
          .limit(5) // giới hạn số thú cưng trả về
          .get();

      final suggestions = petsSnapshot.docs
          .map((doc) => {
        ...doc.data(),
        'id': doc.id,
      })
          .toList();

      print("✅ Found ${suggestions.length} suggested pets");
      return suggestions;
    } catch (e) {
      print("❌ Error in getSuggestedPets: $e");
      return [];
    }
  }
}
