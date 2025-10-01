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
      for (final doc in allPetsSnapshot.docs) {
        final category = doc.data()['category']?.toString();
        if (category != null && category.isNotEmpty) {
          availableCategories.add(category);
        }
      }
      await RecommendationLogger.log('📊 Available categories in database: $availableCategories');
      
      // Get user preferences with comprehensive analysis
      final userPreferences = await _analyzeUserPreferences(request.userId);
      final favoriteCategories = userPreferences['favoriteCategories'] as List<String>;
      await RecommendationLogger.log('🎯 User preferences: $favoriteCategories');
      
      List<RecommendationItem> items = [];

      if (favoriteCategories.isNotEmpty) {
        print('🎯 User has preferences: $favoriteCategories');
        
        // Get category scores to determine priority order
        final categoryScores = userPreferences['categoryScores'] as Map<String, int>;
        final sortedCategories = categoryScores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)); // Sort by score descending
        
        print('🎯 Category scores sorted: ${sortedCategories.map((e) => '${e.key}: ${e.value}').toList()}');
        
        // Process top 2 categories based on actual preference scores
        for (final categoryEntry in sortedCategories.take(2)) {
          final category = categoryEntry.key;
          final score = categoryEntry.value;
          
          if (items.length >= request.limit) break;
          
          print('� Processing top category: $category (score: $score)');
          
          final snapshot = await firestore
              .collection('Pets')
              .where('category', isEqualTo: category)
              .limit((request.limit * 0.7).round()) // Give more slots to top categories
              .get();
          
          print('🔍 Found ${snapshot.docs.length} pets in $category category');
          
          for (final doc in snapshot.docs) {
            if (items.length >= request.limit) break;
            
            final data = doc.data();
            // Include ALL pets to show more variety (no exclusions for viewed pets)
            {
              // Score based on category preference strength
              final recommendationScore = score > 20 ? 0.95 : // Very high preference (Dogs: 29)
                                        score > 10 ? 0.85 : // High preference  
                                        score > 5 ? 0.75 :  // Medium preference
                                        0.65; // Lower preference (Birds: 2)
              
              final item = RecommendationItem(
                petId: doc.id,
                name: data['name'] ?? 'Unknown Pet',
                category: data['category'] ?? 'Unknown',
                breed: data['breed'] ?? 'Mixed',
                price: _parsePrice(data['price']),
                imageUrl: data['imageUrl'] ?? '',
                score: recommendationScore,
                reason: 'Dựa trên sở thích ${category.toLowerCase()} của bạn (điểm: $score)',
                type: RecommendationType.hybrid,
              );
              items.add(item);
              print('✅ Added ${category.toLowerCase()}: ${data['name']} (score: $recommendationScore)');
            }
          }
        }
        
        // Add some variety from other favorite categories
        for (String category in favoriteCategories.take(3)) {
          if (category != 'Birds' && items.length < request.limit) {
            final snapshot = await firestore
                .collection('Pets')
                .where('category', isEqualTo: category)
                .limit(3)
                .get();
            
            print('🔍 Searching category: $category, found: ${snapshot.docs.length} pets');
            
            for (final doc in snapshot.docs) {
              if (items.length >= request.limit) break;
              
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
                  score: 0.85, // High score for favorite categories
                  reason: 'Phù hợp với sở thích $category của bạn',
                  type: RecommendationType.hybrid,
                );
                items.add(item);
                print('✅ Added ${category}: ${data['name']} (${data['breed']})');
              }
            }
          }
        }
      }
      
      // Add more general recommendations from all categories
      final existingPetIds = items.map((item) => item.petId).toSet();
      
      final snapshot = await firestore
          .collection('Pets')
          .get(); // Get all pets, no limit
      
      for (final doc in snapshot.docs) {
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
        }
      }

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
      
      print('✅ Generated ${items.length} recommendations (${favoriteCategories.isNotEmpty ? "personalized" : "general"})');
      print('📄 Comprehensive analysis saved to: ${RecommendationLogger.getLogFilePath()}');
      
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
            score: 0.5, // Lower score for general recommendations
            reason: 'Khám phá thú cưng mới',
            type: RecommendationType.collaborative,
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
      // Get some pets for trending recommendations
      final snapshot = await firestore.collection('Pets').get(); // Get all pets
      
      List<RecommendationItem> items = [];
      for (final doc in snapshot.docs) {
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
      // Get some pets for association recommendations
      final snapshot = await firestore.collection('Pets').get(); // Get all pets
      
      List<RecommendationItem> items = [];
      for (final doc in snapshot.docs) {
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
            final weightedScore = (5 * recencyMultiplier).round();
            categoryCount[category] = (categoryCount[category] ?? 0) + weightedScore;
            print('💰 Purchased $category (${daysSinceOrder}d ago): +$weightedScore points');
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
              final createdAt = data['createdAt'] as Timestamp?;
              double recencyMultiplier = 1.0;
              if (createdAt != null) {
                final daysSinceFavorite = now.difference(createdAt.toDate()).inDays;
                recencyMultiplier = daysSinceFavorite <= 14 ? 1.3 : 
                                  daysSinceFavorite <= 30 ? 1.1 : 1.0;
              }
              
              if (category.isNotEmpty) {
                final weightedScore = (3 * recencyMultiplier).round();
                categoryCount[category] = (categoryCount[category] ?? 0) + weightedScore;
                print('💖 Favorited $category (${createdAt != null ? "${now.difference(createdAt.toDate()).inDays}d ago" : "no timestamp"}): +$weightedScore points');
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
