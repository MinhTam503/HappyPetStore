abstract class SearchEvent {}

class SearchQueryChanged extends SearchEvent {
  final String query;
  SearchQueryChanged(this.query);
}

class SearchSubmitted extends SearchEvent {
  final String query;
  final bool isSuggestionTap;
  SearchSubmitted(this.query, {this.isSuggestionTap = false});
}

class LoadSearchHistory extends SearchEvent {}

class ClearSearchHistory extends SearchEvent {}

class ToggleCategory extends SearchEvent {
  final String category;
  ToggleCategory(this.category);
}

class ImageSearchSubmitted extends SearchEvent {
  final String imagePath;
  ImageSearchSubmitted(this.imagePath);
}