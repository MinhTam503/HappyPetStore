import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pet_shop/presentation/pages/web/model/pet_model.dart';
import 'pet_event.dart';
import 'pet_state.dart';

class PetBloc extends Bloc<PetEvent, PetState> {
  final CollectionReference _petsCollection =
      FirebaseFirestore.instance.collection('Pets');

  PetBloc() : super(const PetInitial()) {
    on<LoadPetsEvent>(_onLoadPets);
    on<AddPetEvent>(_onAddPet);
    on<UpdatePetEvent>(_onUpdatePet);
    on<DeletePetEvent>(_onDeletePet);
    on<FilterPetsByCategoryEvent>(_onFilterByCategory);
    on<SearchPetsEvent>(_onSearchPets);
    on<LoadBreedsEvent>(_onLoadBreeds);
    on<AddBreedEvent>(_onAddBreed);
  }

  // Load danh sách pets từ Firestore
  Future<void> _onLoadPets(
    LoadPetsEvent event,
    Emitter<PetState> emit,
  ) async {
    emit(const PetLoading());
    try {
      final snapshot = await _petsCollection.get();
      final allPets = snapshot.docs
          .map((doc) => Pet.fromDocument(doc))
          .toList();
      
      // ADMIN PANEL: Show ALL pets (including unavailable ones)
      // Admin needs to see all pets to manage inventory
      // Filter is only applied on customer-facing pages
      
      emit(PetLoaded(
        pets: allPets,
        filteredPets: allPets,
      ));
    } catch (e) {
      emit(PetError('Lỗi load pets: $e'));
    }
  }

  // Thêm pet mới
  Future<void> _onAddPet(
    AddPetEvent event,
    Emitter<PetState> emit,
  ) async {
    emit(const PetActionInProgress('Đang thêm thú cưng...'));
    
    try {
      final pet = event.pet;
      final imageBytes = Uint8List.fromList(event.imageBytes);

      // Upload image
      final imageUrl = await _uploadImage(imageBytes, pet.id);
      if (imageUrl.isEmpty) {
        emit(const PetError('Lỗi upload hình ảnh'));
        return;
      }

      // Parse price
      final priceValue = _parsePrice(pet.price);

      // Add to Firestore
      await _petsCollection.doc(pet.id).set({
        'id': pet.id,
        'name': pet.name.isNotEmpty ? pet.name : 'Unknown',
        'category': pet.category.isNotEmpty ? pet.category : 'Dogs',
        'imageUrl': imageUrl,
        'age': pet.age.isNotEmpty ? pet.age : '1',
        'breed': pet.breed.isNotEmpty ? pet.breed : 'Unknown',
        'about': pet.about.isNotEmpty ? pet.about : 'No description',
        'sex': pet.gender.isNotEmpty ? pet.gender : 'Unknown',
        'price': priceValue,
        'weight': pet.weight.isNotEmpty ? pet.weight : '0',
        'color': pet.color ?? '',
        'isAvailable': pet.isAvailable,
      });

      // Train AI
      await _callTrainAPI();

      emit(const PetActionSuccess('Thêm thú cưng thành công!'));
      
      // Reload pets
      add(const LoadPetsEvent());
    } catch (e) {
      emit(PetError('Lỗi thêm pet: $e'));
    }
  }

  // Cập nhật pet
  Future<void> _onUpdatePet(
    UpdatePetEvent event,
    Emitter<PetState> emit,
  ) async {
    emit(const PetActionInProgress('Đang cập nhật...'));
    
    try {
      final pet = event.pet;
      String finalImageUrl = pet.imageUrl;

      // Upload new image if provided
      if (event.imageBytes != null) {
        final imageBytes = Uint8List.fromList(event.imageBytes!);
        finalImageUrl = await _uploadImage(imageBytes, pet.id);
        if (finalImageUrl.isEmpty) {
          emit(const PetError('Lỗi upload hình ảnh'));
          return;
        }
      }

      // Parse price
      final priceValue = _parsePrice(pet.price);

      // Update Firestore
      await _petsCollection.doc(pet.id).update({
        'name': pet.name.isNotEmpty ? pet.name : 'Unknown',
        'category': pet.category.isNotEmpty ? pet.category : 'Dogs',
        'imageUrl': finalImageUrl.isNotEmpty ? finalImageUrl : pet.imageUrl,
        'age': pet.age.isNotEmpty ? pet.age : '1',
        'breed': pet.breed.isNotEmpty ? pet.breed : 'Unknown',
        'about': pet.about.isNotEmpty ? pet.about : 'No description',
        'sex': pet.gender.isNotEmpty ? pet.gender : 'Unknown',
        'weight': pet.weight.isNotEmpty ? pet.weight : '0',
        'color': pet.color ?? '',
        'isAvailable': pet.isAvailable,
        'price': priceValue,
      });

      emit(const PetActionSuccess('Cập nhật thành công!'));
      
      // Reload pets
      add(const LoadPetsEvent());
    } catch (e) {
      emit(PetError('Lỗi cập nhật: $e'));
    }
  }

