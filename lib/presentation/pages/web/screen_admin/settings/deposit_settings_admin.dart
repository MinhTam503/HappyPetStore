import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/data/models/deposit_settings_model.dart';
import 'package:pet_shop/presentation/bloc/deposit_settings/deposit_settings_bloc.dart';
import 'package:pet_shop/presentation/bloc/deposit_settings/deposit_settings_event.dart';
import 'package:pet_shop/presentation/bloc/deposit_settings/deposit_settings_state.dart';

class DepositSettingsAdmin extends StatefulWidget {
  const DepositSettingsAdmin({Key? key}) : super(key: key);

  @override
  State<DepositSettingsAdmin> createState() => _DepositSettingsAdminState();
}

class _DepositSettingsAdminState extends State<DepositSettingsAdmin> {
  final _formKey = GlobalKey<FormState>();
  final _depositPercentageController = TextEditingController();
  final _maxDaysController = TextEditingController();
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    context.read<DepositSettingsBloc>().add(const LoadDepositSettings());
  }

  @override
  void dispose() {
    _depositPercentageController.dispose();
    _maxDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: BlocConsumer<DepositSettingsBloc, DepositSettingsState>(
        listener: (context, state) {
          if (state is DepositSettingsLoaded) {
            _depositPercentageController.text = state.settings.depositPercentage.toStringAsFixed(0);
            _maxDaysController.text = state.settings.maxReservationDays.toString();
            _isEnabled = state.settings.isEnabled;
          } else if (state is DepositSettingsError) {
            NotificationHelper.showError(context, l10n.error, state.message);
          }
        },
        builder: (context, state) {
          if (state is DepositSettingsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.settings, color: primaryColor, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      l10n.depositSettingsTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Settings Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enable/Disable Toggle
                          SwitchListTile(
                            title: Text(
                              l10n.enableReservations,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              'Bật hoặc tắt chức năng đặt trước cho khách hàng',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            value: _isEnabled,
                            activeColor: primaryColor,
                            onChanged: (value) {
                              setState(() => _isEnabled = value);
                            },
                          ),
                          const Divider(height: 32),

                          // Deposit Percentage
                          Text(
                            l10n.depositPercentage,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _depositPercentageController,
                            decoration: InputDecoration(
                              hintText: '30',
                              suffixText: '%',
                              helperText: 'Phần trăm tiền cọc mà khách hàng phải trả trước',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập phần trăm tiền cọc';
                              }
                              final num = int.tryParse(value);
                              if (num == null || num < 0 || num > 100) {
                                return l10n.invalidDepositPercentage;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Max Reservation Days
                          Text(
                            l10n.maxReservationDays(0).replaceAll('0', '').trim(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _maxDaysController,
                            decoration: InputDecoration(
                              hintText: '3',
                              suffixText: 'ngày',
                              helperText: 'Số ngày tối đa khách hàng có thể đặt trước',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập số ngày tối đa';
                              }
                              final num = int.tryParse(value);
                              if (num == null || num <= 0) {
                                return l10n.invalidMaxDays;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // Info Box
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Ví dụ: Nếu cài đặt 30% tiền cọc, khách hàng mua thú cưng 10.000.000đ sẽ phải trả trước 3.000.000đ',
                                    style: TextStyle(color: Colors.blue.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveSettings,
                              icon: const Icon(Icons.save),
                              label: Text(l10n.saveSettings),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _saveSettings() {
    if (!_formKey.currentState!.validate()) return;

    final depositPercentage = double.parse(_depositPercentageController.text);
    final maxDays = int.parse(_maxDaysController.text);

    final settings = DepositSettingsModel(
      id: 'default',
      depositPercentage: depositPercentage,
      maxReservationDays: maxDays,
      isEnabled: _isEnabled,
      updatedAt: DateTime.now(),
    );

    context.read<DepositSettingsBloc>().add(UpdateDepositSettings(settings));

    NotificationHelper.showSuccess(
      context,
      AppLocalizations.of(context)!.success,
      AppLocalizations.of(context)!.settingsUpdated,
    );
  }
}
