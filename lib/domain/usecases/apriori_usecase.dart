import '../entities/breed_entities.dart';
import '../repositories/apriori_repository.dart';

class AprioriUseCase {
  final AprioriRepository repository;
  
  AprioriUseCase(this.repository);

  /// Phân tích các cặp breeds thường đi cùng nhau
  Map<String, Map<String, BreedAssociation>> analyzeBreedAssociations(
    List<BreedTransaction> transactions, {
    double minSupport = 0.1,
    double minConfidence = 0.3,
  }) {
    print('🔍 Analyzing ${transactions.length} transactions with minSupport: $minSupport, minConfidence: $minConfidence');
    
    Map<String, Map<String, int>> pairCounts = {};
    Map<String, int> breedCounts = {};
    int totalTransactions = transactions.length;

    // Đếm tần suất xuất hiện của từng breed
    for (var transaction in transactions) {
      for (var breed in transaction.breeds) {
        breedCounts[breed] = (breedCounts[breed] ?? 0) + 1;
      }
    }
    print('📊 Found ${breedCounts.length} unique breeds: ${breedCounts.keys.toList()}');

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
    print('🔄 Found ${pairCounts.length} breed pairs');

    // Tính confidence và tạo associations
    Map<String, Map<String, BreedAssociation>> associations = {};
    int validAssociations = 0;
    
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
            validAssociations++;
          }
          
          if (confidenceBA >= minConfidence) {
            associations[breedB] ??= {};
            associations[breedB]![breedA] = BreedAssociation(
              breedA: breedB,
              breedB: breedA,
              count: pairCount,
              confidence: confidenceBA,
            );
            validAssociations++;
          }
        }
      }
    }

    print('✅ Created ${validAssociations} valid associations');
    print('🎯 Association keys: ${associations.keys.toList()}');
    return associations;
  }

  /// Gợi ý breeds dựa trên nhiều breeds đầu vào
  List<String> suggestBreedsFromMultiple(
    List<String> inputBreeds,
    Map<String, Map<String, BreedAssociation>> associations,
  ) {
    print('🔍 Suggesting breeds from input: $inputBreeds');
    print('📊 Available associations: ${associations.keys.toList()}');
    
    Map<String, double> breedScores = {};

    for (var inputBreed in inputBreeds) {
      print('🔄 Checking associations for breed: $inputBreed');
      
      if (associations.containsKey(inputBreed)) {
        var breedAssociations = associations[inputBreed]!;
        print('✅ Found ${breedAssociations.length} associations for $inputBreed');
        
        for (var association in breedAssociations.values) {
          String suggestedBreed = association.breedB;
          
          // Bỏ qua nếu breed đã có trong input
          if (inputBreeds.contains(suggestedBreed)) {
            print('⏭️ Skipping $suggestedBreed (already in input)');
            continue;
          }
          
          // Tính điểm dựa trên confidence
          double oldScore = breedScores[suggestedBreed] ?? 0;
          breedScores[suggestedBreed] = oldScore + association.confidence;
          print('💡 Added $suggestedBreed with confidence ${association.confidence} (total: ${breedScores[suggestedBreed]})');
        }
      } else {
        print('❌ No associations found for breed: $inputBreed');
      }
    }

    print('📈 Final breed scores: $breedScores');

    // Sắp xếp theo điểm số giảm dần
    var sortedBreeds = breedScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var result = sortedBreeds.map((e) => e.key).toList();
    print('🎯 Final sorted suggestions: $result');
    return result;
  }

  /// Use case chính: Lấy gợi ý pets dựa trên nhiều breeds
  Future<List<SuggestedPet>> getSuggestedPetsFromMultipleBreeds(
    List<String> inputBreeds, {
    double minSupport = 0.01,
    double minConfidence = 0.3,
    int maxSuggestions = 10,
  }) async {
    try {
      print('🔍 Starting getSuggestedPetsFromMultipleBreeds with: $inputBreeds');
      
      // 1. Lấy transactions
      final transactions = await repository.getBreedTransactions();
      print('📊 Found ${transactions.length} transactions');
      if (transactions.isEmpty) {
        print('❌ No transactions found');
        return [];
      }

      // 2. Phân tích associations
      print('🔄 Analyzing breed associations...');
      final associations = analyzeBreedAssociations(
        transactions,
        minSupport: minSupport,
        minConfidence: minConfidence,
      );
      print('🎯 Found ${associations.length} associations');

      // 3. Gợi ý breeds
      print('💡 Suggesting breeds from input: $inputBreeds');
      final suggestedBreeds = suggestBreedsFromMultiple(inputBreeds, associations);
      print('📝 Suggested breeds: $suggestedBreeds');
      if (suggestedBreeds.isEmpty) {
        print('❌ No suggested breeds found');
        return [];
      }

      // 4. Lấy pets từ suggested breeds
      print('🐕 Getting pets for breeds: ${suggestedBreeds.take(maxSuggestions).toList()}');
      final petsData = await repository.getPetsByBreeds(
        suggestedBreeds.take(maxSuggestions).toList(),
        limit: maxSuggestions,
      );
      print('🎉 Found ${petsData.length} pets');

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
      
      print('✅ Returning ${suggestedPets.length} suggested pets');
      return suggestedPets.take(maxSuggestions).toList();
    } catch (e) {
      print('❌ Error in getSuggestedPetsFromMultipleBreeds: $e');
      return [];
    }
  }
}
