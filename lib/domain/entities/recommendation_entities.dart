/// Domain entities for recommendation system
class UserProfile {
  final String userId;
  final List<String> preferredCategories;
  final List<String> preferredBreeds;
  final Map<String, double> categoryWeights;
  final Map<String, double> breedWeights;
  final double averageSpending;
  final DateTime lastActivity;

  const UserProfile({
    required this.userId,
    required this.preferredCategories,
    required this.preferredBreeds,
    required this.categoryWeights,
    required this.breedWeights,
    required this.averageSpending,
    required this.lastActivity,
  });

  factory UserProfile.empty(String userId) {
    return UserProfile(
      userId: userId,
      preferredCategories: [],
      preferredBreeds: [],
      categoryWeights: {},
      breedWeights: {},
      averageSpending: 0.0,
      lastActivity: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'preferredCategories': preferredCategories,
      'preferredBreeds': preferredBreeds,
      'categoryWeights': categoryWeights,
      'breedWeights': breedWeights,
      'averageSpending': averageSpending,
      'lastActivity': lastActivity.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] ?? '',
      preferredCategories: List<String>.from(map['preferredCategories'] ?? []),
      preferredBreeds: List<String>.from(map['preferredBreeds'] ?? []),
      categoryWeights: Map<String, double>.from(map['categoryWeights'] ?? {}),
      breedWeights: Map<String, double>.from(map['breedWeights'] ?? {}),
      averageSpending: (map['averageSpending'] ?? 0.0).toDouble(),
      lastActivity: DateTime.parse(map['lastActivity'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class RecommendationItem {
  final String petId;
  final String name;
  final String category;
  final String breed;
  final double price;
  final String imageUrl;
  final double score;
  final String reason;
  final RecommendationType type;

  const RecommendationItem({
    required this.petId,
    required this.name,
    required this.category,
    required this.breed,
    required this.price,
    required this.imageUrl,
    required this.score,
    required this.reason,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'petId': petId,
      'name': name,
      'category': category,
      'breed': breed,
      'price': price,
      'imageUrl': imageUrl,
      'score': score,
      'reason': reason,
      'type': type.toString(),
    };
  }

  factory RecommendationItem.fromMap(Map<String, dynamic> map) {
    return RecommendationItem(
      petId: map['petId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      breed: map['breed'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      score: (map['score'] ?? 0.0).toDouble(),
      reason: map['reason'] ?? '',
      type: RecommendationType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => RecommendationType.contentBased,
      ),
    );
  }
}

enum RecommendationType {
  collaborative,    // Dựa trên người dùng tương tự
  contentBased,     // Dựa trên thuộc tính pet
  hybrid,           // Kết hợp cả hai
  trending,         // Thú cưng hot trend
  personalized,     // Cá nhân hóa dựa trên lịch sử
  association,      // Dựa trên mẫu mua hàng
}

class UserInteraction {
  final String userId;
  final String petId;
  final InteractionType type;
  final DateTime timestamp;
  final double weight;
  final Map<String, dynamic>? metadata;

  const UserInteraction({
    required this.userId,
    required this.petId,
    required this.type,
    required this.timestamp,
    required this.weight,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'petId': petId,
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      'weight': weight,
      'metadata': metadata,
    };
  }

  factory UserInteraction.fromMap(Map<String, dynamic> map) {
    return UserInteraction(
      userId: map['userId'] ?? '',
      petId: map['petId'] ?? '',
      type: InteractionType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => InteractionType.view,
      ),
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      weight: (map['weight'] ?? 1.0).toDouble(),
      metadata: map['metadata'],
    );
  }
}

enum InteractionType {
  view,       // Xem chi tiết (weight: 1.0)
  search,     // Tìm kiếm (weight: 1.5)
  favorite,   // Yêu thích (weight: 3.0)
  cart,       // Thêm vào giỏ (weight: 4.0)
  purchase,   // Mua hàng (weight: 5.0)
}

extension InteractionTypeExtension on InteractionType {
  double get weight {
    switch (this) {
      case InteractionType.view:
        return 1.0;
      case InteractionType.search:
        return 1.5;
      case InteractionType.favorite:
        return 3.0;
      case InteractionType.cart:
        return 4.0;
      case InteractionType.purchase:
        return 5.0;
    }
  }
}

class SimilarUser {
  final String userId;
  final double similarity;
  final List<String> commonPreferences;

  const SimilarUser({
    required this.userId,
    required this.similarity,
    required this.commonPreferences,
  });
}

class RecommendationRequest {
  final String userId;
  final int limit;
  final List<RecommendationType>? types;
  final Map<String, dynamic>? filters;

  const RecommendationRequest({
    required this.userId,
    this.limit = 10,
    this.types,
    this.filters,
  });
}

class RecommendationResponse {
  final String userId;
  final List<RecommendationItem> items;
  final Map<RecommendationType, List<RecommendationItem>> itemsByType;
  final DateTime generatedAt;
  final Map<String, dynamic>? metadata;

  const RecommendationResponse({
    required this.userId,
    required this.items,
    required this.itemsByType,
    required this.generatedAt,
    this.metadata,
  });
}