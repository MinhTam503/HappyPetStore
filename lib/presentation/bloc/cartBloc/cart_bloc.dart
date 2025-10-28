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
    on<UpdateCartSelection>(_onUpdateSelection);
  }

  Future<void> _onLoadCart(LoadCart event, Emitter<CartState> emit) async {
    emit(CartLoading());
    try {
      final doc = await _cartRef.doc(event.email).get();
    final data = doc.data();
    final items = (doc.exists && data != null && data['items'] is List)
      ? List<dynamic>.from(data['items'] as List)
      : const <dynamic>[];
    final selected = (doc.exists && data != null && data['selectedProductIds'] is List)
      ? List<String>.from(data['selectedProductIds'] as List)
      : <String>[];
      // Sort by createdAtMillis desc; fallback to createdAt ISO; else 0
      final list = List<Map<String, dynamic>>.from(items);
      list.sort((a, b) {
        int aAt = 0;
        int bAt = 0;
        if (a['createdAtMillis'] is num) aAt = (a['createdAtMillis'] as num).toInt();
        if (b['createdAtMillis'] is num) bAt = (b['createdAtMillis'] as num).toInt();
        if (aAt == 0 && a['createdAt'] is String) {
          final dt = DateTime.tryParse(a['createdAt'] as String);
          if (dt != null) aAt = dt.millisecondsSinceEpoch;
        }
        if (bAt == 0 && b['createdAt'] is String) {
          final dt = DateTime.tryParse(b['createdAt'] as String);
          if (dt != null) bAt = dt.millisecondsSinceEpoch;
        }
        return bAt.compareTo(aAt);
      });
      emit(CartLoaded(list, selectedIds: selected));
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

      final exists =
          items.any((item) => item['productId'] == event.item['productId']);

      if (exists) {
        emit(CartLoaded(items, message: 'Sản phẩm đã có trong giỏ hàng'));
        return;
      } else {
        final newItem = Map<String, dynamic>.from(event.item);
        // Ensure timestamps exist for ordering
        newItem['createdAtMillis'] = newItem['createdAtMillis'] ?? DateTime.now().millisecondsSinceEpoch;
        newItem['createdAt'] = newItem['createdAt'] ?? DateTime.now().toIso8601String();
        items.add(newItem);
        await docRef.set({'items': items}, SetOptions(merge: true));
        // Localization context not directly available here; keep key-like English fallback or integrate via UI.
        // Keep selected ids as-is if available
        final docLatest = await docRef.get();
        final selected = (docLatest.exists && (docLatest.data()?['selectedProductIds'] != null))
            ? List<String>.from(docLatest.data()?['selectedProductIds'] as List)
            : <String>[];
        emit(CartLoaded(items, selectedIds: selected, message: 'Đã thêm vào giỏ hàng'));
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

    final data = doc.data();
    final items = (data != null && data['items'] is List)
      ? List<Map<String, dynamic>>.from(data['items'] as List)
      : <Map<String, dynamic>>[];
      items.removeWhere((item) => item["productId"] == event.id);

      // Update selected ids as well
    final selected = (data != null && data['selectedProductIds'] is List)
      ? List<String>.from(data['selectedProductIds'] as List)
      : <String>[];
      selected.removeWhere((pid) => pid == event.id);

      await docRef.set({'items': items, 'selectedProductIds': selected}, SetOptions(merge: true));
      emit(CartLoaded(items, selectedIds: selected, message: 'Đã xóa khỏi giỏ hàng'));
    } catch (e) {
      emit(CartError(e.toString()));
    }
  }

  Future<void> _onClearCart(ClearCart event, Emitter<CartState> emit) async {
    try {
      final docRef = _cartRef.doc(event.email);
      await docRef.set({'items': [], 'selectedProductIds': []}, SetOptions(merge: true));
      emit(CartLoaded([], selectedIds: []));
    } catch (e) {
      emit(CartError(e.toString()));
    }
  }

  Future<void> _onUpdateSelection(UpdateCartSelection event, Emitter<CartState> emit) async {
    try {
      final docRef = _cartRef.doc(event.email);
    final doc = await docRef.get();
    final data = doc.data();
    final items = (doc.exists && data != null && data['items'] is List)
      ? List<dynamic>.from(data['items'] as List)
      : const <dynamic>[];
      await docRef.set({'selectedProductIds': event.selectedIds}, SetOptions(merge: true));

      // Reuse current sort for items
      final list = List<Map<String, dynamic>>.from(items);
      list.sort((a, b) {
        int aAt = 0;
        int bAt = 0;
        if (a['createdAtMillis'] is num) aAt = (a['createdAtMillis'] as num).toInt();
        if (b['createdAtMillis'] is num) bAt = (b['createdAtMillis'] as num).toInt();
        if (aAt == 0 && a['createdAt'] is String) {
          final dt = DateTime.tryParse(a['createdAt'] as String);
          if (dt != null) aAt = dt.millisecondsSinceEpoch;
        }
        if (bAt == 0 && b['createdAt'] is String) {
          final dt = DateTime.tryParse(b['createdAt'] as String);
          if (dt != null) bAt = dt.millisecondsSinceEpoch;
        }
        return bAt.compareTo(aAt);
      });
      emit(CartLoaded(list, selectedIds: List<String>.from(event.selectedIds)));
    } catch (e) {
      emit(CartError(e.toString()));
    }
  }
}
