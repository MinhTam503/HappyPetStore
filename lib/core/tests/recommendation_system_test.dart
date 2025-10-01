import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/data/repositories/recommendation_repository_impl.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/recommendation_logger.dart';
import 'package:pet_shop/core/utils/favorites_helper.dart';
import 'dart:io';

/// Comprehensive test script for recommendation system analysis
class RecommendationSystemTest {
  final FirebaseFirestore firestore;
  final RecommendationRepositoryImpl repository;
  final FavoritesHelper favoritesHelper;
  
  RecommendationSystemTest()
      : firestore = FirebaseFirestore.instance,
        repository = RecommendationRepositoryImpl(
          firestore: FirebaseFirestore.instance,
          userManager: UserManager(),
        ),
        favoritesHelper = FavoritesHelper(firestore: FirebaseFirestore.instance);
  
  /// Run comprehensive test with the target user
  Future<void> runComprehensiveTest(String userId) async {
    try {
      print('🚀 Starting comprehensive recommendation system test...');
      
      // Step 1: Migrate favorites to include createdAt
      await _migrateFavorites();
      
      // Step 2: Add test favorite with timestamp to demonstrate new feature
      await _addTestFavoriteWithTimestamp(userId);
      
      // Step 3: Run recommendation analysis
      await _runRecommendationAnalysis(userId);
      
      // Step 4: Read and display the log file
      await _displayLogFile();
      
      print('✅ Comprehensive test completed successfully!');
      
    } catch (e) {
      print('❌ Error during comprehensive test: $e');
    }
  }
  
  /// Migrate existing favorites to include createdAt
  Future<void> _migrateFavorites() async {
    print('\n📝 Step 1: Migrating favorites to include createdAt timestamp...');
    await favoritesHelper.migrateFavoritesToIncludeTimestamp();
  }
  
  /// Add a test favorite with createdAt to demonstrate new feature
  Future<void> _addTestFavoriteWithTimestamp(String userId) async {
    print('\n📝 Step 2: Adding test favorite with createdAt timestamp...');
    
    try {
      await favoritesHelper.addToFavorites(
        userId: userId,
        productId: 'test_pet_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Dog with Timestamp',
        category: 'Dogs',
        breed: 'Golden Retriever',
        price: 15000000,
        imageUrl: 'https://example.com/test-dog.jpg',
      );
      
      print('✅ Test favorite added with createdAt timestamp');
    } catch (e) {
      print('⚠️  Could not add test favorite: $e');
    }
  }
  
  /// Run the recommendation analysis
  Future<void> _runRecommendationAnalysis(String userId) async {
    print('\n📝 Step 3: Running recommendation analysis...');
    
    final request = RecommendationRequest(
      userId: userId,
      limit: 20,
    );
    
    // Get recommendations with comprehensive logging
    final response = await repository.getRecommendations(request);
    
    print('✅ Recommendation analysis completed');
    print('📊 Generated ${response.items.length} recommendations');
  }
  
  /// Display the contents of the log file
  Future<void> _displayLogFile() async {
    print('\n📝 Step 4: Reading comprehensive analysis log...');
    
    final logFilePath = RecommendationLogger.getLogFilePath();
    if (logFilePath != null) {
      try {
        final logFile = File(logFilePath);
        if (await logFile.exists()) {
          final contents = await logFile.readAsString();
          
          print('\n' + '=' * 80);
          print('📄 COMPREHENSIVE ANALYSIS RESULTS');
          print('=' * 80);
          print(contents);
          print('=' * 80);
          print('📍 Full analysis saved to: $logFilePath');
        } else {
          print('❌ Log file not found at: $logFilePath');
        }
      } catch (e) {
        print('❌ Error reading log file: $e');
      }
    } else {
      print('❌ Log file path is null');
    }
  }
}

/// Main test runner
Future<void> testRecommendationSystem() async {
  const String testUserId = 'MPG1Pq1rIjdFxi5fgsrWkisKeOJ3';
  
  final test = RecommendationSystemTest();
  await test.runComprehensiveTest(testUserId);
}