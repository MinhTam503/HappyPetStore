abstract class CartEvent {}

class LoadCart extends CartEvent {
  final String email;

  LoadCart(this.email);
}

class AddToCart extends CartEvent {
  final String email;
  final Map<String, dynamic> item;

  AddToCart(this.email, this.item);
}

class RemoveFromCart extends CartEvent {
  final String email;
  final String id;

  RemoveFromCart(this.email, this.id);
}

class ClearCart extends CartEvent {
  final String email;
  ClearCart(this.email);
}

class UpdateCartSelection extends CartEvent {
  final String email;
  final List<String> selectedIds;
  UpdateCartSelection(this.email, this.selectedIds);
}
