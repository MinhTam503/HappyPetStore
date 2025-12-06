import 'package:equatable/equatable.dart';
import 'package:pet_shop/data/models/deposit_settings_model.dart';

/// States for DepositSettings BLoC
abstract class DepositSettingsState extends Equatable {
  const DepositSettingsState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class DepositSettingsInitial extends DepositSettingsState {
  const DepositSettingsInitial();
}

/// Loading state
class DepositSettingsLoading extends DepositSettingsState {
  const DepositSettingsLoading();
}

/// Loaded state
class DepositSettingsLoaded extends DepositSettingsState {
  final DepositSettingsModel settings;

  const DepositSettingsLoaded(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Success state (for update operations)
class DepositSettingsUpdateSuccess extends DepositSettingsState {
  final String message;

  const DepositSettingsUpdateSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

/// Error state
class DepositSettingsError extends DepositSettingsState {
  final String message;

  const DepositSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}
