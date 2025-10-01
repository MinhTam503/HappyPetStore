import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/domain/repositories/recommendation_repository.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/recommendation_logger.dart';

class RecommendationRepositoryImpl implements RecommendationRepository {
  final FirebaseFirestore firestore;
  final UserManager userManager;
  
  RecommendationRepositoryImpl({
    required this.firestore,
    required this.userManager,
  });

  /// Helper function to safely parse price from Firestore data
  double _parsePrice(dynamic priceData) {
    if (priceData == null) return 0.0;
    
    if (priceData is num) {
      return priceData.toDouble();
    } else if (priceData is String) {
      return double.tryParse(priceData) ?? 0.0;
    }
    
    return 0.0;
  }
  
  @override
  Future<UserProfile> getUserProfile(String userId) async {
    return UserProfile.empty(userId);
  }
  
  @override
  Future<void> updateUserProfile(UserInteraction interaction) async {}
  
  @override
  Future<RecommendationResponse> getRecommendations(RecommendationRequest request) async {
    try {
      // Initialize comprehensive logging
      await RecommendationLogger.initialize();
      await RecommendationLogger.log('🎯 Getting recommendations for user: ${request.userId}');
      final startTime = DateTime.now();
      
      // Debug: Check what categories exist in database
      final allPetsSnapshot = await firestore.collection('Pets').limit(50).get();
      final availableCategories = <String>{};
      final availableBreeds = <String>{};
      for (final doc in allPetsSnapshot.docs) {
        final category = doc.data()['category']?.toString();
        final breed = doc.data()['breed']?.toString();
        if (category != null && category.isNotEmpty) {
          availableCategories.add(category);
        }
        if (breed != null && breed.isNotEmpty) {
          availableBreeds.add(breed);
        }
      }
      await RecommendationLogger.log('📊 Available categories in database: $availableCategories');
      await RecommendationLogger.log('🐕 Available breeds in database (sample): ${availableBreeds.take(10).toList()}');
      
      // Get user preferences with comprehensive analysis
      final userPreferences = await _analyzeUserPreferences(request.userId);
      final favoriteCategories = userPreferences['favoriteCategories'] as List<String>;
      await RecommendationLogger.log('🎯 User preferences: $favoriteCategories');
      
      List<RecommendationItem> items = [];

      if (favoriteCategories.isNotEmpty) {
        print('🎯 User has preferences - BREED-FIRST targeting approach');
        
        // Get preference scores for both categories and breeds
        final categoryScores = userPreferences['categoryScores'] as Map<String, int>;
        final breedScores = userPreferences['breedScores'] as Map<String, int>;
        final favoriteBreeds = userPreferences['favoriteBreeds'] as List<String>;
        
        print('🎯 Category scores: ${categoryScores.entries.map((e) => '${e.key}: ${e.value}').toList()}');
        print('🎯 Breed scores: ${breedScores.entries.map((e) => '${e.key}: ${e.value}').toList()}');
        
        // PHASE 1: BREED-SPECIFIC RECOMMENDATIONS (Dynamic threshold based on scores)
        if (favoriteBreeds.isNotEmpty) {
          // Calculate dynamic breed threshold - include breeds with score >= 60% of top breed
          final topBreedScore = breedScores.values.isNotEmpty ? breedScores.values.reduce((a, b) => a > b ? a : b) : 0;
          final threshold = (topBreedScore * 0.6).round(); // 60% threshold for better coverage
          
          final qualifiedBreeds = favoriteBreeds.where((breed) {
            final score = breedScores[breed] ?? 0;
            return score >= threshold;
          }).take(5).toList(); // Max 5 breeds for comprehensive targeting
          
          await RecommendationLogger.log('🎯 PHASE 1: Dynamic breed targeting (threshold: $threshold): $qualifiedBreeds');
          await RecommendationLogger.log('🚀 NO LIMITS MODE: Processing ALL breeds completely');
          
          for (final breed in qualifiedBreeds) { // Process ALL breeds completely
            final breedScore = breedScores[breed] ?? 0;
            
            await RecommendationLogger.log('🔍 SEARCHING for breed: "$breed" (score: $breedScore)');
            
            // NO LIMITS: Get ALL available pets for this breed
            await RecommendationLogger.log('� NO LIMITS: Fetching ALL pets for breed "$breed"');
            
            // Primary query: exact match - GET ALL pets (no limit)
            var breedSnapshot = await firestore
                .collection('Pets')
                .where('breed', isEqualTo: breed)
                .get(); // Removed .limit() to get ALL pets
            
            // Fallback query: case-insensitive for problematic breeds - GET ALL
            if (breedSnapshot.docs.isEmpty && (breed.contains('Golden') || breed.contains('Retriever'))) {
              await RecommendationLogger.log('🔄 FALLBACK: Trying lowercase for "$breed" - NO LIMITS');
              breedSnapshot = await firestore
                  .collection('Pets')
                  .where('breed', isEqualTo: breed.toLowerCase())
                  .get(); // No limit - get ALL
              
              if (breedSnapshot.docs.isEmpty) {
                await RecommendationLogger.log('🔄 FALLBACK: Trying capitalized for "$breed" - NO LIMITS');
                final capitalizedBreed = breed.split(' ').map((word) => 
                  word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ');
                breedSnapshot = await firestore
                    .collection('Pets')
                    .where('breed', isEqualTo: capitalizedBreed)
                    .get(); // No limit - get ALL
              }
            }
            
            print('🎯 BREED-SPECIFIC: "$breed" (score: $breedScore) -> ${breedSnapshot.docs.length} pets found');
            await RecommendationLogger.log('🎯 BREED-SPECIFIC: "$breed" -> ${breedSnapshot.docs.length} pets found in database');
            
            if (breedSnapshot.docs.isEmpty) {
              await RecommendationLogger.log('⚠️ NO PETS FOUND for breed: "$breed" - trying partial match - NO LIMITS');
              
              // Last resort: partial match for Golden Retriever - GET ALL
              if (breed.contains('Golden')) {
                final partialSnapshot = await firestore
                    .collection('Pets')
                    .where('breed', isGreaterThanOrEqualTo: 'Golden')
                    .where('breed', isLessThan: 'Golden\uf8ff')
                    .get(); // No limit - get ALL
                await RecommendationLogger.log('🔍 PARTIAL MATCH for "Golden": ${partialSnapshot.docs.length} pets found');
                if (partialSnapshot.docs.isNotEmpty) {
                  breedSnapshot = partialSnapshot;
                }
              }
            }
            
            // Add ALL pets from this breed (no limits)
            int petsAddedFromBreed = 0;
            for (final doc in breedSnapshot.docs) {
              // NO LIMITS: Add ALL pets from this breed
              final data = doc.data();
              
              // BREED TARGETING: Higher scores for specific breed matches
              final recommendationScore = breedScore > 15 ? 0.98 : // Very high breed preference
                                        breedScore > 10 ? 0.92 : // High breed preference  
                                        breedScore > 5 ? 0.85 :  // Medium breed preference
                                        0.75; // Lower breed preference
              
              final item = RecommendationItem(
                petId: doc.id,
                name: data['name'] ?? 'Unknown Pet',
                category: data['category'] ?? 'Unknown',
                breed: data['breed'] ?? 'Mixed',
                price: _parsePrice(data['price']),
                imageUrl: data['imageUrl'] ?? '',
                score: recommendationScore,
                reason: 'Chính xác giống "${breed}" bạn yêu thích (điểm breed: $breedScore)',
                type: RecommendationType.hybrid,
              );
              items.add(item);
              petsAddedFromBreed++;
              print('✅ BREED-MATCH: "${breed}" -> ${data['name']} (score: $recommendationScore)');
              await RecommendationLogger.log('✅ BREED-MATCH: "${breed}" -> ${data['name']} (score: $recommendationScore)');
            }
            
            await RecommendationLogger.log('📊 BREED SUMMARY: "$breed" -> Added ALL $petsAddedFromBreed pets (found ${breedSnapshot.docs.length} total in database)');
          }
        }
        
        // PHASE 2: CATEGORY-LEVEL RECOMMENDATIONS (Lower Priority)
        if (items.length < request.limit) {
          await RecommendationLogger.log('🎯 PHASE 2: Category-level recommendations for remaining slots');
          
          final sortedCategories = categoryScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          
          // Skip pets already recommended by breed
          final existingPetIds = items.map((item) => item.petId).toSet();
          
          // SMART CATEGORY FILTERING: Strongly prioritize breed matches
          final breedCategoriesUsed = items.map((item) => item.category).toSet();
          final hasGoodBreedMatches = items.where((item) => item.type == RecommendationType.hybrid && item.score > 0.8).length >= 2;
          
          final categoriesToSearch = sortedCategories
              .where((entry) => 
                (!breedCategoriesUsed.contains(entry.key) || !hasGoodBreedMatches) && // Skip same categories if we have good breed matches
                items.length < (request.limit * 0.9).round() // Only if we really need more
              )
              .take(hasGoodBreedMatches ? 0 : 1); // No category matches if we have 2+ good breed matches
          
          for (final categoryEntry in categoriesToSearch) {
            final category = categoryEntry.key;
            final score = categoryEntry.value;
            
            if (items.length >= request.limit) break;
            
            final snapshot = await firestore
                .collection('Pets')
                .where('category', isEqualTo: category)
                .limit(3) // Even fewer category-level recommendations
                .get();
            
            print('� CATEGORY-LEVEL: "$category" (score: $score) -> ${snapshot.docs.length} pets found');
            
            for (final doc in snapshot.docs) {
              if (items.length >= request.limit) break;
              if (existingPetIds.contains(doc.id)) continue; // Skip breed-specific duplicates
              
              final data = doc.data();
              
              // CATEGORY TARGETING: Much lower scores than breed-specific
              final recommendationScore = score > 20 ? 0.65 : // Reduced from 0.75
                                        score > 10 ? 0.55 : // Reduced from 0.65
                                        score > 5 ? 0.45 :  // Reduced from 0.55
                                        0.35; // Reduced from 0.45
              
              final item = RecommendationItem(
                petId: doc.id,
                name: data['name'] ?? 'Unknown Pet',
                category: data['category'] ?? 'Unknown',
                breed: data['breed'] ?? 'Mixed',
                price: _parsePrice(data['price']),
                imageUrl: data['imageUrl'] ?? '',
                score: recommendationScore,
                reason: 'Khám phá thêm trong danh mục ${category.toLowerCase()}',
                type: RecommendationType.hybrid,
              );
              items.add(item);
              existingPetIds.add(doc.id);
              print('✅ CATEGORY-MATCH: "${category}" -> ${data['name']} (score: $recommendationScore)');
            }
          }
        }
      }
      
      // Add limited general recommendations from various categories (like real recommendation systems)
      final existingPetIds = items.map((item) => item.petId).toSet();
      final remainingLimit = math.max(0, request.limit - items.length);
      
      if (remainingLimit > 0) {
        // Get diverse recommendations from different categories (not all pets)
        final categories = ['Dogs', 'Cats', 'Birds', 'Fish'];
        final itemsPerCategory = (remainingLimit / categories.length).ceil();
        
        for (final category in categories) {
          if (items.length >= request.limit) break;
          
          final snapshot = await firestore
              .collection('Pets')
              .where('category', isEqualTo: category)
              .limit(itemsPerCategory)
              .get();
          
          for (final doc in snapshot.docs) {
            if (items.length >= request.limit) break;
            if (existingPetIds.contains(doc.id)) continue;
            
            final data = doc.data();
            final isAlreadyViewed = await _isPetAlreadyInteractedWith(request.userId, doc.id);
            
            if (!isAlreadyViewed) {
              final item = RecommendationItem(
                petId: doc.id,
                name: data['name'] ?? 'Unknown Pet',
                category: data['category'] ?? 'Unknown',
                breed: data['breed'] ?? 'Mixed',
                price: _parsePrice(data['price']),
                imageUrl: data['imageUrl'] ?? '',
                score: 0.6, // Lower score for general recommendations
                reason: 'Khám phá thú cưng mới',
                type: RecommendationType.hybrid,
              );
              items.add(item);
              existingPetIds.add(doc.id);
            }
          }
        }
      }
      
      // Limit final results (like Netflix, Amazon)
      items = items.take(request.limit).toList();

      await RecommendationLogger.log('✅ Generated ${items.length} recommendations (${favoriteCategories.isNotEmpty ? "personalized" : "general"})');
      
      // Log comprehensive analysis
      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime).inMilliseconds;
      
      await RecommendationLogger.logPerformance({
        'Processing Time': '${processingTime}ms',
        'Total Recommendations': items.length,
        'User Has Preferences': favoriteCategories.isNotEmpty,
        'Categories Found': availableCategories.length,
      });
      
      // Log final recommendations
      final recommendationsData = items.map((item) => {
        'name': item.name,
        'category': item.category,
        'breed': item.breed,
        'score': item.score,
        'reason': item.reason,
        'type': item.type.toString(),
      }).toList();
      
      await RecommendationLogger.logRecommendations(recommendationsData);
      
      // Final analysis
      await RecommendationLogger.logConclusion({
        'userPreferences': favoriteCategories,
        'accuracy': favoriteCategories.isNotEmpty ? 'Personalized' : 'General',
        'improvements': [
          'Add more user interaction data',
          'Implement collaborative filtering',
          'Add price range preferences',
        ],
      });
      
      // Save analysis to workspace for easy access
      await RecommendationLogger.saveToWorkspace();
      
      // Create timestamped analysis file
      final analysisFilePath = await RecommendationLogger.createAnalysisFile();
      if (analysisFilePath != null) {
        print('📁 Complete analysis saved to: $analysisFilePath');
      }
      
      // Show file locations
      final filePaths = RecommendationLogger.getLogFilePaths();
      print('📂 Log file locations:');
      if (filePaths['appDocuments'] != null) {
        print('   • App Documents: ${filePaths['appDocuments']}');
      }
      if (filePaths['workspace'] != null) {
        print('   • Workspace: ${filePaths['workspace']}');
      }
      
      print('✅ Generated ${items.length} recommendations (${favoriteCategories.isNotEmpty ? "personalized" : "general"})');
      
      return RecommendationResponse(
        userId: request.userId,
        items: items,
        itemsByType: {RecommendationType.hybrid: items},
        generatedAt: DateTime.now(),
      );

    } catch (e) {
      print('❌ Error getting recommendations: $e');
      return RecommendationResponse(
        userId: request.userId,
        items: [],
        itemsByType: {},
        generatedAt: DateTime.now(),
      );
    }
  }
  
