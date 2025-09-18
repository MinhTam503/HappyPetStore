abstract class FavEvent{}

class LoadFav extends FavEvent {
  final String userId;

  LoadFav(this.userId);
}

class AddToFav extends FavEvent {
  final String userId;
  final Map<String, dynamic> item;

  AddToFav(this.userId, this.item);
}

class RemoveFromFav extends FavEvent {
  final String userId;
  final String id;

  RemoveFromFav(this.userId, this.id);
}