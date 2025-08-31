import '../../domain/entities/breed_entities.dart';

abstract class AprioriState {}

class AprioriInitial extends AprioriState {}

class AprioriLoading extends AprioriState {}

class AprioriLoaded extends AprioriState {
  final List<SuggestedPet> suggestions;
  final List<String> inputBreeds;
  final String analysisInfo;
  
  AprioriLoaded({
    required this.suggestions,
    required this.inputBreeds,
    this.analysisInfo = '',
  });
  
  @override
  String toString() => 'AprioriLoaded(${suggestions.length} suggestions for breeds: $inputBreeds)';
}

class AprioriError extends AprioriState {
  final String message;
  
  AprioriError(this.message);
  
  @override
  String toString() => 'AprioriError: $message';
}

class AprioriEmpty extends AprioriState {
  final String reason;
  
  AprioriEmpty(this.reason);
  
  @override
  String toString() => 'AprioriEmpty: $reason';
}
