import 'package:equatable/equatable.dart';
import 'package:pet_shop/presentation/pages/web/model/pet_model.dart';

/// Base class cho tất cả Pet Events
abstract class PetEvent extends Equatable {
  const PetEvent();

  @override
  List<Object?> get props => [];
}

/// Event: Load danh sách pets từ Firestore
class LoadPetsEvent extends PetEvent {
  const LoadPetsEvent();
}

/// Event: Thêm pet mới
class AddPetEvent extends PetEvent {
  final Pet pet;
  final List<int> imageBytes;

  const AddPetEvent({
    required this.pet,
    required this.imageBytes,
  });

  @override
  List<Object?> get props => [pet, imageBytes];
}

/// Event: Cập nhật thông tin pet
class UpdatePetEvent extends PetEvent {
  final Pet pet;
  final List<int>? imageBytes; // null nếu không đổi ảnh

  const UpdatePetEvent({
    required this.pet,
    this.imageBytes,
  });

  @override
  List<Object?> get props => [pet, imageBytes];
}

/// Event: Xóa pet
class DeletePetEvent extends PetEvent {
  final String petId;
  final String imageUrl;

  const DeletePetEvent({
    required this.petId,
    required this.imageUrl,
  });

  @override
  List<Object?> get props => [petId, imageUrl];
}

/// Event: Lọc pets theo category
class FilterPetsByCategoryEvent extends PetEvent {
  final String category;

  const FilterPetsByCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

/// Event: Tìm kiếm pets theo tên
class SearchPetsEvent extends PetEvent {
  final String query;

  const SearchPetsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

/// Event: Load breeds cho category
class LoadBreedsEvent extends PetEvent {
  final String category;

  const LoadBreedsEvent(this.category);

  @override
  List<Object?> get props => [category];
}

/// Event: Thêm breed mới
class AddBreedEvent extends PetEvent {
  final String category;
  final String breed;

  const AddBreedEvent({
    required this.category,
    required this.breed,
  });

  @override
  List<Object?> get props => [category, breed];
}
