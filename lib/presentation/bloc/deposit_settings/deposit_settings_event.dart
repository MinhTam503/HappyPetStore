import 'package:equatable/equatable.dart';
import 'package:pet_shop/data/models/deposit_settings_model.dart';

/// Events for DepositSettings BLoC
abstract class DepositSettingsEvent extends Equatable {
  const DepositSettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Load deposit settings
class LoadDepositSettings extends DepositSettingsEvent {
  const LoadDepositSettings();
}

/// Update deposit settings (admin only)
class UpdateDepositSettings extends DepositSettingsEvent {
  final DepositSettingsModel settings;

  const UpdateDepositSettings(this.settings);

  @override
  List<Object?> get props => [settings];
}
