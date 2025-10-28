import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/data/models/favorite_pet.dart';

class FavBloc extends Bloc<FavEvent, FavState> {
  final _favRef = FirebaseFirestore.instance.collection('favorites');

  FavBloc() : super(FavLoading()) {
    on<LoadFav>(_onLoadFav);
    on<AddToFav>(_onAddToFav);
    on<RemoveFromFav>(_onRemoveFromFav);
  }

  Future<void> _onLoadFav(LoadFav event, Emitter<FavState> emit) async {
    emit(FavLoading());
    try {
      print("💖 Loading favorites for userId: ${event.userId}");
      final doc = await _favRef.doc(event.userId).get();
      final raw = (doc.exists ? doc['items'] : []) as List<dynamic>;
      // Map to model for consistency and sort by createdAtMillis desc
      final favs = raw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .map((m) => FavoritePet.fromMap(m))
          .toList();
      favs.sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
      print("💖 Found ${favs.length} favorite items");
      emit(FavLoaded(favs.map((f) => f.toMap()).toList()));
    } catch (e) {
      print("❌ Error loading favorites: $e");
      emit(FavError(e.toString()));
    }
  }

  Future<void> _onAddToFav(AddToFav event, Emitter<FavState> emit) async {
    try {
      print("💖 Adding to favorites for userId: ${event.userId}");
      final docRef = _favRef.doc(event.userId);
      final doc = await docRef.get();

      final items = doc.exists
          ? List<Map<String, dynamic>>.from(doc['items'])
          : <Map<String, dynamic>>[];

      final exists =
          items.any((item) => item['productId'] == event.item['productId']);
      if (exists) {
        print("💖 Product already in favorites");
        emit(FavLoaded(items, message: 'Sản phẩm đã có trong trang yêu thích'));
        return;
      } else {
        // Create model and serialize
        final now = DateTime.now();
        final fav = FavoritePet(
          productId: (event.item['productId'] ?? '').toString(),
          name: (event.item['name'] ?? '').toString(),
          imageUrl: (event.item['imageUrl'] ?? '').toString(),
          price: event.item['price'] ?? 0,
          createdAtMillis: now.millisecondsSinceEpoch,
          createdAt: now.toIso8601String(),
        );
        items.add(fav.toMap());
        await docRef.set({'items': items}, SetOptions(merge: true));
        print("💖 Added to favorites with timestamp: ${DateTime.now()}");
        emit(FavLoaded(items, message: 'Đã thêm vào yêu thích'));
      }
    } catch (e) {
      print("❌ Error adding to favorites: $e");
      emit(FavError(e.toString()));
    }
  }

  Future<void> _onRemoveFromFav(
      RemoveFromFav event, Emitter<FavState> emit) async {
    try {
      print("💖 Removing from favorites for userId: ${event.userId}");
      final docRef = _favRef.doc(event.userId);
      final doc = await docRef.get();

      final items = List<Map<String, dynamic>>.from(doc['items']);

      items.removeWhere((item) => item["productId"] == event.id);

      await docRef.set({'items': items}, SetOptions(merge: true));
      print("💖 Removed from favorites successfully");
      emit(FavLoaded(items, message: 'Đã xóa khỏi yêu thích'));
    } catch (e) {
      print("❌ Error removing from favorites: $e");
      emit(FavError(e.toString()));
    }
  }
}
