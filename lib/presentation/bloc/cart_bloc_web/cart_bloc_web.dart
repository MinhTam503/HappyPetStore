// lib/bloc/cart_bloc_web/cart_bloc_web.dart
import 'package:bloc/bloc.dart';
import 'package:pet_shop/presentation/bloc/cart_bloc_web/cart_event_web.dart';
import 'package:pet_shop/presentation/bloc/cart_bloc_web/cart_state_web.dart';


/// Web-only in-memory cart: đóng tab / refresh là mất.
/// Vẫn dùng CartEvent/CartState cũ để không phải sửa UI nhiều.
class CartBlocWeb extends Bloc<CartEventWeb, CartStateWeb> {
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  CartBlocWeb() : super(CartLoaded(const [])) {
    on<LoadCart>((event, emit) {
      // Trả về hiện tại, không tải ở đâu cả
      emit(CartLoaded(List<Map<String, dynamic>>.from(_items)));
    });

    on<AddToCart>((event, emit) {
      final exists = _items.any(
            (e) => e['productId']?.toString() == event.item['productId']?.toString(),
      );
      if (exists) {
        emit(CartLoaded(List<Map<String, dynamic>>.from(_items),
            message: 'Sản phẩm đã có trong giỏ hàng'));
        return;
      }
      _items.add(Map<String, dynamic>.from(event.item));
      emit(CartLoaded(List<Map<String, dynamic>>.from(_items),
          message: 'Đã thêm vào giỏ hàng'));
    });

    // Các event khác không dùng, nhưng nếu lỡ bắn thì vẫn phản hồi lại danh sách hiện tại.
    on<RemoveFromCart>((event, emit) {
      _items.removeWhere((e) => e['productId']?.toString() == event.id);
      emit(CartLoaded(List<Map<String, dynamic>>.from(_items),
          message: 'Đã xóa khỏi giỏ hàng'));
    });

    on<ClearCart>((event, emit) {
      _items.clear();
      emit(CartLoaded(const [], message: 'Đã làm trống giỏ hàng'));
    });
  }
}
