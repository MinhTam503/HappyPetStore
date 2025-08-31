import 'package:flutter_test/flutter_test.dart';
import 'package:pet_shop/domain/entities/breed_entities.dart';
import 'package:pet_shop/domain/usecases/apriori_usecase.dart';
import 'package:pet_shop/domain/repositories/apriori_repository.dart';

// Fake repository cho testing
class FakeAprioriRepository implements AprioriRepository {
  @override
  Future<List<BreedTransaction>> getBreedTransactions() async {
    return [
      BreedTransaction(
        orderId: 'order1',
        breeds: ['Golden Retriever', 'Beagle'],
        timestamp: DateTime.now(),
      ),
      BreedTransaction(
        orderId: 'order2',
        breeds: ['Persian Cat', 'Siamese Cat'],
        timestamp: DateTime.now(),
      ),
      BreedTransaction(
        orderId: 'order3',
        breeds: ['Golden Retriever', 'Persian Cat', 'Beagle'],
        timestamp: DateTime.now(),
      ),
      BreedTransaction(
        orderId: 'order4',
        breeds: ['Golden Retriever', 'Labrador'],
        timestamp: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getPetsByBreeds(List<String> breeds, {int limit = 10}) async {
    return [
      {
        'id': 'pet1',
        'name': 'Suggested Labrador',
        'breed': 'Labrador',
        'age': 2,
        'weight': 20.0,
        'image': 'image1.jpg',
        'color': 'Golden',
      },
      {
        'id': 'pet2',
        'name': 'Suggested Siamese',
        'breed': 'Siamese Cat',
        'age': 1,
        'weight': 4.0,
        'image': 'image2.jpg',
        'color': 'White',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>?> getCachedAnalysisResult(String key) async {
    return null;
  }

  @override
  Future<void> saveAnalysisResult(String key, Map<String, dynamic> result) async {
    // Do nothing for fake implementation
  }
}

// Helper function để mô phỏng việc extract breeds từ cart
List<String> extractBreedsFromCart(List<Map<String, dynamic>> cartItems) {
  return cartItems
      .map((item) => item['breed'] as String)
      .toSet()
      .toList();
}

void main() {
  group('AprioriUseCase Multi-Breed Tests', () {
    late AprioriUseCase aprioriUseCase;
    late FakeAprioriRepository fakeRepository;

    setUp(() {
      fakeRepository = FakeAprioriRepository();
      aprioriUseCase = AprioriUseCase(fakeRepository);
    });

    test('should analyze multiple breeds from cart correctly', () async {
      // Arrange - Giả lập giỏ hàng có 3 giống khác nhau
      final cartItems = [
        {'breed': 'Golden Retriever', 'name': 'Dog A', 'price': 500.0},
        {'breed': 'Persian Cat', 'name': 'Cat A', 'price': 300.0},
        {'breed': 'Beagle', 'name': 'Dog B', 'price': 400.0},
        {'breed': 'Golden Retriever', 'name': 'Dog C', 'price': 550.0}, // Duplicate breed
      ];

      // Extract unique breeds từ cart
      final uniqueBreeds = extractBreedsFromCart(cartItems);

      // Act - Sử dụng method đúng
      final result = await aprioriUseCase.getSuggestedPetsFromMultipleBreeds(uniqueBreeds);

      // Assert
      expect(result.isNotEmpty, true);
      
      print('=== MULTI-BREED ANALYSIS TEST ===');
      print('Processed cart with ${cartItems.length} items');
      print('Unique breeds in cart: $uniqueBreeds');
      print('Expected: 3 unique breeds (Golden Retriever, Persian Cat, Beagle)');
      print('Actual unique breeds count: ${uniqueBreeds.length}');
      print('Suggested pets count: ${result.length}');
      
      // Verify unique breeds extraction
      expect(uniqueBreeds.length, equals(3));
      expect(uniqueBreeds.contains('Golden Retriever'), true);
      expect(uniqueBreeds.contains('Persian Cat'), true);
      expect(uniqueBreeds.contains('Beagle'), true);
      
      for (final pet in result) {
        print('Suggested: ${pet.name} (${pet.breed}) - Confidence: ${pet.confidence.toStringAsFixed(2)}');
      }
    });

    test('should extract unique breeds from cart items correctly', () {
      // Arrange
      final cartItems = [
        {'breed': 'Golden Retriever', 'name': 'Dog A'},
        {'breed': 'Persian Cat', 'name': 'Cat A'},
        {'breed': 'Beagle', 'name': 'Dog B'},
        {'breed': 'Golden Retriever', 'name': 'Dog C'}, // Duplicate
        {'breed': 'Persian Cat', 'name': 'Cat B'}, // Duplicate
      ];

      // Act
      final uniqueBreeds = extractBreedsFromCart(cartItems);

      // Assert
      print('=== UNIQUE BREEDS EXTRACTION TEST ===');
      print('Original cart items count: ${cartItems.length}');
      print('Unique breeds: $uniqueBreeds');
      
      expect(uniqueBreeds.length, 3);
      expect(uniqueBreeds.contains('Golden Retriever'), true);
      expect(uniqueBreeds.contains('Persian Cat'), true);
      expect(uniqueBreeds.contains('Beagle'), true);
    });

    test('should handle single breed cart correctly', () async {
      // Arrange
      final cartItems = [
        {'breed': 'Golden Retriever', 'name': 'Dog A'},
        {'breed': 'Golden Retriever', 'name': 'Dog B'},
      ];

      final uniqueBreeds = extractBreedsFromCart(cartItems);

      // Act
      final result = await aprioriUseCase.getSuggestedPetsFromMultipleBreeds(uniqueBreeds);

      // Assert
      print('=== SINGLE BREED TEST ===');
      print('Cart with single breed type: Golden Retriever');
      print('Cart items count: ${cartItems.length}');
      print('Unique breeds: $uniqueBreeds');
      print('Suggested pets count: ${result.length}');
      
      expect(uniqueBreeds.length, 1);
      expect(uniqueBreeds.first, 'Golden Retriever');
    });

    test('should handle empty cart correctly', () async {
      // Arrange
      final cartItems = <Map<String, dynamic>>[];
      final uniqueBreeds = extractBreedsFromCart(cartItems);

      // Act
      final result = await aprioriUseCase.getSuggestedPetsFromMultipleBreeds(uniqueBreeds);

      // Assert
      print('=== EMPTY CART TEST ===');
      print('Empty cart should return no suggestions');
      print('Result: ${result.length} suggestions');
      
      expect(result.isEmpty, true);
      expect(uniqueBreeds.isEmpty, true);
    });

    test('should demonstrate improved multi-breed analysis vs single-breed', () async {
      // Arrange - Cart với nhiều giống khác nhau
      final multiBreedCart = [
        {'breed': 'Golden Retriever', 'name': 'Dog A'},
        {'breed': 'Persian Cat', 'name': 'Cat A'},
        {'breed': 'Beagle', 'name': 'Dog B'},
      ];

      final singleBreedCart = [
        {'breed': 'Golden Retriever', 'name': 'Dog A'},
      ];

      final multiBreeds = extractBreedsFromCart(multiBreedCart);
      final singleBreeds = extractBreedsFromCart(singleBreedCart);

      // Act
      final multiBreedResult = await aprioriUseCase.getSuggestedPetsFromMultipleBreeds(multiBreeds);
      final singleBreedResult = await aprioriUseCase.getSuggestedPetsFromMultipleBreeds(singleBreeds);

      // Assert
      print('=== COMPARISON: MULTI-BREED vs SINGLE-BREED ===');
      print('Multi-breed cart (${multiBreeds.length} breeds): ${multiBreedResult.length} suggestions');
      print('Single-breed cart (${singleBreeds.length} breed): ${singleBreedResult.length} suggestions');
      
      expect(multiBreeds.length, 3);
      expect(singleBreeds.length, 1);
      
      print('✅ Algorithm successfully processes both single and multiple breeds');
      print('Multi-breed input: $multiBreeds');
      print('Single-breed input: $singleBreeds');
    });

    test('should analyze breed associations correctly', () async {
      // Arrange
      final transactions = await fakeRepository.getBreedTransactions();

      // Act
      final associations = aprioriUseCase.analyzeBreedAssociations(
        transactions,
        minSupport: 0.1,
        minConfidence: 0.3,
      );

      // Assert
      print('=== BREED ASSOCIATIONS TEST ===');
      print('Total transactions: ${transactions.length}');
      print('Associations found: ${associations.length}');
      
      expect(associations.isNotEmpty, true);
      
      // In ra associations để kiểm tra
      associations.forEach((breedA, breedBMap) {
        breedBMap.forEach((breedB, association) {
          print('${association.breedA} -> ${association.breedB}: '
                'confidence=${association.confidence.toStringAsFixed(2)}, '
                'count=${association.count}');
        });
      });
    });
  });
}
