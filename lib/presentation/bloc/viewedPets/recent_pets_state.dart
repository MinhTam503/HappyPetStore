import 'package:equatable/equatable.dart';
import 'package:pet_shop/data/models/viewed_pet_model.dart';


sealed class RecentPetsState extends Equatable {
  const RecentPetsState();
  @override
  List<Object?> get props => [];
}

final class RecentPetsLoading extends RecentPetsState {}

final class RecentPetsEmpty extends RecentPetsState {}

final class RecentPetsLoaded extends RecentPetsState {
  final List<ViewedPetModel> items;
  const RecentPetsLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

final class RecentPetsError extends RecentPetsState {
  final String message;
  const RecentPetsError(this.message);

  @override
  List<Object?> get props => [message];
}
