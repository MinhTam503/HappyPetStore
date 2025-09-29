import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/domain/repositories/viewed_pets/recent_pets_repository.dart';
import 'recent_pets_event.dart';
import 'recent_pets_state.dart';

class RecentPetsBloc extends Bloc<RecentPetsEvent, RecentPetsState> {
  RecentPetsBloc(this.repo) : super(RecentPetsLoading()) {
    on<LoadRecentPets>(_onLoad);
    on<AddViewedPet>(_onAdd);
    on<RemoveViewedPet>(_onRemove);
    on<ClearRecentPets>(_onClear);
  }

  final RecentPetsRepository repo;

  Future<void> _onLoad(LoadRecentPets event, Emitter<RecentPetsState> emit) async {
    emit(RecentPetsLoading());
    try {
      final data = await repo.getAll();
      emit(data.isEmpty ? RecentPetsEmpty() : RecentPetsLoaded(data));
    } catch (e) {
      emit(RecentPetsError(e.toString()));
    }
  }

  Future<void> _onAdd(AddViewedPet event, Emitter<RecentPetsState> emit) async {
    try {
      await repo.add(event.pet);
      final data = await repo.getAll();
      emit(data.isEmpty ? RecentPetsEmpty() : RecentPetsLoaded(data));
    } catch (e) {
      emit(RecentPetsError(e.toString()));
    }
  }

  Future<void> _onRemove(RemoveViewedPet event, Emitter<RecentPetsState> emit) async {
    try {
      await repo.remove(event.id);
      final data = await repo.getAll();
      emit(data.isEmpty ? RecentPetsEmpty() : RecentPetsLoaded(data));
    } catch (e) {
      emit(RecentPetsError(e.toString()));
    }
  }

  Future<void> _onClear(ClearRecentPets event, Emitter<RecentPetsState> emit) async {
    try {
      await repo.clear();
      emit(RecentPetsEmpty());
    } catch (e) {
      emit(RecentPetsError(e.toString()));
    }
  }
}
