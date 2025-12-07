import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/data/models/reservation_model.dart';
import 'package:pet_shop/data/models/deposit_settings_model.dart';
import 'package:pet_shop/presentation/bloc/reservation/reservation_bloc.dart';
import 'package:pet_shop/presentation/bloc/reservation/reservation_event.dart';
import 'package:pet_shop/presentation/bloc/reservation/reservation_state.dart';
import 'package:pet_shop/presentation/bloc/deposit_settings/deposit_settings_bloc.dart';
import 'package:pet_shop/presentation/bloc/deposit_settings/deposit_settings_event.dart';
import 'package:pet_shop/presentation/bloc/deposit_settings/deposit_settings_state.dart';

class ReservationsAdmin extends StatefulWidget {
  const ReservationsAdmin({Key? key}) : super(key: key);

  @override
  State<ReservationsAdmin> createState() => _ReservationsAdminState();
}

class _ReservationsAdminState extends State<ReservationsAdmin> {
  ReservationStatus? _selectedStatus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<ReservationBloc>().add(const LoadAllReservations());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.book_online,
                        color: primaryColor, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      l10n.reservationsAdmin,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Settings Icon Button
                    IconButton(
                      icon: const Icon(Icons.settings, color: primaryColor),
                      tooltip: l10n.depositSettings,
                      onPressed: () => _showDepositSettingsDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Search
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: l10n.searchByCustomer,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value.toLowerCase());
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Status Filter
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<ReservationStatus?>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: l10n.filterByStatus,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n.allStatuses),
                          ),
                          ...ReservationStatus.values.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(_getStatusText(status, l10n)),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: BlocConsumer<ReservationBloc, ReservationState>(
              listener: (context, state) {
                if (state is ReservationSuccess) {
                  NotificationHelper.showSuccess(
                    context,
                    l10n.success,
                    'Thao tác thành công',
                  );
                  context
                      .read<ReservationBloc>()
                      .add(const LoadAllReservations());
                } else if (state is ReservationError) {
                  NotificationHelper.showError(
                    context,
                    l10n.error,
                    state.message,
                  );
                }
              },
              builder: (context, state) {
                if (state is ReservationLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ReservationLoaded) {
                  final filteredReservations = state.reservations.where((r) {
                    final matchesStatus =
                        _selectedStatus == null || r.status == _selectedStatus;
                    final matchesSearch = _searchQuery.isEmpty ||
                        r.displayName.toLowerCase().contains(_searchQuery) ||
                        r.email.toLowerCase().contains(_searchQuery) ||
                        r.phone.toLowerCase().contains(_searchQuery);
                    return matchesStatus && matchesSearch;
                  }).toList();

                  if (filteredReservations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noReservations,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildReservationsTable(
                        filteredReservations, l10n, theme),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsTable(
    List<ReservationModel> reservations,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text(l10n.reservationId,
                        style: _headerStyle.copyWith(
                            color: theme.colorScheme.onSurface))),
                Expanded(
                    flex: 3,
                    child: Text(l10n.customerInfo,
                        style: _headerStyle.copyWith(
                            color: theme.colorScheme.onSurface))),
                Expanded(
                    flex: 2,
                    child: Text(l10n.pickupDate,
                        style: _headerStyle.copyWith(
                            color: theme.colorScheme.onSurface))),
                Expanded(
                    flex: 2,
                    child: Text(l10n.totalAmountLabel,
                        style: _headerStyle.copyWith(
                            color: theme.colorScheme.onSurface))),
                Expanded(
                    flex: 2,
                    child: Text(l10n.statusLabel,
                        style: _headerStyle.copyWith(
                            color: theme.colorScheme.onSurface))),
                Expanded(
                    flex: 3,
                    child: Text(l10n.actions,
                        style: _headerStyle.copyWith(
                            color: theme.colorScheme.onSurface))),
              ],
            ),
          ),
          // Table Body
          ...reservations.map(
              (reservation) => _buildReservationRow(reservation, l10n, theme)),
        ],
      ),
    );
  }

  Widget _buildReservationRow(
    ReservationModel reservation,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // ID
          Expanded(
            flex: 2,
            child: SelectableText(
              reservation.id.substring(0, 8),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          // Customer Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  reservation.phone,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          // Pickup Date
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd/MM/yyyy').format(reservation.pickupDate),
            ),
          ),
          // Total Amount
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CurrencyHelper.formatVND(reservation.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${l10n.paidAmount}: ${CurrencyHelper.formatVND(reservation.paidAmount)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: _buildStatusChip(reservation.status, l10n),
          ),
          // Actions
          Expanded(
            flex: 3,
            child: _buildActionButtons(reservation, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ReservationStatus status, AppLocalizations l10n) {
    Color color;
    IconData icon;

    switch (status) {
      case ReservationStatus.pending:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case ReservationStatus.confirmed:
        color = Colors.blue;
        icon = Icons.check_circle_outline;
        break;
      case ReservationStatus.completed:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case ReservationStatus.cancelled:
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case ReservationStatus.expired:
        color = Colors.grey;
        icon = Icons.access_time;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            _getStatusText(status, l10n),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      ReservationModel reservation, AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reservation.status == ReservationStatus.pending) ...[
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            tooltip: l10n.confirmPickup,
            onPressed: () => _confirmReservation(reservation, l10n),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: l10n.cancel,
            onPressed: () => _cancelReservation(reservation, l10n),
          ),
        ],
        if (reservation.status == ReservationStatus.confirmed) ...[
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.blue),
            tooltip: l10n.markAsCompleted,
            onPressed: () => _completeReservation(reservation, l10n),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: l10n.cancel,
            onPressed: () => _cancelReservation(reservation, l10n),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.grey),
          tooltip: l10n.viewReservationDetails,
          onPressed: () => _showReservationDetails(reservation, l10n),
        ),
      ],
    );
  }

  void _confirmReservation(
      ReservationModel reservation, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmReservationTitle),
        content: Text(l10n.confirmReservationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<ReservationBloc>()
                  .add(ConfirmReservation(reservation.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text(
              l10n.confirm,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _completeReservation(
      ReservationModel reservation, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.completeReservationTitle),
        content: Text(l10n.completeReservationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<ReservationBloc>()
                  .add(CompleteReservation(reservation.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text(
              l10n.confirm,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelReservation(ReservationModel reservation, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelReservation),
        content: Text(l10n.cancelReservationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<ReservationBloc>()
                  .add(CancelReservation(reservation.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.cancel,style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  void _showReservationDetails(
      ReservationModel reservation, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.viewReservationDetails),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('ID', reservation.id),
                _buildDetailRow(l10n.customerInfo, reservation.displayName),
                _buildDetailRow(l10n.email, reservation.email),
                _buildDetailRow(l10n.phone, reservation.phone),
                _buildDetailRow(l10n.pickupDate,
                    DateFormat('dd/MM/yyyy').format(reservation.pickupDate)),
                _buildDetailRow(l10n.totalAmountLabel,
                    CurrencyHelper.formatVND(reservation.totalAmount)),
                _buildDetailRow(l10n.depositAmount,
                    CurrencyHelper.formatVND(reservation.depositAmount)),
                _buildDetailRow(l10n.paidAmount,
                    CurrencyHelper.formatVND(reservation.paidAmount)),
                _buildDetailRow(l10n.remainingAmount,
                    CurrencyHelper.formatVND(reservation.remainingAmount)),
                _buildDetailRow(l10n.paymentMethod, reservation.paymentMethod),
                const SizedBox(height: 16),
                Text(
                  l10n.items,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...reservation.items.map((item) => ListTile(
                      leading: item['imageUrl'] != null
                          ? Image.network(item['imageUrl'],
                              width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.pets),
                      title: Text(item['name'] ?? ''),
                      subtitle: Text('${item['breed']} - ${item['category']}'),
                      trailing: Text(CurrencyHelper.formatVND(item['price'])),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  // Show deposit settings dialog
  void _showDepositSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => const _DepositSettingsDialog(),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  String _getStatusText(ReservationStatus status, AppLocalizations l10n) {
    switch (status) {
      case ReservationStatus.pending:
        return l10n.pending;
      case ReservationStatus.confirmed:
        return 'Đã xác nhận';
      case ReservationStatus.completed:
        return l10n.completed;
      case ReservationStatus.cancelled:
        return l10n.cancelled;
      case ReservationStatus.expired:
        return 'Hết hạn';
    }
  }

  TextStyle get _headerStyle => const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
      );
}

// Deposit Settings Dialog Widget
class _DepositSettingsDialog extends StatefulWidget {
  const _DepositSettingsDialog({Key? key}) : super(key: key);

  @override
  State<_DepositSettingsDialog> createState() => _DepositSettingsDialogState();
}

class _DepositSettingsDialogState extends State<_DepositSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _depositPercentageController = TextEditingController();
  final _depositFixedAmountController = TextEditingController();
  final _maxDaysController = TextEditingController();
  bool _isEnabled = true;
  bool _isLoading = true;
  DepositType _depositType = DepositType.percentage;

  @override
  void initState() {
    super.initState();
    context.read<DepositSettingsBloc>().add(const LoadDepositSettings());
  }

  @override
  void dispose() {
    _depositPercentageController.dispose();
    _depositFixedAmountController.dispose();
    _maxDaysController.dispose();
    super.dispose();
  }

  void _loadSettings(DepositSettingsModel settings) {
    if (_isLoading) {
      _depositType = settings.depositType;
      _depositPercentageController.text = settings.depositPercentage.toString();
      _depositFixedAmountController.text =
          settings.depositFixedAmount.toString();
      _maxDaysController.text = settings.maxReservationDays.toString();
      _isEnabled = settings.isEnabled;
      _isLoading = false;
    }
  }

  void _saveSettings() {
    if (!_formKey.currentState!.validate()) return;

    final settings = DepositSettingsModel(
      id: 'reservationSettings',
      depositType: _depositType,
      depositPercentage: double.parse(_depositPercentageController.text),
      depositFixedAmount: double.parse(_depositFixedAmountController.text),
      maxReservationDays: int.parse(_maxDaysController.text),
      isEnabled: _isEnabled,
      updatedAt: DateTime.now(),
    );

    context.read<DepositSettingsBloc>().add(UpdateDepositSettings(settings));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocListener<DepositSettingsBloc, DepositSettingsState>(
      listener: (context, state) {
        if (state is DepositSettingsLoaded) {
          _loadSettings(state.settings);
        } else if (state is DepositSettingsUpdateSuccess) {
          NotificationHelper.showSuccess(
              context, 'Cài đặt đã được lưu thành công');
          Navigator.pop(context);
        } else if (state is DepositSettingsError) {
          NotificationHelper.showError(context, state.message);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: BlocBuilder<DepositSettingsBloc, DepositSettingsState>(
            builder: (context, state) {
              if (state is DepositSettingsLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              return Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.settings,
                            color: primaryColor, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          l10n.depositSettings,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Enable/Disable Switch
                    SwitchListTile(
                      title: const Text('Bật tính năng đặt cọc'),
                      value: _isEnabled,
                      onChanged: (value) {
                        setState(() => _isEnabled = value);
                      },
                      activeColor: primaryColor,
                    ),
                    const SizedBox(height: 16),

                    // Deposit Type Selection
                    const Text(
                      'Loại tính toán tiền cọc:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<DepositType>(
                            title: const Text('Theo phần trăm (%)'),
                            value: DepositType.percentage,
                            groupValue: _depositType,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _depositType = value);
                              }
                            },
                            activeColor: primaryColor,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<DepositType>(
                            title: const Text('Số tiền cố định'),
                            value: DepositType.fixedAmount,
                            groupValue: _depositType,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _depositType = value);
                              }
                            },
                            activeColor: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Conditional input based on type
                    if (_depositType == DepositType.percentage)
                      TextFormField(
                        controller: _depositPercentageController,
                        decoration: InputDecoration(
                          labelText: l10n.depositPercentage,
                          hintText: 'Nhập phần trăm đặt cọc',
                          suffixText: '%',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (value) {
                          if (_depositType != DepositType.percentage)
                            return null;
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập phần trăm đặt cọc';
                          }
                          final percentage = double.tryParse(value);
                          if (percentage == null ||
                              percentage <= 0 ||
                              percentage > 100) {
                            return 'Phần trăm không hợp lệ (1-100)';
                          }
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: _depositFixedAmountController,
                        decoration: InputDecoration(
                          labelText: 'Số tiền đặt cọc',
                          hintText: 'Nhập số tiền cố định (VD: 100000)',
                          suffixText: 'đ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (_depositType != DepositType.fixedAmount)
                            return null;
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập số tiền đặt cọc';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Số tiền không hợp lệ';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),

                    // Max Days to Pickup
                    TextFormField(
                      controller: _maxDaysController,
                      decoration: InputDecoration(
                        labelText: l10n.maxDaysToPickup,
                        hintText: 'Nhập số ngày tối đa',
                        suffixText: 'ngày',
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
                        final days = int.tryParse(value);
                        if (days == null || days < 1) {
                          return 'Số ngày không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Example calculation
                    if (_depositType == DepositType.percentage
                        ? _depositPercentageController.text.isNotEmpty
                        : _depositFixedAmountController.text.isNotEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ví dụ:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tổng giá trị: ${CurrencyHelper.formatVND(1000000)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                'Tiền cọc: ${CurrencyHelper.formatVND(_calculateExampleDeposit())}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(l10n.save),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _calculateExampleDeposit() {
    if (_depositType == DepositType.fixedAmount) {
      return double.tryParse(_depositFixedAmountController.text) ?? 0;
    }
    final percentage = double.tryParse(_depositPercentageController.text) ?? 0;
    return 1000000 * (percentage / 100);
  }
}
