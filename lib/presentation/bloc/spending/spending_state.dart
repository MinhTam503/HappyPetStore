import 'package:equatable/equatable.dart';

abstract class SpendingState extends Equatable {
  const SpendingState();

  @override
  List<Object?> get props => [];
}

class SpendingInitial extends SpendingState {}

class SpendingLoading extends SpendingState {}

class SpendingLoaded extends SpendingState {
  final Map<String, SpendingData> data; // key: period identifier (week/month/year)
  final String period;

  const SpendingLoaded({
    required this.data,
    required this.period,
  });

  @override
  List<Object?> get props => [data, period];
}

class SpendingError extends SpendingState {
  final String message;

  const SpendingError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Data cho một period (ngày/tuần/tháng/năm)
class SpendingData {
  final double totalAmount;
  final List<OrderItem> orders;

  SpendingData({
    required this.totalAmount,
    required this.orders,
  });
}

/// Thông tin đơn hàng đã mua
class OrderItem {
  final String orderId;
  final double amount;
  final DateTime timestamp;
  final List<PetItem> pets;

  OrderItem({
    required this.orderId,
    required this.amount,
    required this.timestamp,
    required this.pets,
  });
}

/// Thông tin thú cưng trong đơn
class PetItem {
  final String petId;
  final String name;
  final String? imageUrl;
  final int quantity;
  final double price;

  PetItem({
    required this.petId,
    required this.name,
    this.imageUrl,
    required this.quantity,
    required this.price,
  });
}
