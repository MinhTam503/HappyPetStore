import 'package:equatable/equatable.dart';
import 'package:pet_shop/data/models/reservation_model.dart';

/// Events for Reservation BLoC
abstract class ReservationEvent extends Equatable {
  const ReservationEvent();

  @override
  List<Object?> get props => [];
}

/// Load user's reservations
class LoadUserReservations extends ReservationEvent {
  final String userId;

  const LoadUserReservations(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Load all reservations (admin)
class LoadAllReservations extends ReservationEvent {
  const LoadAllReservations();
}

/// Create new reservation
class CreateReservation extends ReservationEvent {
  final ReservationModel reservation;

  const CreateReservation(this.reservation);

  @override
  List<Object?> get props => [reservation];
}

/// Confirm reservation (admin)
class ConfirmReservation extends ReservationEvent {
  final String reservationId;
  final String? adminNote;

  const ConfirmReservation(this.reservationId, {this.adminNote});

  @override
  List<Object?> get props => [reservationId, adminNote];
}

/// Cancel reservation
class CancelReservation extends ReservationEvent {
  final String reservationId;
  final String? cancelReason;
  final bool isAdmin;

  const CancelReservation(
    this.reservationId, {
    this.cancelReason,
    this.isAdmin = false,
  });

  @override
  List<Object?> get props => [reservationId, cancelReason, isAdmin];
}

/// Complete reservation (customer picked up)
class CompleteReservation extends ReservationEvent {
  final String reservationId;
  final double? additionalPayment;
  final String? adminNote;

  const CompleteReservation(
    this.reservationId, {
    this.additionalPayment,
    this.adminNote,
  });

  @override
  List<Object?> get props => [reservationId, additionalPayment, adminNote];
}

/// Update reservation payment
class UpdateReservationPayment extends ReservationEvent {
  final String reservationId;
  final double paidAmount;

  const UpdateReservationPayment(this.reservationId, this.paidAmount);

  @override
  List<Object?> get props => [reservationId, paidAmount];
}

/// Check and update expired reservations
class CheckExpiredReservations extends ReservationEvent {
  const CheckExpiredReservations();
}
