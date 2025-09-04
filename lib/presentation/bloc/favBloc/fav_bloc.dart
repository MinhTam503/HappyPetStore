import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_state.dart';

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
      final doc = await _favRef.doc(event.email).get();
      final items = (doc.exists ? doc['items'] : []) as List<dynamic>;
      emit(FavLoaded(List<Map<String, dynamic>>.from(items)));
    } catch (e) {
      emit(FavError(e.toString()));
    }
  }

  Future<void> _onAddToFav(AddToFav event, Emitter<FavState> emit) async {
    try {
      final docRef = _favRef.doc(event.email);
      final doc = await docRef.get();

      final items = doc.exists
          ? List<Map<String, dynamic>>.from(doc['items'])
          : <Map<String, dynamic>>[];

      final exists = items.any(
              (item) => item['productId'] == event.item['productId']);
      if (exists) {
        emit(FavLoaded(items, message: 'Sản phẩm đã có trong trang yêu thích'));
        return;
      } else {
        items.add(event.item);
        await docRef.set({'items': items});
        emit(FavLoaded(items, message: 'Đã thêm vào yêu thích'));
      }

    } catch (e) {
      emit(FavError(e.toString()));
    }
  }

  Future<void> _onRemoveFromFav(
      RemoveFromFav event, Emitter<FavState> emit) async {
    try {
      final docRef = _favRef.doc(event.email);
      final doc = await docRef.get();

      final items = List<Map<String, dynamic>>.from(doc['items']);

      items.removeWhere((item) => item["productId"] == event.id);

      await docRef.set({'items': items});
      emit(FavLoaded(items, message: 'Đã xóa khỏi giỏ hàng'));
    } catch (e) {
      emit(FavError(e.toString()));
    }
  }
}
