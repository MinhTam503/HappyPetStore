import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/data/models/reservation_model.dart';
import 'package:pet_shop/services/reservation_service.dart';
import 'reservation_event.dart';
import 'reservation_state.dart';

/// BLoC for managing reservations
class ReservationBloc extends Bloc<ReservationEvent, ReservationState> {
  final ReservationService _reservationService;
  StreamSubscription<List<ReservationModel>>? _reservationSubscription;

  ReservationBloc({ReservationService? reservationService})
      : _reservationService = reservationService ?? ReservationService(),
        super(const ReservationInitial()) {
    on<LoadUserReservations>(_onLoadUserReservations);
    on<LoadAllReservations>(_onLoadAllReservations);
    on<CreateReservation>(_onCreateReservation);
    on<ConfirmReservation>(_onConfirmReservation);
    on<CancelReservation>(_onCancelReservation);
    on<CompleteReservation>(_onCompleteReservation);
    on<UpdateReservationPayment>(_onUpdateReservationPayment);
    on<CheckExpiredReservations>(_onCheckExpiredReservations);
  }

  /// Load user's reservations
  Future<void> _onLoadUserReservations(
    LoadUserReservations event,
    Emitter<ReservationState> emit,
  ) async {
    emit(const ReservationLoading());
    
    await _reservationSubscription?.cancel();
    
    await emit.forEach<List<ReservationModel>>(
      _reservationService.getUserReservations(event.userId),
      onData: (reservations) => ReservationLoaded(reservations),
      onError: (error, stackTrace) => ReservationError(error.toString()),
    );
  }

  /// Load all reservations (admin)
  Future<void> _onLoadAllReservations(
    LoadAllReservations event,
    Emitter<ReservationState> emit,
  ) async {
    emit(const ReservationLoading());
    
    await _reservationSubscription?.cancel();
    
    await emit.forEach<List<ReservationModel>>(
      _reservationService.getAllReservations(),
      onData: (reservations) => ReservationLoaded(reservations),
      onError: (error, stackTrace) => ReservationError(error.toString()),
    );
  }

  /// Create new reservation
  Future<void> _onCreateReservation(
    CreateReservation event,
    Emitter<ReservationState> emit,
  ) async {
    try {
      emit(const ReservationLoading());
      
      final reservationId = await _reservationService.createReservation(
        event.reservation,
      );
      
      emit(ReservationSuccess(
        'Đặt trước thành công! Vui lòng chờ xác nhận.',
        reservationId: reservationId,
      ));
    } catch (e) {
      emit(ReservationError('Lỗi khi đặt trước: ${e.toString()}'));
    }
  }

  /// Confirm reservation (admin)
  Future<void> _onConfirmReservation(
    ConfirmReservation event,
    Emitter<ReservationState> emit,
  ) async {
    try {
      emit(const ReservationLoading());
      
      await _reservationService.confirmReservation(
        event.reservationId,
        adminNote: event.adminNote,
      );
      
      emit(const ReservationSuccess('Đã xác nhận đơn đặt trước!'));
    } catch (e) {
      emit(ReservationError('Lỗi khi xác nhận: ${e.toString()}'));
    }
  }

  /// Cancel reservation
  Future<void> _onCancelReservation(
    CancelReservation event,
    Emitter<ReservationState> emit,
  ) async {
    try {
      emit(const ReservationLoading());
      
      await _reservationService.cancelReservation(
        event.reservationId,
        cancelReason: event.cancelReason,
        isAdmin: event.isAdmin,
      );
      
      emit(const ReservationSuccess('Đã hủy đơn đặt trước!'));
    } catch (e) {
      emit(ReservationError('Lỗi khi hủy: ${e.toString()}'));
    }
  }

  /// Complete reservation
  Future<void> _onCompleteReservation(
    CompleteReservation event,
    Emitter<ReservationState> emit,
  ) async {
    try {
      emit(const ReservationLoading());
      
      await _reservationService.completeReservation(
        event.reservationId,
        additionalPayment: event.additionalPayment,
        adminNote: event.adminNote,
      );
      
      emit(const ReservationSuccess('Đã hoàn thành đơn đặt trước!'));
    } catch (e) {
      emit(ReservationError('Lỗi khi hoàn thành: ${e.toString()}'));
    }
  }

  /// Update reservation payment
  Future<void> _onUpdateReservationPayment(
    UpdateReservationPayment event,
    Emitter<ReservationState> emit,
  ) async {
    try {
      emit(const ReservationLoading());
      
      await _reservationService.updateReservationPayment(
        event.reservationId,
        event.paidAmount,
      );
      
      emit(const ReservationSuccess('Đã cập nhật thanh toán!'));
    } catch (e) {
      emit(ReservationError('Lỗi khi cập nhật thanh toán: ${e.toString()}'));
    }
  }

  /// Check and update expired reservations
  Future<void> _onCheckExpiredReservations(
    CheckExpiredReservations event,
    Emitter<ReservationState> emit,
  ) async {
    try {
      await _reservationService.checkAndUpdateExpiredReservations();
    } catch (e) {
      print('Error checking expired reservations: $e');
    }
  }

  @override
  Future<void> close() {
    _reservationSubscription?.cancel();
    return super.close();
  }
}
