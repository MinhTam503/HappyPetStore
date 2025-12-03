import 'package:equatable/equatable.dart';

abstract class SpendingEvent extends Equatable {
  const SpendingEvent();

  @override
  List<Object?> get props => [];
}

class LoadSpending extends SpendingEvent {
  final String userId;
  final String period; // 'week', 'month', 'year'

  const LoadSpending({
    required this.userId,
    required this.period,
  });

  @override
  List<Object?> get props => [userId, period];
}
