import 'package:pet_shop/core/di/recommendation_di.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/domain/usecases/recommendation_usecase.dart';
import 'package:pet_shop/services/recommendation_logger.dart';

/// Service to automatically track user interactions for recommendation system
class RecommendationTrackingService {
  static final RecommendationTrackingService _instance = 
      RecommendationTrackingService._internal();
  factory RecommendationTrackingService() => _instance;
  RecommendationTrackingService._internal();

  late final RecommendationUseCase _recommendationUseCase;
  late final UserManager _userManager;
  bool _isInitialized = false;

  /// Initialize the tracking service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await setupRecommendationDI();
      _recommendationUseCase = getIt<RecommendationUseCase>();
      _userManager = UserManager();
      await _userManager.initialize();
      _isInitialized = true;
      print('🎯 RecommendationTrackingService initialized');
    } catch (e) {
      print('❌ Failed to initialize RecommendationTrackingService: $e');
    }
  }

  /// Track when user views a pet
  Future<void> trackPetView(String petId, {Map<String, dynamic>? metadata}) async {
    await _trackInteraction(petId, InteractionType.view, metadata);
  }

  /// Track when user searches
  Future<void> trackSearch(String petId, String query, {Map<String, dynamic>? metadata}) async {
    final searchMetadata = {
      'query': query,
      ...?metadata,
    };
    await _trackInteraction(petId, InteractionType.search, searchMetadata);
  }

  /// Track when user adds to favorites
  Future<void> trackFavorite(String petId, {Map<String, dynamic>? metadata}) async {
    await _trackInteraction(petId, InteractionType.favorite, metadata);
  }

  /// Track when user adds to cart
  Future<void> trackAddToCart(String petId, {Map<String, dynamic>? metadata}) async {
    await _trackInteraction(petId, InteractionType.cart, metadata);
  }

  /// Track when user makes a purchase
  Future<void> trackPurchase(String petId, {Map<String, dynamic>? metadata}) async {
    await _trackInteraction(petId, InteractionType.purchase, metadata);
  }

  /// Track multiple purchases (for order completion)
  Future<void> trackPurchases(List<String> petIds, {Map<String, dynamic>? metadata}) async {
    for (final petId in petIds) {
      await trackPurchase(petId, metadata: metadata);
    }
  }

  /// Get user recommendations
  Future<List<RecommendationItem>> getPersonalizedRecommendations({
    int limit = 10,
    List<RecommendationType>? types,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final userId = await _userManager.getUserIdForOperations();
      if (userId == null) return [];

      final response = await _recommendationUseCase.getPersonalizedRecommendations(
        userId: userId,
        limit: limit,
        types: types,
      );

      return response.items;
    } catch (e) {
      print('❌ Error getting personalized recommendations: $e');
      return [];
    }
  }

  /// Get recommendations by specific type
  Future<List<RecommendationItem>> getRecommendationsByType(
    RecommendationType type, {
    int limit = 10,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final userId = await _userManager.getUserIdForOperations();
      if (userId == null) return [];

      return await _recommendationUseCase.getRecommendationsByType(
        userId: userId,
        type: type,
        limit: limit,
      );
    } catch (e) {
      print('❌ Error getting recommendations by type: $e');
      return [];
    }
  }

  /// Get user behavior analysis
  Future<Map<String, dynamic>?> getUserBehaviorAnalysis() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final userId = await _userManager.getUserIdForOperations();
      if (userId == null) return null;

      return await _recommendationUseCase.analyzeUserBehavior(userId);
    } catch (e) {
      print('❌ Error getting user behavior analysis: $e');
      return null;
    }
  }

  /// Private method to track interactions
  Future<void> _trackInteraction(
    String petId,
    InteractionType type,
    Map<String, dynamic>? metadata,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final userId = await _userManager.getUserIdForOperations();
      if (userId == null) {
        print('⚠️ Cannot track interaction: user not logged in');
        return;
      }

      // Log user interaction
      await RecommendationLogger.logUserInteraction(
        userId: userId,
        petId: petId,
        interactionType: type,
        metadata: metadata,
      );

      await _recommendationUseCase.trackUserInteraction(
        userId: userId,
        petId: petId,
        type: type,
        metadata: metadata,
      );

      print('🎯 Tracked ${type.toString()} for pet $petId');
    } catch (e) {
      print('❌ Error tracking interaction: $e');
    }
  }
}

/// Extension to easily integrate tracking into existing widgets
extension RecommendationTrackingExtension on RecommendationTrackingService {
  /// Track interaction and navigate to detail page
  Future<void> trackAndNavigate(
    String petId,
    InteractionType type, {
    Map<String, dynamic>? metadata,
  }) async {
    await _trackInteraction(petId, type, metadata);
  }

  /// Batch track multiple interactions
  Future<void> batchTrackInteractions(List<({
    String petId,
    InteractionType type,
    Map<String, dynamic>? metadata,
  })> interactions) async {
    for (final interaction in interactions) {
      await _trackInteraction(
        interaction.petId,
        interaction.type,
        interaction.metadata,
      );
    }
  }
}

/// Helper function to get tracking service instance
RecommendationTrackingService get recommendationTracker => 
    RecommendationTrackingService();