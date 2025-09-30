import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/domain/usecases/recommendation_usecase.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_event.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_state.dart';

class RecommendationBloc extends Bloc<RecommendationEvent, RecommendationState> {
  final RecommendationUseCase _recommendationUseCase;

  RecommendationBloc({
    required RecommendationUseCase recommendationUseCase,
  })  : _recommendationUseCase = recommendationUseCase,
        super(RecommendationInitial()) {
    on<LoadRecommendations>(_onLoadRecommendations);
    on<LoadRecommendationsByType>(_onLoadRecommendationsByType);
    on<LoadHybridRecommendations>(_onLoadHybridRecommendations);
    on<LoadPersonalizedRecommendations>(_onLoadPersonalizedRecommendations);
    on<TrackUserInteraction>(_onTrackUserInteraction);
    on<LoadUserProfile>(_onLoadUserProfile);
    on<LoadSimilarUsers>(_onLoadSimilarUsers);
    on<RefreshRecommendations>(_onRefreshRecommendations);
  }

  Future<void> _onLoadRecommendations(
    LoadRecommendations event,
    Emitter<RecommendationState> emit,
  ) async {
    emit(RecommendationLoading());
    
    try {
      final response = await _recommendationUseCase.getPersonalizedRecommendations(
        userId: event.userId,
        limit: event.limit,
        types: event.types,
      );

      if (response.items.isEmpty) {
        emit(const RecommendationEmpty());
      } else {
        emit(RecommendationLoaded(
          recommendations: response.items,
          recommendationsByType: response.itemsByType,
        ));
      }
    } catch (e) {
      emit(RecommendationError('Lỗi khi tải khuyến nghị: ${e.toString()}'));
    }
  }

  Future<void> _onLoadRecommendationsByType(
    LoadRecommendationsByType event,
    Emitter<RecommendationState> emit,
  ) async {
    emit(RecommendationLoading());
    
    try {
      final recommendations = await _recommendationUseCase.getRecommendationsByType(
        userId: event.userId,
        type: event.type,
        limit: event.limit,
      );

      if (recommendations.isEmpty) {
        emit(const RecommendationEmpty());
      } else {
        emit(RecommendationLoaded(
          recommendations: recommendations,
        ));
      }
    } catch (e) {
      emit(RecommendationError('Lỗi khi tải khuyến nghị theo loại: ${e.toString()}'));
    }
  }

  Future<void> _onLoadHybridRecommendations(
    LoadHybridRecommendations event,
    Emitter<RecommendationState> emit,
  ) async {
    emit(RecommendationLoading());
    
    try {
      final recommendations = await _recommendationUseCase.getHybridRecommendations(
        userId: event.userId,
        limit: event.limit,
      );

      if (recommendations.isEmpty) {
        emit(const RecommendationEmpty());
      } else {
        emit(RecommendationLoaded(
          recommendations: recommendations,
        ));
      }
    } catch (e) {
      emit(RecommendationError('Lỗi khi tải khuyến nghị kết hợp: ${e.toString()}'));
    }
  }

  Future<void> _onLoadPersonalizedRecommendations(
    LoadPersonalizedRecommendations event,
    Emitter<RecommendationState> emit,
  ) async {
    emit(RecommendationLoading());
    
    try {
      final response = await _recommendationUseCase.getPersonalizedRecommendations(
        userId: event.userId,
        limit: event.limit,
      );

      if (response.items.isEmpty) {
        emit(const RecommendationEmpty());
      } else {
        emit(RecommendationLoaded(
          recommendations: response.items,
          recommendationsByType: response.itemsByType,
        ));
      }
    } catch (e) {
      emit(RecommendationError('Lỗi khi tải khuyến nghị cá nhân: ${e.toString()}'));
    }
  }

  Future<void> _onTrackUserInteraction(
    TrackUserInteraction event,
    Emitter<RecommendationState> emit,
  ) async {
    try {
      await _recommendationUseCase.trackUserInteraction(
        userId: event.userId,
        petId: event.petId,
        type: event.type,
        metadata: event.metadata,
      );

      // Don't emit a new state for tracking unless needed for UI feedback
      // The tracking happens in the background
      if (state is RecommendationLoaded) {
        // Optionally show a success message
        emit((state as RecommendationLoaded).copyWith(
          message: 'Đã cập nhật sở thích của bạn',
        ));
      }
    } catch (e) {
      // Only emit error if tracking is critical for the UI
      print('Error tracking interaction: $e');
    }
  }

  Future<void> _onLoadUserProfile(
    LoadUserProfile event,
    Emitter<RecommendationState> emit,
  ) async {
    try {
      final userProfile = await _recommendationUseCase.getUserProfile(event.userId);
      final behaviorAnalysis = await _recommendationUseCase.analyzeUserBehavior(event.userId);
      
      emit(UserProfileLoaded(
        userProfile: userProfile,
        behaviorAnalysis: behaviorAnalysis,
      ));
    } catch (e) {
      emit(RecommendationError('Lỗi khi tải thông tin người dùng: ${e.toString()}'));
    }
  }

  Future<void> _onLoadSimilarUsers(
    LoadSimilarUsers event,
    Emitter<RecommendationState> emit,
  ) async {
    try {
      final similarUsers = await _recommendationUseCase.getSimilarUsers(
        userId: event.userId,
        limit: event.limit,
      );

      emit(SimilarUsersLoaded(similarUsers));
    } catch (e) {
      emit(RecommendationError('Lỗi khi tìm người dùng tương tự: ${e.toString()}'));
    }
  }

  Future<void> _onRefreshRecommendations(
    RefreshRecommendations event,
    Emitter<RecommendationState> emit,
  ) async {
    // Force refresh by loading personalized recommendations
    add(LoadPersonalizedRecommendations(userId: event.userId));
  }
}