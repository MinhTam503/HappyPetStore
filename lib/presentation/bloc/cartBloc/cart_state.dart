abstract class CartState {}

class CartLoading extends CartState {}

class CartLoaded extends CartState {
  final List<Map<String, dynamic>> items;
  final List<String> selectedIds;
  final String? message;
  final DateTime? messageTimestamp;

  CartLoaded(
    this.items, {
    this.message,
    List<String>? selectedIds,
  })  : selectedIds = selectedIds ?? const [],
        messageTimestamp = message != null ? DateTime.now() : null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartLoaded &&
        other.items.length == items.length &&
        other.selectedIds.length == selectedIds.length &&
        other.message == message;
  }

  @override
  int get hashCode =>
      items.length.hashCode ^ selectedIds.length.hashCode ^ message.hashCode;
}

class CartError extends CartState {
  final String message;

  CartError(this.message);
}
