import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/domain/repositories/recommendation_repository.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/services/recommendation_logger.dart';
import 'package:pet_shop/core/config/recommendation_config.dart';

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
  //=========================================================================================
  // Personalized BREED-FIRST
  @override
  Future<RecommendationResponse> getRecommendations(
      RecommendationRequest request) async {
    try {
      // Content-based only with detailed logging
      // Ensure logger is initialized in per-user mode and does not downgrade file selection
      await RecommendationLogger.initialize(
        userId: request.userId,
        perUserFile: true,
        clearExisting: false,
      );
      final sessionId = await RecommendationLogger.logSessionStart(
        userId: request.userId,
        requestedTypes: request.types ?? [RecommendationType.contentBased],
        limit: request.limit,
        additionalData: {
          'mode': 'content-only',
        },
      );

      final totalStart = DateTime.now();

      // Content-based only: compute preferences and return matched pets
      final items = await getContentBasedRecommendations(
        request.userId,
        limit: request.limit,
      );

      final totalTime = DateTime.now().difference(totalStart);
      await RecommendationLogger.logSessionComplete(
        sessionId: sessionId,
        finalRecommendations: items,
        totalTime: totalTime,
        performanceMetrics: {
          'algorithm': 'contentBased',
          'resultCount': items.length,
        },
      );

      return RecommendationResponse(
        userId: request.userId,
        items: items,
        itemsByType: {RecommendationType.contentBased: items},
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
  Future<List<SimilarUser>> findSimilarUsers(String userId,
      {int? limit}) async {
    return [];
  }

  //------------------------------------------------------------------//
  // content-based filtering
  @override
  Future<List<RecommendationItem>> getContentBasedRecommendations(String userId,
      {int? limit}) async {
    try {
  final algoStart = DateTime.now();
      // Analyze user preferences from multiple sources
      final userPreferences = await _analyzeUserPreferences(userId);
    final favoriteCategories =
      (userPreferences['favoriteCategories'] as List<String>?) ?? [];
    final favoriteBreeds =
      (userPreferences['favoriteBreeds'] as List<String>?) ?? [];

      // Log preferences fetch
      await RecommendationLogger.logDataFetching(
        sessionId: 'content_only',
        dataType: 'userPreferences',
        count: favoriteCategories.length,
        fetchTime: DateTime.now().difference(algoStart),
      );

  // Get pets based on user preferences
      List<RecommendationItem> items = [];
  final effectiveLimit = limit ?? RecommendationConfig.defaultLimit;

      if (favoriteCategories.isNotEmpty) {
        // Recommend pets from favorite categories
        final takeCategories = favoriteCategories.take(3).toList();
  final perCategory = math.max(1, (effectiveLimit) ~/ takeCategories.length);

        for (String category in takeCategories) {
          final addedIds = <String>{};
          // 1) Breed-first within this category (if any favorite breeds exist)
          final topBreeds = favoriteBreeds.take(3).toList();
          if (topBreeds.isNotEmpty) {
            // Distribute some of perCategory to breed-focused picks
            final breedQuota = RecommendationConfig.strictBreed
                ? perCategory
                : math.max(1, (perCategory * (1.0 - RecommendationConfig.exploreRatio)).round());
            final perBreedLimit = math.max(1, breedQuota ~/ topBreeds.length);

            for (final breed in topBreeds) {
              final breedFetchStart = DateTime.now();
              final breedSnapshot = await firestore
                  .collection('Pets')
                  .where('category', isEqualTo: category)
                  .where('breed', isEqualTo: breed)
                  .limit(perBreedLimit)
                  .get();

              await RecommendationLogger.logDataFetching(
                sessionId: 'content_only',
                dataType: 'PetsByBreed:$breed',
                count: breedSnapshot.docs.length,
                fetchTime: DateTime.now().difference(breedFetchStart),
              );

              for (final doc in breedSnapshot.docs) {
                if (addedIds.contains(doc.id)) continue;
                final data = doc.data();
                items.add(RecommendationItem(
                  petId: doc.id,
                  name: data['name'] ?? 'Unknown Pet',
                  category: data['category'] ?? 'Unknown',
                  breed: data['breed'] ?? 'Mixed',
                  price: _parsePrice(data['price']),
                  imageUrl: data['imageUrl'] ?? '',
                  score: 1.0, // Highest score for breed match
                  reason: 'Dựa trên giống ${data['breed'] ?? breed} bạn quan tâm',
                  type: RecommendationType.contentBased,
                ));
                addedIds.add(doc.id);
                if (addedIds.length >= breedQuota) break;
              }
              if (addedIds.length >= breedQuota) break;
            }
          }

          // 2) Fill remaining from category (skip if strictBreed)
          final remaining = RecommendationConfig.strictBreed ? 0 : (perCategory - addedIds.length);
          if (remaining > 0) {
            final fetchStart = DateTime.now();
            final snapshot = await firestore
                .collection('Pets')
                .where('category', isEqualTo: category)
                .limit(math.max(remaining, perCategory)) // fetch extra to offset dups
                .get();

            await RecommendationLogger.logDataFetching(
              sessionId: 'content_only',
              dataType: 'PetsByCategory:$category',
              count: snapshot.docs.length,
              fetchTime: DateTime.now().difference(fetchStart),
            );

            for (final doc in snapshot.docs) {
              if (addedIds.contains(doc.id)) continue;
              final data = doc.data();
              items.add(RecommendationItem(
                petId: doc.id,
                name: data['name'] ?? 'Unknown Pet',
                category: data['category'] ?? 'Unknown',
                breed: data['breed'] ?? 'Mixed',
                price: _parsePrice(data['price']),
                imageUrl: data['imageUrl'] ?? '',
                score: 0.9, // High score for category match
                reason: 'Dựa trên sở thích $category của bạn',
                type: RecommendationType.contentBased,
              ));
              addedIds.add(doc.id);
              if (addedIds.length >= perCategory) break;
            }
          }
        }
      } else {
        // Fallback: get some general pets
        final fetchStart = DateTime.now();
    final snapshot = await firestore
            .collection('Pets')
      .limit(effectiveLimit)
            .get(); // Limit total

        await RecommendationLogger.logDataFetching(
          sessionId: 'content_only',
          dataType: 'GeneralPets',
          count: snapshot.docs.length,
          fetchTime: DateTime.now().difference(fetchStart),
        );

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final item = RecommendationItem(
            petId: doc.id,
            name: data['name'] ?? 'Unknown Pet',
            category: data['category'] ?? 'Unknown',
            breed: data['breed'] ?? 'Mixed',
            price: _parsePrice(data['price']),
            imageUrl: data['imageUrl'] ?? '',
            score: 0.6, // Lower score for general content-based fallback
            reason: 'Khám phá các loại thú cưng mới',
            type: RecommendationType.contentBased,
          );
          items.add(item);
        }
      }

      // Remove duplicates - keep highest score when duplicate IDs appear
      final uniqueItems = <String, RecommendationItem>{};
      for (final item in items) {
        final existing = uniqueItems[item.petId];
        if (existing == null || item.score > existing.score) {
          uniqueItems[item.petId] = item;
        }
      }

      // Sort by score descending so breed-first (score=1.0) surfaces ahead of pure category (score=0.9)
      final result = uniqueItems.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      // Respect limit
      if (result.length > effectiveLimit) {
        result.removeRange(effectiveLimit, result.length);
      }

      // Log algorithm execution
      await RecommendationLogger.logAlgorithmExecution(
        sessionId: 'content_only',
        algorithmType: RecommendationType.contentBased,
        inputCount: favoriteCategories.isEmpty
            ? 1
            : (favoriteCategories.take(3).length + favoriteBreeds.take(3).length),
        outputCount: result.length,
        executionTime: DateTime.now().difference(algoStart),
        weights: {
          'categoryPriority': 1.0,
          'breedPriority': 1.2,
        },
      );
      print(
          '📝 Generated ${result.length} content-based recommendations based on preferences: ${userPreferences['favoriteCategories']}');
      return result;
    } catch (e) {
      print('❌ Error in content-based recommendations: $e');
      return [];
    }
  }

  //==============================================================
  // collaborative Filtering
  @override
  Future<List<RecommendationItem>> getCollaborativeRecommendations(
      String userId,
      {int? limit}) async {
    // Simplified: route to content-based
    return getContentBasedRecommendations(userId, limit: limit);
  }

  //=========================================================================
  // Trending analysis
  @override
  Future<List<RecommendationItem>> getTrendingPets({int? limit}) async {
    // Simplified: route to content-based with generic fallback
    return getContentBasedRecommendations('anonymous', limit: limit);
  }

  @override
  Future<List<RecommendationItem>> getAssociationRecommendations(String userId,
      {int? limit}) async {
    // Simplified: route to content-based
    return getContentBasedRecommendations(userId, limit: limit);
  }

  @override
  Future<void> trackInteraction(UserInteraction interaction) async {}

  @override
  Future<List<UserInteraction>> getUserInteractions(String userId,
      {int limit = 100, DateTime? since}) async {
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
      final favoritesDoc =
          await firestore.collection('favorites').doc(userId).get();

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
      print('📦 Orders: ${ordersSnapshot.docs.length}');
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

        // Calculate recency bonus
        final daysSinceOrder =
            timestamp != null ? now.difference(timestamp).inDays : 365;
        final recencyMultiplier = daysSinceOrder <= 30
            ? 2.0
            : daysSinceOrder <= 90
                ? 1.5
                : 1.0;

        for (final item in items) {
          final itemData = item as Map<String, dynamic>;
          final category = itemData['category']?.toString() ?? '';
          final breed = itemData['breed']?.toString() ?? '';

          if (category.isNotEmpty) {
            // Smart hybrid scoring: 70% repeat, 30% discovery
            final baseScore = (5 * recencyMultiplier).round();
            final repeatScore =
                (baseScore * 0.7).round(); // Favor same category
            final discoveryBonus =
                (baseScore * 0.3).round(); // Discovery for other categories

            categoryCount[category] =
                (categoryCount[category] ?? 0) + repeatScore;
            print(
                '💰 Purchased $category (${daysSinceOrder}d ago): +$repeatScore points (repeat preference)');

            // Add small discovery bonus to other categories
            final allCategories = ['Birds', 'Dogs', 'Cats', 'Fish'];
            for (final otherCategory in allCategories) {
              if (otherCategory != category) {
                categoryCount[otherCategory] =
                    (categoryCount[otherCategory] ?? 0) + (discoveryBonus ~/ 3);
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
        final recencyMultiplier = daysSinceView <= 7
            ? 1.5
            : daysSinceView <= 14
                ? 1.2
                : 1.0;

        if (category.isNotEmpty) {
          final weightedScore = (2 * recencyMultiplier).round();
          categoryCount[category] =
              (categoryCount[category] ?? 0) + weightedScore;
        }
        if (breed.isNotEmpty) {
          final weightedScore = (2 * recencyMultiplier).round();
          breedCount[breed] = (breedCount[breed] ?? 0) + weightedScore;
        }
      }

      // 3. FAVORITES (High weight with createdAt support)
      print('❤️ Favorites: ${favoritesItems.length}');
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
                recencyMultiplier = daysSinceFavorite <= 14
                    ? 1.3
                    : daysSinceFavorite <= 30
                        ? 1.1
                        : 1.0;
              }

              if (category.isNotEmpty) {
                final weightedScore = (3 * recencyMultiplier).round();
                categoryCount[category] =
                    (categoryCount[category] ?? 0) + weightedScore;
                print(
                    '💖 Favorited $category (${createdAtDate != null ? "${now.difference(createdAtDate).inDays}d ago" : "no timestamp"}): +$weightedScore points');
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
      print('🔍 Search history: ${searchHistorySnapshot.docs.length}');
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

  // Removed interaction check in simplified mode
}
