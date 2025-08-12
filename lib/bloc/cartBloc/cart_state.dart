abstract class CartState {}

class CartLoading extends CartState {}

class CartLoaded extends CartState {
  final List<Map<String, dynamic>> items;
  final String? message;

  CartLoaded(this.items, {this.message});
}


class CartError extends CartState {
  final String message;

  CartError(this.message);
}
