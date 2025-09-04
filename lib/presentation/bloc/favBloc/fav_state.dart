abstract class FavState {}

class FavLoading extends FavState {}

class FavLoaded extends FavState {
  final List<Map<String, dynamic>> items;
  final String? message;

  FavLoaded(this.items, {this.message});
}


class FavError extends FavState {
  final String message;

  FavError(this.message);
}
