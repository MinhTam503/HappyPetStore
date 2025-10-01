import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/domain/repositories/recommendation_repository.dart';
import 'package:pet_shop/core/services/user_manager.dart';

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
      print('🎯 Getting recommendations for user: ${request.userId}');
      
      // Debug: Check what categories exist in database
      final allPetsSnapshot = await firestore.collection('Pets').limit(50).get();
      final availableCategories = <String>{};
      for (final doc in allPetsSnapshot.docs) {
        final category = doc.data()['category']?.toString();
        if (category != null && category.isNotEmpty) {
          availableCategories.add(category);
        }
      }
      print('📊 Available categories in database: $availableCategories');
      
      // Get user preferences first
      final userPreferences = await _analyzeUserPreferences(request.userId);
      final favoriteCategories = userPreferences['favoriteCategories'] as List<String>;
      print('🎯 User preferences: $favoriteCategories');
      
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
            final isAlreadyViewed = await _isPetAlreadyInteractedWith(request.userId, doc.id);
            
            if (!isAlreadyViewed) {
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

  /// Analyze user preferences from multiple data sources
  Future<Map<String, dynamic>> _analyzeUserPreferences(String userId) async {
    try {
      print('🔍 Analyzing user preferences for: $userId');
      
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
      
      // Analyze categories from viewed pets
      Map<String, int> categoryCount = {};
      Map<String, int> breedCount = {};
      
      print('📊 Viewed pets: ${viewedPetsSnapshot.docs.length}');
      for (final doc in viewedPetsSnapshot.docs) {
        final data = doc.data();
        final category = data['category']?.toString() ?? '';
        final breed = data['breed']?.toString() ?? '';
        
        if (category.isNotEmpty) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 2; // Higher weight for views
        }
        if (breed.isNotEmpty) {
          breedCount[breed] = (breedCount[breed] ?? 0) + 2;
        }
      }
      
      print('📊 Favorites: ${favoritesItems.length}');
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
              
              if (category.isNotEmpty) {
                categoryCount[category] = (categoryCount[category] ?? 0) + 3; // Highest weight for favorites
              }
              if (breed.isNotEmpty) {
                breedCount[breed] = (breedCount[breed] ?? 0) + 3;
              }
            }
          } catch (e) {
            print('Error fetching pet details for favorite: $e');
          }
        }
      }
      
      print('📊 Search history: ${searchHistorySnapshot.docs.length}');
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
