import 'package:equatable/equatable.dart';

class RecentOrderItem extends Equatable {
  final String id;
  final String customerName;
  final String status;
  final double totalAmount;
  final String source; // 'Mobile' or 'Web'
  final DateTime? timestamp;

  const RecentOrderItem({
    required this.id,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.source,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, customerName, status, totalAmount, source, timestamp];
}

abstract class RecentOrdersState extends Equatable {
  const RecentOrdersState();

  @override
  List<Object?> get props => [];
}

class RecentOrdersInitial extends RecentOrdersState {}
class RecentOrdersLoading extends RecentOrdersState {}
class RecentOrdersEmpty extends RecentOrdersState {}
class RecentOrdersFailure extends RecentOrdersState {
  final String message;
  const RecentOrdersFailure(this.message);

  @override
  List<Object?> get props => [message];
}
class RecentOrdersSuccess extends RecentOrdersState {
  final List<RecentOrderItem> orders;
  const RecentOrdersSuccess(this.orders);

  @override
  List<Object?> get props => [orders];
}
