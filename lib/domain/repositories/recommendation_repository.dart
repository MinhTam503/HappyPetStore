import 'package:pet_shop/domain/entities/recommendation_entities.dart';

/// Abstract repository interface for recommendation system
abstract class RecommendationRepository {
  /// Get user profile based on behavior data
  Future<UserProfile> getUserProfile(String userId);
  
  /// Update user profile with new interaction
  Future<void> updateUserProfile(UserInteraction interaction);
  
  /// Get recommendations for a user
  Future<RecommendationResponse> getRecommendations(RecommendationRequest request);
  
  /// Find similar users based on behavior patterns
  Future<List<SimilarUser>> findSimilarUsers(String userId, {int limit = 10});
  
  /// Get content-based recommendations
  Future<List<RecommendationItem>> getContentBasedRecommendations(
    String userId, {
    int limit = 10,
  });
  
  /// Get collaborative filtering recommendations
  Future<List<RecommendationItem>> getCollaborativeRecommendations(
    String userId, {
    int limit = 10,
  });
  
  /// Get trending pets
  Future<List<RecommendationItem>> getTrendingPets({int limit = 10});
  
  /// Get association rule based recommendations
  Future<List<RecommendationItem>> getAssociationRecommendations(
    String userId, {
    int limit = 10,
  });
  
  /// Track user interaction for future recommendations
  Future<void> trackInteraction(UserInteraction interaction);
  
  /// Get user interactions history
  Future<List<UserInteraction>> getUserInteractions(
    String userId, {
    int limit = 100,
    DateTime? since,
  });
  
  /// Get pets by IDs for recommendation display
  Future<List<Map<String, dynamic>>> getPetsByIds(List<String> petIds);
}