  @override
  Future<List<SimilarUser>> findSimilarUsers(String userId, {int? limit}) async {
    return [];
  }
  
  @override
  Future<List<RecommendationItem>> getContentBasedRecommendations(String userId, {int? limit}) async {
    try {
      // Analyze user preferences from multiple sources
      final userPreferences = await _analyzeUserPreferences(userId);
      
      // Get pets based on user preferences
      List<RecommendationItem> items = [];
      
      if (userPreferences['favoriteCategories'].isNotEmpty) {
        // Recommend pets from favorite categories
        final favoriteCategories = userPreferences['favoriteCategories'] as List<String>;
        
        for (String category in favoriteCategories.take(3)) {
          final snapshot = await firestore
              .collection('Pets')
              .where('category', isEqualTo: category)
              .get(); // Get all pets in this category
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final item = RecommendationItem(
              petId: doc.id,
              name: data['name'] ?? 'Unknown Pet',
              category: data['category'] ?? 'Unknown',
              breed: data['breed'] ?? 'Mixed',
              price: _parsePrice(data['price']),
              imageUrl: data['imageUrl'] ?? '',
              score: 0.9, // High score for category match
              reason: 'Dựa trên sở thích $category của bạn',
              type: RecommendationType.contentBased,
            );
            items.add(item);
          }
        }
      } else {
        // Fallback: get some general pets
        final snapshot = await firestore.collection('Pets').get(); // Get all pets
        
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final item = RecommendationItem(
            petId: doc.id,
            name: data['name'] ?? 'Unknown Pet',
            category: data['category'] ?? 'Unknown',
            breed: data['breed'] ?? 'Mixed',
            price: _parsePrice(data['price']),
            imageUrl: data['imageUrl'] ?? '',
            score: 0.6, // Lower score for general recommendations
            reason: 'Khám phá các loại thú cưng mới',
            type: RecommendationType.contentBased,
          );
          items.add(item);
        }
      }
      