  // Xóa pet
  Future<void> _onDeletePet(
    DeletePetEvent event,
    Emitter<PetState> emit,
  ) async {
    emit(const PetActionInProgress('Đang xóa...'));
    
    try {
      // Delete image from Storage
      try {
        final imageRef = FirebaseStorage.instance.refFromURL(event.imageUrl);
        await imageRef.delete();
      } catch (e) {
        debugPrint('Error deleting image: $e');
      }

      // Delete from Firestore
      await _petsCollection.doc(event.petId).delete();

      emit(const PetActionSuccess('Xóa thành công!'));
      
      // Reload pets
      add(const LoadPetsEvent());
    } catch (e) {
      emit(PetError('Lỗi xóa: $e'));
    }
  }

  // Filter pets by category
  void _onFilterByCategory(
    FilterPetsByCategoryEvent event,
    Emitter<PetState> emit,
  ) {
    if (state is PetLoaded) {
      final currentState = state as PetLoaded;
      final filteredPets = event.category == 'All'
          ? currentState.pets
          : currentState.pets
              .where((pet) => pet.category == event.category)
              .toList();

      // Apply search if exists
      final searchQuery = currentState.searchQuery;
      final finalFiltered = searchQuery.isEmpty
          ? filteredPets
          : filteredPets
              .where((pet) => pet.name.toLowerCase().contains(searchQuery))
              .toList();

      emit(currentState.copyWith(
        filteredPets: finalFiltered,
        selectedCategory: event.category,
      ));
    }
  }

  // Search pets
  void _onSearchPets(
    SearchPetsEvent event,
    Emitter<PetState> emit,
  ) {
    if (state is PetLoaded) {
      final currentState = state as PetLoaded;
      final query = event.query.toLowerCase();

      // Start with category filtered pets
      var filteredPets = currentState.selectedCategory == 'All'
          ? currentState.pets
          : currentState.pets
              .where((pet) => pet.category == currentState.selectedCategory)
              .toList();

      // Apply search
      if (query.isNotEmpty) {
        filteredPets = filteredPets
            .where((pet) => pet.name.toLowerCase().contains(query))
            .toList();
      }

      emit(currentState.copyWith(
        filteredPets: filteredPets,
        searchQuery: query,
      ));
    }
  }

  // Load breeds for category
  Future<void> _onLoadBreeds(
    LoadBreedsEvent event,
    Emitter<PetState> emit,
  ) async {
    try {
      // Lưu state hiện tại
      final currentState = state;
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Category')
          .where('name', isEqualTo: event.category)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final breeds = List<String>.from(doc['breeds']);
        emit(BreedsLoaded(breeds: breeds, category: event.category));
      } else {
        emit(BreedsLoaded(breeds: const [], category: event.category));
      }
      
      // Emit lại state trước đó để giữ UI ổn định
      if (currentState is PetLoaded) {
        emit(currentState);
      }
    } catch (e) {
      emit(PetError('Lỗi load breeds: $e'));
    }
  }

  // Add new breed
  Future<void> _onAddBreed(
    AddBreedEvent event,
    Emitter<PetState> emit,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('Breed')
          .doc(event.category);
      
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({
          'breeds': FieldValue.arrayUnion([event.breed])
        });
      } else {
        await docRef.set({
          'breeds': [event.breed]
        });
      }
    } catch (e) {
      emit(PetError('Lỗi thêm breed: $e'));
    }
  }

  // ===== Helper Methods =====

  Future<String> _uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      debugPrint('[uploadImage] Start upload. bytes length=${imageBytes.length}');
      
      // Detect image format
      String ext = 'jpg';
      String contentType = 'image/jpeg';

      bool matches(List<int> sig) {
        if (imageBytes.length < sig.length) return false;
        for (int i = 0; i < sig.length; i++) {
          if (imageBytes[i] != sig[i]) return false;
        }
        return true;
      }

      if (matches([0x89, 0x50, 0x4E, 0x47])) {
        ext = 'png';
        contentType = 'image/png';
      } else if (imageBytes.length >= 2 &&
          imageBytes[0] == 0xFF &&
          imageBytes[1] == 0xD8) {
        ext = 'jpg';
        contentType = 'image/jpeg';
      } else if (matches([0x47, 0x49, 0x46, 0x38])) {
        ext = 'gif';
        contentType = 'image/gif';
      } else if (imageBytes.length >= 12 &&
          matches([0x52, 0x49, 0x46, 0x46]) &&
          imageBytes[8] == 0x57 &&
          imageBytes[9] == 0x45 &&
          imageBytes[10] == 0x42 &&
          imageBytes[11] == 0x50) {
        ext = 'webp';
        contentType = 'image/webp';
      }

      final baseFileName =
          fileName.contains('.') ? fileName.split('.').first : fileName;
      final finalFileName = '$baseFileName.$ext';

      final metadata = SettableMetadata(contentType: contentType);
      final storageRef = FirebaseStorage.instance.ref().child(finalFileName);
      final uploadTask = storageRef.putData(imageBytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return '';
    }
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is String) {
      return double.tryParse(price) ?? 0.0;
    } else if (price is num) {
      return price.toDouble();
    }
    return 0.0;
  }

  Future<void> _callTrainAPI() async {
    try {
      final uri = Uri.parse('https://train-pet-image.onrender.com/train');
      final response = await http.post(uri);
      if (response.statusCode == 200) {
        debugPrint('Train thành công!');
      } else {
        debugPrint('Train thất bại: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Lỗi train: $e');
    }
  }
}
