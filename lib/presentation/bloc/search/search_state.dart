import 'package:pet_shop/data/models/search_history_model.dart';
abstract class SearchState {}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchSuccess extends SearchState {
  final List<Map<String, dynamic>> searchResults;
  final List<Map<String, dynamic>> suggestions;
  final List<SearchHistoryModel> searchHistory;
  final String? selectedCategory;
  
  SearchSuccess({
    required this.searchResults,
    required this.suggestions,
    required this.searchHistory,
    this.selectedCategory,
  });

  SearchSuccess copyWith({
    List<Map<String, dynamic>>? searchResults,
    List<Map<String, dynamic>>? suggestions,
    List<SearchHistoryModel>? searchHistory,
    String? selectedCategory,
  }) {
    return SearchSuccess(
      searchResults: searchResults ?? this.searchResults,
      suggestions: suggestions ?? this.suggestions,
      searchHistory: searchHistory ?? this.searchHistory,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }
}

class SearchError extends SearchState {
  final String message;
  SearchError(this.message);
}