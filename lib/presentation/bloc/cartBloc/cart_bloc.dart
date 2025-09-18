import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_event.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final _cartRef = FirebaseFirestore.instance.collection('carts');

  CartBloc() : super(CartLoading()) {
    on<LoadCart>(_onLoadCart);
    on<AddToCart>(_onAddToCart);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<ClearCart>(_onClearCart);
  }

  Future<void> _onLoadCart(LoadCart event, Emitter<CartState> emit) async {
    emit(CartLoading());
    try {
      final doc = await _cartRef.doc(event.email).get();
      final items = (doc.exists ? doc['items'] : []) as List<dynamic>;
      emit(CartLoaded(List<Map<String, dynamic>>.from(items)));
    } catch (e) {
      emit(CartError(e.toString()));
    }
  }

  Future<void> _onAddToCart(AddToCart event, Emitter<CartState> emit) async {
    try {
      final docRef = _cartRef.doc(event.email);
      final doc = await docRef.get();

      final items = doc.exists
          ? List<Map<String, dynamic>>.from(doc['items'])
          : <Map<String, dynamic>>[];

      final exists = items.any(
              (item) => item['productId'] == event.item['productId']);
      
      if (exists) {
        emit(CartLoaded(items, message: 'Sản phẩm đã có trong giỏ hàng'));
        return;
      } else {
        items.add(event.item);
        await docRef.set({'items': items});
        emit(CartLoaded(items, message: 'Đã thêm vào giỏ hàng'));
      }
    } catch (e) {
      emit(CartError(e.toString()));
    }
  }

  Future<void> _onRemoveFromCart(
      RemoveFromCart event, Emitter<CartState> emit) async {
    try {
      final docRef = _cartRef.doc(event.email);
      final doc = await docRef.get();

      final items = List<Map<String, dynamic>>.from(doc['items']);

      items.removeWhere((item) => item["productId"] == event.id); // đúng key

      await docRef.set({'items': items});
      emit(CartLoaded(items, message: 'Đã xóa khỏi giỏ hàng'));
    } catch (e) {
      emit(CartError(e.toString()));
    }
  }

  Future<void> _onClearCart(ClearCart event, Emitter<CartState> emit) async {
    try {
      final docRef = _cartRef.doc(event.email);
      await docRef.set({'items': []});
      emit(CartLoaded([]));
    } catch (e) {
      emit(CartError(e.toString()));
    }
  }
}
