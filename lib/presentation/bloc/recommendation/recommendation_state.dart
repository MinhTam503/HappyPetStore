import 'package:equatable/equatable.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';

abstract class RecommendationState extends Equatable {
  const RecommendationState();

  @override
  List<Object?> get props => [];
}

class RecommendationInitial extends RecommendationState {}

class RecommendationLoading extends RecommendationState {}

class RecommendationLoaded extends RecommendationState {
  final List<RecommendationItem> recommendations;
  final Map<RecommendationType, List<RecommendationItem>>? recommendationsByType;
  final UserProfile? userProfile;
  final List<SimilarUser>? similarUsers;
  final String? message;

  const RecommendationLoaded({
    required this.recommendations,
    this.recommendationsByType,
    this.userProfile,
    this.similarUsers,
    this.message,
  });

  @override
  List<Object?> get props => [
        recommendations,
        recommendationsByType,
        userProfile,
        similarUsers,
        message,
      ];

  RecommendationLoaded copyWith({
    List<RecommendationItem>? recommendations,
    Map<RecommendationType, List<RecommendationItem>>? recommendationsByType,
    UserProfile? userProfile,
    List<SimilarUser>? similarUsers,
    String? message,
  }) {
    return RecommendationLoaded(
      recommendations: recommendations ?? this.recommendations,
      recommendationsByType: recommendationsByType ?? this.recommendationsByType,
      userProfile: userProfile ?? this.userProfile,
      similarUsers: similarUsers ?? this.similarUsers,
      message: message ?? this.message,
    );
  }
}

class RecommendationError extends RecommendationState {
  final String message;

  const RecommendationError(this.message);

  @override
  List<Object?> get props => [message];
}

class UserProfileLoaded extends RecommendationState {
  final UserProfile userProfile;
  final Map<String, dynamic>? behaviorAnalysis;

  const UserProfileLoaded({
    required this.userProfile,
    this.behaviorAnalysis,
  });

  @override
  List<Object?> get props => [userProfile, behaviorAnalysis];
}

class InteractionTracked extends RecommendationState {
  final String message;

  const InteractionTracked(this.message);

  @override
  List<Object?> get props => [message];
}

class SimilarUsersLoaded extends RecommendationState {
  final List<SimilarUser> similarUsers;

  const SimilarUsersLoaded(this.similarUsers);

  @override
  List<Object?> get props => [similarUsers];
}

class RecommendationEmpty extends RecommendationState {
  final String message;

  const RecommendationEmpty({
    this.message = 'Không có khuyến nghị nào được tìm thấy',
  });

  @override
  List<Object?> get props => [message];
}