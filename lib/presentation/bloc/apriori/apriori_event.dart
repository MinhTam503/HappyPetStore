abstract class AprioriEvent {}

class GetSuggestionsFromSingleBreed extends AprioriEvent {
  final String breed;
  
  GetSuggestionsFromSingleBreed(this.breed);
}

class GetSuggestionsFromMultipleBreeds extends AprioriEvent {
  final List<String> breeds;
  final double minSupport;
  final double minConfidence;
  final int maxSuggestions;
  
  GetSuggestionsFromMultipleBreeds(
    this.breeds, {
    this.minSupport = 0.01,
    this.minConfidence = 0.3,
    this.maxSuggestions = 10,
  });
}

class GetSuggestionsFromCartItems extends AprioriEvent {
  final List<Map<String, dynamic>> cartItems;
  final double minSupport;
  final double minConfidence;
  final int maxSuggestions;
  
  GetSuggestionsFromCartItems(
    this.cartItems, {
    this.minSupport = 0.01,
    this.minConfidence = 0.3,
    this.maxSuggestions = 10,
  });
}

class ClearSuggestions extends AprioriEvent {}
