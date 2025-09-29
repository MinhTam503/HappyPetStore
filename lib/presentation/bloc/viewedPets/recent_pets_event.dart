import 'package:equatable/equatable.dart';
import 'package:pet_shop/data/models/viewed_pet_model.dart';


sealed class RecentPetsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

final class LoadRecentPets extends RecentPetsEvent {}

final class AddViewedPet extends RecentPetsEvent {
  final ViewedPetModel pet;
  AddViewedPet(this.pet);
  @override
  List<Object?> get props => [pet];
}

final class RemoveViewedPet extends RecentPetsEvent {
  final String id;
  RemoveViewedPet(this.id);
  @override
  List<Object?> get props => [id];
}

final class ClearRecentPets extends RecentPetsEvent {}