      // Remove duplicates - no limit
      final uniqueItems = <String, RecommendationItem>{};
      for (final item in items) {
        uniqueItems[item.petId] = item;
      }
      
      final result = uniqueItems.values.toList(); // Return all unique items
      print('📝 Generated ${result.length} content-based recommendations based on preferences: ${userPreferences['favoriteCategories']}');
      return result;
    } catch (e) {
      print('❌ Error in content-based recommendations: $e');
      return [];
    }
  }
  
  @override
  Future<List<RecommendationItem>> getCollaborativeRecommendations(String userId, {int? limit}) async {
    try {
      // Get user preferences to find similar users
      final userPreferences = await _analyzeUserPreferences(userId);
      final userFavoriteCategories = userPreferences['favoriteCategories'] as List<String>;
      
      List<RecommendationItem> items = [];
      
      if (userFavoriteCategories.isNotEmpty) {
        // Find pets that other users with similar preferences liked
        // For each favorite category, get pets that are popular
        for (String category in userFavoriteCategories.take(2)) {
          final snapshot = await firestore
              .collection('Pets')
              .where('category', isEqualTo: category)
              .get(); // Get all pets in this category
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            
            // Skip if this pet is already in user's viewed or favorites
            final isAlreadyViewed = await _isPetAlreadyInteractedWith(userId, doc.id);
            if (!isAlreadyViewed) {
              final item = RecommendationItem(
                petId: doc.id,
                name: data['name'] ?? 'Unknown Pet',
                category: data['category'] ?? 'Unknown',
                breed: data['breed'] ?? 'Mixed',
                price: _parsePrice(data['price']),
                imageUrl: data['imageUrl'] ?? '',
                score: 0.8, // Good score for collaborative
                reason: 'Người có sở thích tương tự đã thích $category',
                type: RecommendationType.collaborative,
              );
              items.add(item);
            }
          }
        }
      } else {
        // Fallback: get limited general pets (like real systems)
        final categories = ['Dogs', 'Cats', 'Birds', 'Fish'];
        final limitPerCategory = math.max(1, (limit ?? 20) ~/ categories.length);
        
        for (final category in categories) {
          if (items.length >= (limit ?? 20)) break;
          
          final snapshot = await firestore
              .collection('Pets')
              .where('category', isEqualTo: category)
              .limit(limitPerCategory)
              .get();
          
          for (final doc in snapshot.docs) {
            if (items.length >= (limit ?? 20)) break;
            final data = doc.data();
            final item = RecommendationItem(
              petId: doc.id,
              name: data['name'] ?? 'Unknown Pet',
              category: data['category'] ?? 'Unknown',
              breed: data['breed'] ?? 'Mixed',
              price: _parsePrice(data['price']),
              imageUrl: data['imageUrl'] ?? '',
              score: 0.5, // Lower score for general recommendations
              reason: 'Khám phá thú cưng mới',
              type: RecommendationType.collaborative,
            );
            items.add(item);
          }
        }
      }
      
      // Remove duplicates and limit results (like Netflix, Amazon)
      final uniqueItems = <String, RecommendationItem>{};
      for (final item in items) {
        uniqueItems[item.petId] = item;
      }
      
      final result = uniqueItems.values.take(limit ?? 20).toList();
      print('🤝 Generated ${result.length} collaborative recommendations for categories: $userFavoriteCategories');
      return result;
    } catch (e) {
      print('❌ Error in collaborative recommendations: $e');
      return [];
    }
  }
  
  @override
  Future<List<RecommendationItem>> getTrendingPets({int? limit}) async {
    try {
      // Get diverse trending pets from different categories (like real systems)
      final categories = ['Dogs', 'Cats', 'Birds', 'Fish'];
      final limitPerCategory = math.max(1, (limit ?? 20) ~/ categories.length);
      
      List<RecommendationItem> items = [];
      for (final category in categories) {
        if (items.length >= (limit ?? 20)) break;
        
        final snapshot = await firestore
            .collection('Pets')
            .where('category', isEqualTo: category)
            .limit(limitPerCategory)
            .get();
        
        for (final doc in snapshot.docs) {
          if (items.length >= (limit ?? 20)) break;
          final data = doc.data();
          final item = RecommendationItem(
            petId: doc.id,
            name: data['name'] ?? 'Unknown Pet',
            category: data['category'] ?? 'Unknown',
            breed: data['breed'] ?? 'Mixed',
            price: _parsePrice(data['price']),
            imageUrl: data['imageUrl'] ?? '',
            score: 0.7, // Good score for trending
            reason: 'Đang được yêu thích',
            type: RecommendationType.trending,
          );
          items.add(item);
        }
      }
      
      print('📈 Generated ${items.length} trending recommendations');
      return items;
    } catch (e) {
      print('❌ Error in trending recommendations: $e');
      return [];
    }
  }
  
  @override
  Future<List<RecommendationItem>> getAssociationRecommendations(String userId, {int? limit}) async {
    try {
      // Get diverse association recommendations (like "customers who bought this also bought")
      final categories = ['Dogs', 'Cats', 'Birds', 'Fish'];
      final limitPerCategory = math.max(1, (limit ?? 20) ~/ categories.length);
      
      List<RecommendationItem> items = [];
      for (final category in categories) {
        if (items.length >= (limit ?? 20)) break;
        
        final snapshot = await firestore
            .collection('Pets')
            .where('category', isEqualTo: category)
            .limit(limitPerCategory)
            .get();
        
        for (final doc in snapshot.docs) {
          if (items.length >= (limit ?? 20)) break;
          final data = doc.data();
          final item = RecommendationItem(
            petId: doc.id,
            name: data['name'] ?? 'Unknown Pet',
            category: data['category'] ?? 'Unknown',
            breed: data['breed'] ?? 'Mixed',
            price: _parsePrice(data['price']),
            imageUrl: data['imageUrl'] ?? '',
            score: 0.6, // Decent score for association
            reason: 'Thường được mua cùng nhau',
            type: RecommendationType.association,
          );
          items.add(item);
        }
      }
      
      print('🔗 Generated ${items.length} association recommendations');
      return items;
    } catch (e) {
      print('❌ Error in association recommendations: $e');
      return [];
    }
  }
  
  @override
  Future<void> trackInteraction(UserInteraction interaction) async {}
  
  @override
  Future<List<UserInteraction>> getUserInteractions(String userId, {int limit = 100, DateTime? since}) async {
    return [];
  }
  
  @override
  Future<List<Map<String, dynamic>>> getPetsByIds(List<String> petIds) async {
    return [];
  }

  /// Public method to analyze user preferences (for debugging/analytics)
  Future<Map<String, dynamic>> analyzeUserPreferences(String userId) async {
    return await _analyzeUserPreferences(userId);
  }

  /// Analyze user preferences from multiple data sources including Orders
  Future<Map<String, dynamic>> _analyzeUserPreferences(String userId) async {
    try {
      print('🔍 Analyzing user preferences for: $userId');
      
      // Get user orders (HIGHEST priority)
      final ordersSnapshot = await firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      // Get user viewed pets
      final viewedPetsSnapshot = await firestore
          .collection('ViewedPets')
          .doc(userId)
          .collection('pets')
          .orderBy('viewedAtMillis', descending: true)
          .limit(20)
          .get();
      
      // Get user favorites
      final favoritesDoc = await firestore
          .collection('favorites')
          .doc(userId)
          .get();
      
      // Process favorites from the document field
      final favoritesItems = favoritesDoc.exists 
          ? (favoritesDoc.data()?['items'] as List<dynamic>?) ?? []
          : [];
      
      // Get search history
      final searchHistorySnapshot = await firestore
          .collection('SearchHistory')
          .doc(userId)
          .collection('searches')
          .orderBy('searchedAtMillis', descending: true)
          .limit(20)
          .get();
      
      // Analyze categories with weighted scoring and recency
      Map<String, int> categoryCount = {};
      Map<String, int> breedCount = {};
      final now = DateTime.now();
      
      // 1. ORDERS (Highest weight + recency bonus)
      print('� Orders: ${ordersSnapshot.docs.length}');
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        // Calculate recency bonus
        final daysSinceOrder = timestamp != null ? now.difference(timestamp).inDays : 365;
        final recencyMultiplier = daysSinceOrder <= 30 ? 2.0 : 
                                daysSinceOrder <= 90 ? 1.5 : 1.0;
        
        for (final item in items) {
          final itemData = item as Map<String, dynamic>;
          final category = itemData['category']?.toString() ?? '';
          final breed = itemData['breed']?.toString() ?? '';
          
          if (category.isNotEmpty) {
            // Smart hybrid scoring: 70% repeat, 30% discovery
            final baseScore = (5 * recencyMultiplier).round();
            final repeatScore = (baseScore * 0.7).round(); // Favor same category
            final discoveryBonus = (baseScore * 0.3).round(); // Discovery for other categories
            
            categoryCount[category] = (categoryCount[category] ?? 0) + repeatScore;
            print('💰 Purchased $category (${daysSinceOrder}d ago): +$repeatScore points (repeat preference)');
            
            // Add small discovery bonus to other categories
            final allCategories = ['Birds', 'Dogs', 'Cats', 'Fish'];
            for (final otherCategory in allCategories) {
              if (otherCategory != category) {
                categoryCount[otherCategory] = (categoryCount[otherCategory] ?? 0) + (discoveryBonus ~/ 3);
              }
            }
          }
          if (breed.isNotEmpty) {
            final weightedScore = (5 * recencyMultiplier).round();
            breedCount[breed] = (breedCount[breed] ?? 0) + weightedScore;
          }
        }
      }
      
      // 2. VIEWED PETS (Medium weight)
      print('👀 Viewed pets: ${viewedPetsSnapshot.docs.length}');
      for (final doc in viewedPetsSnapshot.docs) {
        final data = doc.data();
        final category = data['category']?.toString() ?? '';
        final breed = data['breed']?.toString() ?? '';
        final viewedAtMillis = data['viewedAtMillis'] as int?;
        
        // Calculate recency bonus for views
        final viewedAt = viewedAtMillis != null 
            ? DateTime.fromMillisecondsSinceEpoch(viewedAtMillis)
            : DateTime.now().subtract(Duration(days: 30));
        final daysSinceView = now.difference(viewedAt).inDays;
        final recencyMultiplier = daysSinceView <= 7 ? 1.5 : 
                                daysSinceView <= 14 ? 1.2 : 1.0;
        
        if (category.isNotEmpty) {
          final weightedScore = (2 * recencyMultiplier).round();
          categoryCount[category] = (categoryCount[category] ?? 0) + weightedScore;
        }
        if (breed.isNotEmpty) {
          final weightedScore = (2 * recencyMultiplier).round();
          breedCount[breed] = (breedCount[breed] ?? 0) + weightedScore;
        }
      }
      
      // 3. FAVORITES (High weight with createdAt support)
      print('� Favorites: ${favoritesItems.length}');
      for (final item in favoritesItems) {
        final data = item as Map<String, dynamic>;
        
        // Get pet details from Pets collection to get category
        final petId = data['productId']?.toString() ?? '';
        if (petId.isNotEmpty) {
          try {
            final petDoc = await firestore.collection('Pets').doc(petId).get();
            if (petDoc.exists) {
              final petData = petDoc.data()!;
              final category = petData['category']?.toString() ?? '';
              final breed = petData['breed']?.toString() ?? '';
              
              // Calculate recency bonus for favorites (with createdAt support)
              dynamic createdAtRaw = data['createdAt'];
              DateTime? createdAtDate;
              
              // Handle both Timestamp and String formats
              if (createdAtRaw is Timestamp) {
                createdAtDate = createdAtRaw.toDate();
              } else if (createdAtRaw is String) {
                try {
                  createdAtDate = DateTime.parse(createdAtRaw);
                } catch (e) {
                  print('⚠️ Invalid createdAt format: $createdAtRaw');
                  createdAtDate = null;
                }
              }
              
              double recencyMultiplier = 1.0;
              if (createdAtDate != null) {
                final daysSinceFavorite = now.difference(createdAtDate).inDays;
                recencyMultiplier = daysSinceFavorite <= 14 ? 1.3 : 
                                  daysSinceFavorite <= 30 ? 1.1 : 1.0;
              }
              
              if (category.isNotEmpty) {
                final weightedScore = (3 * recencyMultiplier).round();
                categoryCount[category] = (categoryCount[category] ?? 0) + weightedScore;
                print('💖 Favorited $category (${createdAtDate != null ? "${now.difference(createdAtDate).inDays}d ago" : "no timestamp"}): +$weightedScore points');
              }
              if (breed.isNotEmpty) {
                final weightedScore = (3 * recencyMultiplier).round();
                breedCount[breed] = (breedCount[breed] ?? 0) + weightedScore;
              }
            }
          } catch (e) {
            print('Error fetching pet details for favorite: $e');
          }
        }
      }
      
      // 4. SEARCH HISTORY (Lower weight)
      print('� Search history: ${searchHistorySnapshot.docs.length}');
      for (final doc in searchHistorySnapshot.docs) {
        final data = doc.data();
        final query = data['query']?.toString().toLowerCase() ?? '';
        
        // Analyze search terms for categories
        if (query.contains('chó') || query.contains('dog')) {
          categoryCount['Dogs'] = (categoryCount['Dogs'] ?? 0) + 1;
        }
        if (query.contains('mèo') || query.contains('cat')) {
          categoryCount['Cats'] = (categoryCount['Cats'] ?? 0) + 1;
        }
        if (query.contains('chim') || query.contains('bird')) {
          categoryCount['Birds'] = (categoryCount['Birds'] ?? 0) + 1;
        }
        if (query.contains('cá') || query.contains('fish')) {
          categoryCount['Fish'] = (categoryCount['Fish'] ?? 0) + 1;
        }
        if (query.contains('thỏ') || query.contains('rabbit')) {
          categoryCount['Rabbits'] = (categoryCount['Rabbits'] ?? 0) + 1;
        }
      }
      
      // Sort categories by preference count
      final sortedCategories = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final sortedBreeds = breedCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final favoriteCategories = sortedCategories.map((e) => e.key).toList();
      final favoriteBreeds = sortedBreeds.map((e) => e.key).toList();
      
      print('🎯 User preferences:');
      print('   Favorite categories: $favoriteCategories');
      print('   Category counts: $categoryCount');
      print('   Favorite breeds: $favoriteBreeds');
      
      return {
        'favoriteCategories': favoriteCategories,
        'favoriteBreeds': favoriteBreeds,
        'categoryScores': categoryCount,
        'breedScores': breedCount,
      };
    } catch (e) {
      print('❌ Error analyzing user preferences: $e');
      return {
        'favoriteCategories': <String>[],
        'favoriteBreeds': <String>[],
        'categoryScores': <String, int>{},
        'breedScores': <String, int>{},
      };
    }
  }

  /// Check if user has already interacted with this pet (viewed or favorited)
  Future<bool> _isPetAlreadyInteractedWith(String userId, String petId) async {
    try {
      // Check if pet is in viewed pets
      final viewedDoc = await firestore
          .collection('ViewedPets')
          .doc(userId)
          .collection('pets')
          .doc(petId)
          .get();
      
      if (viewedDoc.exists) return true;
      
      // Check if pet is in favorites
      final favSnapshot = await firestore
          .collection('UserFav')
          .doc(userId)
          .collection('favorites')
          .where('productId', isEqualTo: petId)
          .limit(1)
          .get();
      
      return favSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking pet interaction: $e');
      return false;
    }
  }
}
