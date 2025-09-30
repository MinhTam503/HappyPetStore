import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/data/repositories/recommendation_repository_impl.dart';
import 'package:pet_shop/domain/repositories/recommendation_repository.dart';
import 'package:pet_shop/domain/usecases/recommendation_usecase.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_bloc.dart';

/// Service locator for dependency injection
final getIt = GetIt.instance;

/// Setup dependency injection for recommendation system
Future<void> setupRecommendationDI() async {
  // External dependencies
  if (!getIt.isRegistered<FirebaseFirestore>()) {
    getIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  }
  
  if (!getIt.isRegistered<UserManager>()) {
    getIt.registerLazySingleton<UserManager>(() => UserManager());
  }

  // Repository - check if already registered
  if (!getIt.isRegistered<RecommendationRepository>()) {
    getIt.registerLazySingleton<RecommendationRepository>(
      () => RecommendationRepositoryImpl(
        firestore: getIt<FirebaseFirestore>(),
        userManager: getIt<UserManager>(),
      ),
    );
  }

  // Use case - check if already registered
  if (!getIt.isRegistered<RecommendationUseCase>()) {
    getIt.registerLazySingleton<RecommendationUseCase>(
      () => RecommendationUseCase(getIt<RecommendationRepository>()),
    );
  }

  // BLoC - always register as factory (can have multiple instances)
  if (!getIt.isRegistered<RecommendationBloc>()) {
    getIt.registerFactory<RecommendationBloc>(
      () => RecommendationBloc(
        recommendationUseCase: getIt<RecommendationUseCase>(),
      ),
    );
  }
}

/// Clean up dependency injection
Future<void> cleanupRecommendationDI() async {
  if (getIt.isRegistered<RecommendationBloc>()) {
    await getIt.unregister<RecommendationBloc>();
  }
  if (getIt.isRegistered<RecommendationUseCase>()) {
    await getIt.unregister<RecommendationUseCase>();
  }
  if (getIt.isRegistered<RecommendationRepository>()) {
    await getIt.unregister<RecommendationRepository>();
  }
}