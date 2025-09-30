import 'package:equatable/equatable.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';

abstract class RecommendationEvent extends Equatable {
  const RecommendationEvent();

  @override
  List<Object?> get props => [];
}

class LoadRecommendations extends RecommendationEvent {
  final String userId;
  final List<RecommendationType>? types;
  final int limit;

  const LoadRecommendations({
    required this.userId,
    this.types,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [userId, types, limit];
}

class LoadRecommendationsByType extends RecommendationEvent {
  final String userId;
  final RecommendationType type;
  final int limit;

  const LoadRecommendationsByType({
    required this.userId,
    required this.type,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [userId, type, limit];
}

class TrackUserInteraction extends RecommendationEvent {
  final String userId;
  final String petId;
  final InteractionType type;
  final Map<String, dynamic>? metadata;

  const TrackUserInteraction({
    required this.userId,
    required this.petId,
    required this.type,
    this.metadata,
  });

  @override
  List<Object?> get props => [userId, petId, type, metadata];
}

class LoadUserProfile extends RecommendationEvent {
  final String userId;

  const LoadUserProfile(this.userId);

  @override
  List<Object?> get props => [userId];
}

class LoadHybridRecommendations extends RecommendationEvent {
  final String userId;
  final int limit;

  const LoadHybridRecommendations({
    required this.userId,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [userId, limit];
}

class LoadSimilarUsers extends RecommendationEvent {
  final String userId;
  final int limit;

  const LoadSimilarUsers({
    required this.userId,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [userId, limit];
}

class RefreshRecommendations extends RecommendationEvent {
  final String userId;

  const RefreshRecommendations(this.userId);

  @override
  List<Object?> get props => [userId];
}

class LoadPersonalizedRecommendations extends RecommendationEvent {
  final String userId;
  final int limit;

  const LoadPersonalizedRecommendations({
    required this.userId,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [userId, limit];
}