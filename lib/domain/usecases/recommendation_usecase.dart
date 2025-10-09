import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/domain/repositories/recommendation_repository.dart';

/// Use case for handling all recommendation operations
class RecommendationUseCase {
  final RecommendationRepository _repository;

  RecommendationUseCase(this._repository);

  /// Get personalized recommendations for user
  Future<RecommendationResponse> getPersonalizedRecommendations({
    required String userId,
    int limit = 10,
    List<RecommendationType>? types,
  }) async {
    try {
      final request = RecommendationRequest(
        userId: userId,
        limit: limit,
        types: types,
      );
      
      return await _repository.getRecommendations(request);
    } catch (e) {
      throw Exception('Failed to get personalized recommendations: $e');
    }
  }
//==========================================================
  /// Get hybrid recommendations combining multiple algorithms
  Future<List<RecommendationItem>> getHybridRecommendations({
    required String userId,
    int limit = 10,
  }) async {
    try {
      // Get different types of recommendations
      final contentBased = await _repository.getContentBasedRecommendations(
        userId,
        limit: (limit * 0.4).round(), // 40%
      );
      
      final collaborative = await _repository.getCollaborativeRecommendations(
        userId,
        limit: (limit * 0.3).round(), // 30%
      );
      
      final trending = await _repository.getTrendingPets(
        limit: (limit * 0.2).round(), // 20%
      );
      
      final association = await _repository.getAssociationRecommendations(
        userId,
        limit: (limit * 0.1).round(), // 10%
      );

      // Combine and deduplicate
      final allRecommendations = <RecommendationItem>[];
      final seenPetIds = <String>{};

      // Add recommendations with priority
      for (final item in contentBased) {
        if (!seenPetIds.contains(item.petId)) {
          allRecommendations.add(item);
          seenPetIds.add(item.petId);
        }
      }

      for (final item in collaborative) {
        if (!seenPetIds.contains(item.petId) && allRecommendations.length < limit) {
          allRecommendations.add(item);
          seenPetIds.add(item.petId);
        }
      }

      for (final item in trending) {
        if (!seenPetIds.contains(item.petId) && allRecommendations.length < limit) {
          allRecommendations.add(item);
          seenPetIds.add(item.petId);
        }
      }

      for (final item in association) {
        if (!seenPetIds.contains(item.petId) && allRecommendations.length < limit) {
          allRecommendations.add(item);
          seenPetIds.add(item.petId);
        }
      }

      // Sort by score and return top items
      allRecommendations.sort((a, b) => b.score.compareTo(a.score));
      return allRecommendations.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get hybrid recommendations: $e');
    }
  }

  /// Track user interaction for improving recommendations
  Future<void> trackUserInteraction({
    required String userId,
    required String petId,
    required InteractionType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final interaction = UserInteraction(
        userId: userId,
        petId: petId,
        type: type,
        timestamp: DateTime.now(),
        weight: type.weight,
        metadata: metadata,
      );

      await _repository.trackInteraction(interaction);
      await _repository.updateUserProfile(interaction);
    } catch (e) {
      throw Exception('Failed to track user interaction: $e');
    }
  }

  /// Get user profile and preferences
  Future<UserProfile> getUserProfile(String userId) async {
    try {
      return await _repository.getUserProfile(userId);
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  /// Get recommendations by specific type
  Future<List<RecommendationItem>> getRecommendationsByType({
    required String userId,
    required RecommendationType type,
    int limit = 10,
  }) async {
    try {
      switch (type) {
        case RecommendationType.contentBased:
          return await _repository.getContentBasedRecommendations(userId, limit: limit);
        case RecommendationType.collaborative:
          return await _repository.getCollaborativeRecommendations(userId, limit: limit);
        case RecommendationType.trending:
          return await _repository.getTrendingPets(limit: limit);
        case RecommendationType.association:
          return await _repository.getAssociationRecommendations(userId, limit: limit);
        case RecommendationType.hybrid:
          return await getHybridRecommendations(userId: userId, limit: limit);
        case RecommendationType.personalized:
          final response = await getPersonalizedRecommendations(userId: userId, limit: limit);
          return response.items;
      }
    } catch (e) {
      throw Exception('Failed to get recommendations by type: $e');
    }
  }

  /// Get similar users for collaborative filtering insights
  Future<List<SimilarUser>> getSimilarUsers({
    required String userId,
    int limit = 10,
  }) async {
    try {
      return await _repository.findSimilarUsers(userId, limit: limit);
    } catch (e) {
      throw Exception('Failed to get similar users: $e');
    }
  }

  /// Get user interaction history for analysis
  Future<List<UserInteraction>> getUserInteractionHistory({
    required String userId,
    int limit = 100,
    DateTime? since,
  }) async {
    try {
      return await _repository.getUserInteractions(
        userId,
        limit: limit,
        since: since,
      );
    } catch (e) {
      throw Exception('Failed to get user interaction history: $e');
    }
  }

  /// Analyze user behavior patterns
  Future<Map<String, dynamic>> analyzeUserBehavior(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      final interactions = await getUserInteractionHistory(userId: userId);
      
      // Calculate behavior statistics
      final totalInteractions = interactions.length;
      final interactionsByType = <InteractionType, int>{};
      
      for (final interaction in interactions) {
        interactionsByType[interaction.type] = 
            (interactionsByType[interaction.type] ?? 0) + 1;
      }

      return {
        'userId': userId,
        'totalInteractions': totalInteractions,
        'interactionsByType': interactionsByType.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        'preferredCategories': profile.preferredCategories,
        'preferredBreeds': profile.preferredBreeds,
        'averageSpending': profile.averageSpending,
        'lastActivity': profile.lastActivity.toIso8601String(),
        'categoryWeights': profile.categoryWeights,
        'breedWeights': profile.breedWeights,
      };
    } catch (e) {
      throw Exception('Failed to analyze user behavior: $e');
    }
  }
}