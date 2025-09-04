abstract class CartStateWeb {}

class CartLoading extends CartStateWeb {}

class CartLoaded extends CartStateWeb {
  final List<Map<String, dynamic>> items;
  final String? message;

  CartLoaded(this.items, {this.message});
}

class CartError extends CartStateWeb {
  final String message;

  CartError(this.message);
}
