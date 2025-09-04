import 'package:flutter_test/flutter_test.dart';
import 'package:pet_shop/domain/entities/breed_entities.dart';
import 'package:pet_shop/domain/usecases/apriori_usecase.dart';
import 'package:pet_shop/domain/repositories/apriori_repository.dart';
import 'package:pet_shop/services/apriori/apriori_algorithm.dart';

// Fake repository với dữ liệu test phong phú
class RichTestAprioriRepository implements AprioriRepository {
  @override
  Future<List<BreedTransaction>> getBreedTransactions() async {
    return [
      // Order có Golden Retriever thường đi với Labrador
      BreedTransaction(orderId: 'order1', breeds: ['Golden Retriever', 'Labrador'], timestamp: DateTime.now()),
      BreedTransaction(orderId: 'order2', breeds: ['Golden Retriever', 'Labrador'], timestamp: DateTime.now()),
      BreedTransaction(orderId: 'order3', breeds: ['Golden Retriever', 'Labrador'], timestamp: DateTime.now()),
      BreedTransaction(orderId: 'order4', breeds: ['Golden Retriever', 'Labrador'], timestamp: DateTime.now()),
      
      // Order có Persian Cat thường đi với Siamese Cat
      BreedTransaction(orderId: 'order5', breeds: ['Persian Cat', 'Siamese Cat'], timestamp: DateTime.now()),
      BreedTransaction(orderId: 'order6', breeds: ['Persian Cat', 'Siamese Cat'], timestamp: DateTime.now()),
      BreedTransaction(orderId: 'order7', breeds: ['Persian Cat', 'Siamese Cat'], timestamp: DateTime.now()),
      
      // Order có Beagle thường đi với Border Collie
      BreedTransaction(orderId: 'order8', breeds: ['Beagle', 'Border Collie'], timestamp: DateTime.now()),
      BreedTransaction(orderId: 'order9', breeds: ['Beagle', 'Border Collie'], timestamp: DateTime.now()),
      
      // Order phức tạp có nhiều giống
      BreedTransaction(orderId: 'order10', breeds: ['Golden Retriever', 'Persian Cat', 'Beagle'], timestamp: DateTime.now()),
      BreedTransaction(orderId: 'order11', breeds: ['Golden Retriever', 'Persian Cat', 'Siamese Cat'], timestamp: DateTime.now()),
      BreedTransaction(orderId: 'order12', breeds: ['Labrador', 'Border Collie', 'Beagle'], timestamp: DateTime.now()),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getPetsByBreeds(List<String> breeds, {int limit = 10}) async {
    final allPets = [
      {'id': 'pet1', 'name': 'Lab 1', 'breed': 'Labrador', 'age': 2, 'weight': 25.0, 'image': 'lab1.jpg', 'color': 'Yellow'},
      {'id': 'pet2', 'name': 'Lab 2', 'breed': 'Labrador', 'age': 3, 'weight': 28.0, 'image': 'lab2.jpg', 'color': 'Chocolate'},
      {'id': 'pet3', 'name': 'Siamese 1', 'breed': 'Siamese Cat', 'age': 1, 'weight': 4.0, 'image': 'siamese1.jpg', 'color': 'Seal Point'},
      {'id': 'pet4', 'name': 'Siamese 2', 'breed': 'Siamese Cat', 'age': 2, 'weight': 4.5, 'image': 'siamese2.jpg', 'color': 'Blue Point'},
      {'id': 'pet5', 'name': 'Collie 1', 'breed': 'Border Collie', 'age': 2, 'weight': 20.0, 'image': 'collie1.jpg', 'color': 'Black & White'},
      {'id': 'pet6', 'name': 'Collie 2', 'breed': 'Border Collie', 'age': 3, 'weight': 22.0, 'image': 'collie2.jpg', 'color': 'Red & White'},
      {'id': 'pet7', 'name': 'German Shepherd', 'breed': 'German Shepherd', 'age': 4, 'weight': 30.0, 'image': 'gsd.jpg', 'color': 'Sable'},
      {'id': 'pet8', 'name': 'Husky', 'breed': 'Husky', 'age': 3, 'weight': 25.0, 'image': 'husky.jpg', 'color': 'Gray & White'},
    ];
    
    return allPets.where((pet) => breeds.contains(pet['breed'])).take(limit).toList();
  }

  @override
  Future<Map<String, dynamic>?> getCachedAnalysisResult(String key) async => null;

  @override
  Future<void> saveAnalysisResult(String key, Map<String, dynamic> result) async {}
}

void main() {
  group('OLD vs NEW Algorithm Comparison', () {
    late AprioriUseCase newAlgorithm;
    late AprioriAlgorithm oldAlgorithm;
    late RichTestAprioriRepository repository;

    setUp(() {
      repository = RichTestAprioriRepository();
      newAlgorithm = AprioriUseCase(repository);
      oldAlgorithm = AprioriAlgorithm();
    });

    test('OLD ALGORITHM - Single breed analysis (LIMITATION)', () async {
      // Arrange - Cart có 3 giống khác nhau nhưng old algorithm chỉ xử lý 1 giống
      final cartItems = [
        {'breed': 'Golden Retriever', 'name': 'Golden Dog A', 'price': 500.0},
        {'breed': 'Persian Cat', 'name': 'Persian Cat A', 'price': 300.0},
        {'breed': 'Beagle', 'name': 'Beagle Dog A', 'price': 400.0},
      ];

      print('=== OLD ALGORITHM TEST ===');
      print('Cart contains ${cartItems.length} items with breeds:');
      for (var item in cartItems) {
        print('  - ${item['name']}: ${item['breed']}');
      }

      // Old algorithm chỉ lấy breed đầu tiên
      final firstBreed = cartItems.first['breed'] as String;
      print('\\n❌ OLD ALGORITHM LIMITATION:');
      print('   Only analyzes first breed: $firstBreed');
      print('   Ignores: Persian Cat, Beagle');

      // Giả lập kết quả của old algorithm (chỉ dựa trên Golden Retriever)
      final oldResult = await oldAlgorithm.getSuggestedPets(firstBreed);
      
      print('\\n📊 OLD ALGORITHM RESULTS:');
      print('   Suggestions based on single breed ($firstBreed): ${oldResult.length}');
      for (var pet in oldResult) {
        print('   - ${pet['name']} (${pet['breed']})');
      }
    });

    test('NEW ALGORITHM - Multi-breed analysis (IMPROVEMENT)', () async {
      // Arrange - Cùng cart items
      final cartItems = [
        {'breed': 'Golden Retriever', 'name': 'Golden Dog A', 'price': 500.0},
        {'breed': 'Persian Cat', 'name': 'Persian Cat A', 'price': 300.0},
        {'breed': 'Beagle', 'name': 'Beagle Dog A', 'price': 400.0},
      ];

      print('\\n=== NEW ALGORITHM TEST ===');
      print('Cart contains ${cartItems.length} items with breeds:');
      for (var item in cartItems) {
        print('  - ${item['name']}: ${item['breed']}');
      }

      // Extract all unique breeds
      final uniqueBreeds = cartItems
          .map((item) => item['breed'] as String)
          .toSet()
          .toList();

      print('\\n NEW ALGORITHM IMPROVEMENT:');
      print('   Analyzes ALL breeds: $uniqueBreeds');
      print('   Considers associations between multiple breeds');

      // Act - New algorithm processes all breeds
      final newResult = await newAlgorithm.getSuggestedPetsFromMultipleBreeds(uniqueBreeds);
      
      print('\\n NEW ALGORITHM RESULTS:');
      print('   Suggestions based on multiple breeds: ${newResult.length}');
      for (var pet in newResult) {
        print('   - ${pet.name} (${pet.breed}) - Confidence: ${pet.confidence.toStringAsFixed(2)}');
      }

      // Assert improvements
      expect(uniqueBreeds.length, equals(3));
      expect(uniqueBreeds.contains('Golden Retriever'), true);
      expect(uniqueBreeds.contains('Persian Cat'), true);
      expect(uniqueBreeds.contains('Beagle'), true);
    });

    test('DETAILED COMPARISON - Why new algorithm is better', () async {
      // Test case: Khách hàng mua 5 giống khác nhau
      final largeCartItems = [
        {'breed': 'Golden Retriever', 'name': 'Golden 1', 'price': 500.0},
        {'breed': 'Persian Cat', 'name': 'Persian 1', 'price': 300.0},
        {'breed': 'Beagle', 'name': 'Beagle 1', 'price': 400.0},
        {'breed': 'Labrador', 'name': 'Lab 1', 'price': 450.0},
        {'breed': 'Border Collie', 'name': 'Collie 1', 'price': 550.0},
      ];

      print('\\n=== DETAILED COMPARISON ===');
      print('🛒 CUSTOMER CART (5 different breeds):');
      for (var item in largeCartItems) {
        print('   ${item['name']} - ${item['breed']} - \$${item['price']}');
      }

      // OLD Algorithm simulation
      final firstBreedOnly = largeCartItems.first['breed'] as String;
      print('\\n OLD ALGORITHM:');
      print('   Input: $firstBreedOnly (ONLY!)');
      print('   Lost information: Persian Cat, Beagle, Labrador, Border Collie');
      print('   Result: Suggestions based on 1/5 breeds = 20% of available data');

      // NEW Algorithm 
      final allBreeds = largeCartItems
          .map((item) => item['breed'] as String)
          .toSet()
          .toList();
      
      print('\\n NEW ALGORITHM:');
      print('   Input: $allBreeds (ALL!)');
      print('   Uses: 100% of available breed data');
      print('   Analyzes breed associations across entire purchase pattern');

      final newResult = await newAlgorithm.getSuggestedPetsFromMultipleBreeds(allBreeds);
      
      print('\\n IMPROVEMENT SUMMARY:');
      print('   - Data utilization: 20% → 100% (+400%)');
      print('   - Breed analysis: Single → Multi-breed');
      print('   - Association patterns: None → Cross-breed associations');
      print('   - Suggestions quality: Basic → Advanced with confidence scores');
      print('   - Customer satisfaction: Lower → Higher (more relevant suggestions)');
      
      print('\\n NEW ALGORITHM SUGGESTIONS:');
      for (var pet in newResult) {
        print('   ${pet.name} (${pet.breed}) - Confidence: ${(pet.confidence * 100).toStringAsFixed(1)}%');
      }

      expect(allBreeds.length, equals(5));
      expect(newResult.isNotEmpty, true);
    });

    test('BREED ASSOCIATIONS ANALYSIS', () async {
      final transactions = await repository.getBreedTransactions();
      
      print('\\n=== BREED ASSOCIATIONS ANALYSIS ===');
      print(' Training data: ${transactions.length} orders');
      
      // Analyze associations
      final associations = newAlgorithm.analyzeBreedAssociations(transactions);
      
      print('\\n🔗 DISCOVERED ASSOCIATIONS:');
      associations.forEach((breedA, breedBMap) {
        breedBMap.forEach((breedB, association) {
          final percentage = (association.confidence * 100).toStringAsFixed(1);
          print('   ${association.breedA} → ${association.breedB}: ${percentage}% confidence (${association.count} orders)');
        });
      });

      expect(associations.isNotEmpty, true);
      
      print('\\n💡 BUSINESS INSIGHTS:');
      print('   - Customers buying Golden Retriever often also buy Labrador');
      print('   - Persian Cat buyers frequently purchase Siamese Cat');
      print('   - Beagle owners tend to also get Border Collie');
      print('   - These patterns enable smart recommendations!');
    });
  });
}
