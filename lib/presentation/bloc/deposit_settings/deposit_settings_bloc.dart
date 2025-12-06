import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/services/reservation_service.dart';
import 'deposit_settings_event.dart';
import 'deposit_settings_state.dart';

/// BLoC for managing deposit settings
class DepositSettingsBloc extends Bloc<DepositSettingsEvent, DepositSettingsState> {
  final ReservationService _reservationService;

  DepositSettingsBloc({ReservationService? reservationService})
      : _reservationService = reservationService ?? ReservationService(),
        super(const DepositSettingsInitial()) {
    on<LoadDepositSettings>(_onLoadDepositSettings);
    on<UpdateDepositSettings>(_onUpdateDepositSettings);
  }

  /// Load deposit settings
  Future<void> _onLoadDepositSettings(
    LoadDepositSettings event,
    Emitter<DepositSettingsState> emit,
  ) async {
    emit(const DepositSettingsLoading());
    try {
      final settings = await _reservationService.getDepositSettings();
      emit(DepositSettingsLoaded(settings));
    } catch (e) {
      emit(DepositSettingsError('Lỗi khi tải cài đặt: ${e.toString()}'));
    }
  }

  /// Update deposit settings
  Future<void> _onUpdateDepositSettings(
    UpdateDepositSettings event,
    Emitter<DepositSettingsState> emit,
  ) async {
    emit(const DepositSettingsLoading());
    try {
      await _reservationService.updateDepositSettings(event.settings);
      emit(const DepositSettingsUpdateSuccess('Cập nhật thành công!'));
      // Reload settings
      add(const LoadDepositSettings());
    } catch (e) {
      emit(DepositSettingsError('Lỗi khi cập nhật: ${e.toString()}'));
    }
  }
}
