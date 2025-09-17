import 'package:equatable/equatable.dart';

abstract class PopularState extends Equatable {
  const PopularState();
  @override
  List<Object?> get props => [];
}

class PopularInitial extends PopularState {}

class PopularLoading extends PopularState {}

class PopularLoaded extends PopularState {
  final List<Map<String, dynamic>> pets; // all pets of top 5 breeds
  final List<String> topBreeds;
  const PopularLoaded(this.pets, this.topBreeds);

  @override
  List<Object?> get props => [pets, topBreeds];
}

class PopularError extends PopularState {
  final String message;
  const PopularError(this.message);

  @override
  List<Object?> get props => [message];
}
