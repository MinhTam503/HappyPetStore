import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/apriori_usecase.dart';
import 'apriori_event.dart';
import 'apriori_state.dart';

class AprioriBloc extends Bloc<AprioriEvent, AprioriState> {
  final AprioriUseCase _aprioriUseCase;

  AprioriBloc(this._aprioriUseCase) : super(AprioriInitial()) {
    on<GetSuggestionsFromSingleBreed>(_onGetSuggestionsFromSingleBreed);
    on<GetSuggestionsFromMultipleBreeds>(_onGetSuggestionsFromMultipleBreeds);
    on<GetSuggestionsFromCartItems>(_onGetSuggestionsFromCartItems);
    on<ClearSuggestions>(_onClearSuggestions);
  }

  Future<void> _onGetSuggestionsFromSingleBreed(
    GetSuggestionsFromSingleBreed event,
    Emitter<AprioriState> emit,
  ) async {
    emit(AprioriLoading());
    
    try {
      final suggestions = await _aprioriUseCase.getSuggestedPetsFromMultipleBreeds(
        [event.breed],
        maxSuggestions: 10,
      );
      
      if (suggestions.isEmpty) {
        emit(AprioriEmpty('Không tìm thấy gợi ý cho giống "${event.breed}"'));
      } else {
        emit(AprioriLoaded(
          suggestions: suggestions,
          inputBreeds: [event.breed],
          analysisInfo: 'Gợi ý dựa trên giống: ${event.breed}',
        ));
      }
    } catch (e) {
      emit(AprioriError('Lỗi khi lấy gợi ý: ${e.toString()}'));
    }
  }

  Future<void> _onGetSuggestionsFromMultipleBreeds(
    GetSuggestionsFromMultipleBreeds event,
    Emitter<AprioriState> emit,
  ) async {
    emit(AprioriLoading());
    
    try {
      if (event.breeds.isEmpty) {
        emit(AprioriEmpty('Không có giống nào để phân tích'));
        return;
      }

      final suggestions = await _aprioriUseCase.getSuggestedPetsFromMultipleBreeds(
        event.breeds,
        minSupport: event.minSupport,
        minConfidence: event.minConfidence,
        maxSuggestions: event.maxSuggestions,
      );
      
      if (suggestions.isEmpty) {
        emit(AprioriEmpty('Không tìm thấy gợi ý cho các giống: ${event.breeds.join(", ")}'));
      } else {
        final analysisInfo = 'Phân tích ${event.breeds.length} giống: ${event.breeds.join(", ")}';
        emit(AprioriLoaded(
          suggestions: suggestions,
          inputBreeds: event.breeds,
          analysisInfo: analysisInfo,
        ));
      }
    } catch (e) {
      emit(AprioriError('Lỗi khi phân tích nhiều giống: ${e.toString()}'));
    }
  }

  Future<void> _onGetSuggestionsFromCartItems(
    GetSuggestionsFromCartItems event,
    Emitter<AprioriState> emit,
  ) async {
    emit(AprioriLoading());
    
    try {
      // Extract unique breeds from cart items
      Set<String> breedSet = {};
      for (var item in event.cartItems) {
        final breed = item['breed'] as String?;
        if (breed != null && breed.isNotEmpty) {
          breedSet.add(breed);
        }
      }

      final breeds = breedSet.toList();
      
      if (breeds.isEmpty) {
        emit(AprioriEmpty('Không tìm thấy thông tin giống trong giỏ hàng'));
        return;
      }

      print('🔍 Analyzing cart with ${breeds.length} unique breeds: $breeds');

      final suggestions = await _aprioriUseCase.getSuggestedPetsFromMultipleBreeds(
        breeds,
        minSupport: event.minSupport,
        minConfidence: event.minConfidence,
        maxSuggestions: event.maxSuggestions,
      );
      
      if (suggestions.isEmpty) {
        emit(AprioriEmpty('Không tìm thấy gợi ý phù hợp cho giỏ hàng hiện tại'));
      } else {
        final analysisInfo = 'Gợi ý dựa trên ${breeds.length} giống trong giỏ hàng: ${breeds.join(", ")}';
        emit(AprioriLoaded(
          suggestions: suggestions,
          inputBreeds: breeds,
          analysisInfo: analysisInfo,
        ));
      }
    } catch (e) {
      emit(AprioriError('Lỗi khi phân tích giỏ hàng: ${e.toString()}'));
    }
  }

  void _onClearSuggestions(
    ClearSuggestions event,
    Emitter<AprioriState> emit,
  ) {
    emit(AprioriInitial());
  }
}
