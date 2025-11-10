import 'package:equatable/equatable.dart';
import 'package:pet_shop/presentation/pages/web/model/pet_model.dart';

/// Base class cho tất cả Pet States
abstract class PetState extends Equatable {
  const PetState();

  @override
  List<Object?> get props => [];
}

/// State: Khởi tạo
class PetInitial extends PetState {
  const PetInitial();
}

/// State: Đang load dữ liệu
class PetLoading extends PetState {
  const PetLoading();
}

/// State: Load thành công
class PetLoaded extends PetState {
  final List<Pet> pets;
  final List<Pet> filteredPets;
  final String selectedCategory;
  final String searchQuery;

  const PetLoaded({
    required this.pets,
    required this.filteredPets,
    this.selectedCategory = 'All',
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [pets, filteredPets, selectedCategory, searchQuery];

  PetLoaded copyWith({
    List<Pet>? pets,
    List<Pet>? filteredPets,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return PetLoaded(
      pets: pets ?? this.pets,
      filteredPets: filteredPets ?? this.filteredPets,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// State: Đang thực hiện action (add/update/delete)
class PetActionInProgress extends PetState {
  final String message;

  const PetActionInProgress(this.message);

  @override
  List<Object?> get props => [message];
}

/// State: Action thành công
class PetActionSuccess extends PetState {
  final String message;

  const PetActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

/// State: Lỗi
class PetError extends PetState {
  final String message;

  const PetError(this.message);

  @override
  List<Object?> get props => [message];
}

/// State: Breeds đã được load
class BreedsLoaded extends PetState {
  final List<String> breeds;
  final String category;

  const BreedsLoaded({
    required this.breeds,
    required this.category,
  });

  @override
  List<Object?> get props => [breeds, category];
}
