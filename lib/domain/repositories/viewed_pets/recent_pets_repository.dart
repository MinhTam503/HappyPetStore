import 'package:pet_shop/data/models/viewed_pet_model.dart';

abstract interface class RecentPetsRepository {
  Future<List<ViewedPetModel>> getAll({int limit});
  Future<void> add(ViewedPetModel pet);
  Future<void> remove(String id);
  Future<void> clear();
}
