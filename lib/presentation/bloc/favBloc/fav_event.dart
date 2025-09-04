abstract class FavEvent{}

class LoadFav extends FavEvent {
  final String email;

  LoadFav(this.email);
}

class AddToFav extends FavEvent {
  final String email;
  final Map<String, dynamic> item;

  AddToFav(this.email, this.item);
}

class RemoveFromFav extends FavEvent {
  final String email;
  final String id;

  RemoveFromFav(this.email, this.id);
}