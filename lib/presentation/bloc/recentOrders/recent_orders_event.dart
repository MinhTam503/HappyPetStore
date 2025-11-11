import 'package:equatable/equatable.dart';

abstract class RecentOrdersEvent extends Equatable {
  const RecentOrdersEvent();

  @override
  List<Object?> get props => [];
}

class LoadRecentOrders extends RecentOrdersEvent {
  final int limit;
  final bool mobileOnly; // true to match dashboard requirement
  const LoadRecentOrders({this.limit = 6, this.mobileOnly = true});

  @override
  List<Object?> get props => [limit, mobileOnly];
}
