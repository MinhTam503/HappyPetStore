abstract class CartEventWeb {}

class LoadCart extends CartEventWeb {
  final String email;
  LoadCart(this.email);
}

class AddToCart extends CartEventWeb {
  final String email;
  final Map<String, dynamic> item;
  AddToCart(this.email, this.item);
}

class RemoveFromCart extends CartEventWeb {
  final String email;
  final String id;
  RemoveFromCart(this.email, this.id);
}

class ClearCart extends CartEventWeb {
  final String email;
  ClearCart(this.email);
}
