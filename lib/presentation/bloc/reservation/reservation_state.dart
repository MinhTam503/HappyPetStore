import 'package:equatable/equatable.dart';
import 'package:pet_shop/data/models/reservation_model.dart';

/// States for Reservation BLoC
abstract class ReservationState extends Equatable {
  const ReservationState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ReservationInitial extends ReservationState {
  const ReservationInitial();
}

/// Loading state
class ReservationLoading extends ReservationState {
  const ReservationLoading();
}

/// Loaded state with reservations
class ReservationLoaded extends ReservationState {
  final List<ReservationModel> reservations;

  const ReservationLoaded(this.reservations);

  @override
  List<Object?> get props => [reservations];
}

/// Success state (for create, update, delete operations)
class ReservationSuccess extends ReservationState {
  final String message;
  final String? reservationId;

  const ReservationSuccess(this.message, {this.reservationId});

  @override
  List<Object?> get props => [message, reservationId];
}

/// Error state
class ReservationError extends ReservationState {
  final String message;

  const ReservationError(this.message);

  @override
  List<Object?> get props => [message];
}
