import '../entities/breed_entities.dart';
import '../repositories/apriori_repository.dart';

class AprioriUseCase {
  final AprioriRepository repository;
  
  AprioriUseCase(this.repository);

  /// Phân tích các cặp breeds thường đi cùng nhau
  Map<String, Map<String, BreedAssociation>> analyzeBreedAssociations(
    List<BreedTransaction> transactions, {
    double minSupport = 0.1,
    double minConfidence = 0.5,
  }) {
    Map<String, Map<String, int>> pairCounts = {};
    Map<String, int> breedCounts = {};
    int totalTransactions = transactions.length;

    // Đếm tần suất xuất hiện của từng breed
    for (var transaction in transactions) {
      for (var breed in transaction.breeds) {
        breedCounts[breed] = (breedCounts[breed] ?? 0) + 1;
      }
    }

    // Đếm tần suất xuất hiện của từng cặp breeds
    for (var transaction in transactions) {
      for (int i = 0; i < transaction.breeds.length; i++) {
        for (int j = i + 1; j < transaction.breeds.length; j++) {
          String breedA = transaction.breeds[i];
          String breedB = transaction.breeds[j];

          // Đảm bảo thứ tự nhất quán
          if (breedA.compareTo(breedB) > 0) {
            String temp = breedA;
            breedA = breedB;
            breedB = temp;
          }

          pairCounts[breedA] ??= {};
          pairCounts[breedA]![breedB] = (pairCounts[breedA]![breedB] ?? 0) + 1;
        }
      }
    }

    // Tính confidence và tạo associations
    Map<String, Map<String, BreedAssociation>> associations = {};
    
    for (var breedA in pairCounts.keys) {
      for (var breedB in pairCounts[breedA]!.keys) {
        int pairCount = pairCounts[breedA]![breedB]!;
        double support = pairCount / totalTransactions;
        
        if (support >= minSupport) {
          // Tính confidence: P(B|A) = count(A,B) / count(A)
          double confidenceAB = pairCount / (breedCounts[breedA] ?? 1);
          double confidenceBA = pairCount / (breedCounts[breedB] ?? 1);
          
          if (confidenceAB >= minConfidence) {
            associations[breedA] ??= {};
            associations[breedA]![breedB] = BreedAssociation(
              breedA: breedA,
              breedB: breedB,
              count: pairCount,
              confidence: confidenceAB,
            );
          }
          
          if (confidenceBA >= minConfidence) {
            associations[breedB] ??= {};
            associations[breedB]![breedA] = BreedAssociation(
              breedA: breedB,
              breedB: breedA,
              count: pairCount,
              confidence: confidenceBA,
            );
          }
        }
      }
    }

    return associations;
  }

  /// Gợi ý breeds dựa trên nhiều breeds đầu vào
  List<String> suggestBreedsFromMultiple(
    List<String> inputBreeds,
    Map<String, Map<String, BreedAssociation>> associations,
  ) {
    Map<String, double> breedScores = {};

    for (var inputBreed in inputBreeds) {
      if (associations.containsKey(inputBreed)) {
        for (var association in associations[inputBreed]!.values) {
          String suggestedBreed = association.breedB;
          
          // Bỏ qua nếu breed đã có trong input
          if (inputBreeds.contains(suggestedBreed)) continue;
          
          // Tính điểm dựa trên confidence
          breedScores[suggestedBreed] = 
            (breedScores[suggestedBreed] ?? 0) + association.confidence;
        }
      }
    }

    // Sắp xếp theo điểm số giảm dần
    var sortedBreeds = breedScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedBreeds.map((e) => e.key).toList();
  }

  /// Use case chính: Lấy gợi ý pets dựa trên nhiều breeds
  Future<List<SuggestedPet>> getSuggestedPetsFromMultipleBreeds(
    List<String> inputBreeds, {
    double minSupport = 0.05,
    double minConfidence = 0.3,
    int maxSuggestions = 10,
  }) async {
    try {
      // 1. Lấy transactions
      final transactions = await repository.getBreedTransactions();
      if (transactions.isEmpty) return [];

      // 2. Phân tích associations
      final associations = analyzeBreedAssociations(
        transactions,
        minSupport: minSupport,
        minConfidence: minConfidence,
      );

      // 3. Gợi ý breeds
      final suggestedBreeds = suggestBreedsFromMultiple(inputBreeds, associations);
      if (suggestedBreeds.isEmpty) return [];

      // 4. Lấy pets từ suggested breeds
      final petsData = await repository.getPetsByBreeds(
        suggestedBreeds.take(maxSuggestions).toList(),
        limit: maxSuggestions,
      );

      // 5. Tạo SuggestedPet với confidence scores
      List<SuggestedPet> suggestedPets = [];
      
      for (int i = 0; i < petsData.length; i++) {
        final petData = petsData[i];
        final breedIndex = suggestedBreeds.indexOf(petData['breed']);
        
        // Confidence giảm dần theo thứ tự gợi ý
        final confidence = breedIndex >= 0 
          ? 1.0 - (breedIndex / suggestedBreeds.length) 
          : 0.5;
          
        suggestedPets.add(SuggestedPet.fromMap(petData, confidence));
      }

      // Sắp xếp theo confidence
      suggestedPets.sort((a, b) => b.confidence.compareTo(a.confidence));
      
      return suggestedPets.take(maxSuggestions).toList();
    } catch (e) {
      print('❌ Error in getSuggestedPetsFromMultipleBreeds: $e');
      return [];
    }
  }
}
