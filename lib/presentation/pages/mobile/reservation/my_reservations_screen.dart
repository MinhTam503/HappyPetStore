import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/data/models/reservation_model.dart';
import 'package:pet_shop/presentation/bloc/reservation/reservation_bloc.dart';
import 'package:pet_shop/presentation/bloc/reservation/reservation_event.dart';
import 'package:pet_shop/presentation/bloc/reservation/reservation_state.dart';

/// My Reservations Screen - User view their reservations
class MyReservationsScreen extends StatefulWidget {
  final bool isEmbedded; // If true, hide AppBar (used in tabs)
  final String? initialReservationId; // If provided, auto-show details dialog
  
  const MyReservationsScreen({
    Key? key,
    this.isEmbedded = false,
    this.initialReservationId,
  }) : super(key: key);

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  bool _hasShownInitialDialog = false;
  
  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      context.read<ReservationBloc>().add(LoadUserReservations(userId));
    }
  }
  
  void _showInitialDialogIfNeeded(List<ReservationModel> reservations, AppLocalizations l10n) {
    if (_hasShownInitialDialog || widget.initialReservationId == null) return;
    
    final targetReservation = reservations.firstWhere(
      (r) => r.id == widget.initialReservationId,
      orElse: () => reservations.first,
    );
    
    _hasShownInitialDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showReservationDetails(targetReservation, l10n);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final bodyContent = BlocConsumer<ReservationBloc, ReservationState>(
      listener: (context, state) {
        if (state is ReservationSuccess) {
          NotificationHelper.showSuccess(
            context,
            l10n.success,
            'Cập nhật thành công',
          );
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            context.read<ReservationBloc>().add(LoadUserReservations(userId));
          }
        } else if (state is ReservationError) {
          print(state.message);
          NotificationHelper.showError(context, l10n.error, state.message);
        }
      },
      builder: (context, state) {
          if (state is ReservationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ReservationLoaded) {
            if (state.reservations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.book_online_outlined,
                      size: 80,
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noReservations,
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }
            
            // Auto-show dialog if initialReservationId is provided
            _showInitialDialogIfNeeded(state.reservations, l10n);

            return RefreshIndicator(
              onRefresh: () async {
                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId != null) {
                  context.read<ReservationBloc>().add(LoadUserReservations(userId));
                }
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.reservations.length,
                itemBuilder: (context, index) {
                  final reservation = state.reservations[index];
                  return _buildReservationCard(reservation, l10n);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      );
    
    // If embedded, return body content directly
    if (widget.isEmbedded) {
      return bodyContent;
    }
    
    // Otherwise, return full Scaffold
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.myReservations),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary,
        foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
      ),
      body: bodyContent,
    );
  }

  Widget _buildReservationCard(ReservationModel reservation, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showReservationDetails(reservation, l10n),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.reservationId}: ${reservation.id.substring(0, 8)}...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(reservation.status, l10n),
                ],
              ),
              const Divider(height: 24),

              // Pickup date
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.pickupDate}: ${DateFormat('dd/MM/yyyy').format(reservation.pickupDate)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items count
              Row(
                children: [
                  Icon(Icons.pets, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Text(
                    '${reservation.items.length} ${reservation.items.length > 1 ? "thú cưng" : "thú cưng"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Payment info
              Row(
                children: [
                  Icon(Icons.payment, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Text(
                    _getPaymentStatusText(reservation.paymentStatus, l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: reservation.paymentStatus == ReservationPaymentStatus.fullPaid
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.totalAmountLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          CurrencyHelper.formatVND(reservation.totalAmount),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (reservation.remainingAmount > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n.remainingAmount,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            CurrencyHelper.formatVND(reservation.remainingAmount),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Action buttons
              if (reservation.status == ReservationStatus.pending)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelReservation(reservation, l10n),
                      icon: const Icon(Icons.cancel_outlined),
                      label: Text(l10n.cancelReservation),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ReservationStatus status, AppLocalizations l10n) {
    final theme = Theme.of(context);
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case ReservationStatus.pending:
        color = theme.colorScheme.secondary;
        icon = Icons.hourglass_empty;
        text = l10n.pending;
        break;
      case ReservationStatus.confirmed:
        color = theme.colorScheme.primary;
        icon = Icons.check_circle_outline;
        text = 'Đã xác nhận';
        break;
      case ReservationStatus.completed:
        color = theme.colorScheme.tertiary;
        icon = Icons.check_circle;
        text = l10n.completed;
        break;
      case ReservationStatus.cancelled:
        color = theme.colorScheme.error;
        icon = Icons.cancel;
        text = l10n.cancelled;
        break;
      case ReservationStatus.expired:
        color = theme.colorScheme.onSurface.withOpacity(0.5);
        icon = Icons.access_time;
        text = 'Hết hạn';
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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
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

  String _getPaymentStatusText(ReservationPaymentStatus status, AppLocalizations l10n) {
    switch (status) {
      case ReservationPaymentStatus.pending:
        return 'Chưa thanh toán';
      case ReservationPaymentStatus.depositPaid:
        return l10n.paymentStatusDeposit;
      case ReservationPaymentStatus.fullPaid:
        return l10n.paymentStatusFull;
    }
  }

  void _showReservationDetails(ReservationModel reservation, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.viewReservationDetails,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              _buildDetailRow(l10n.reservationId, reservation.id),
              _buildDetailRow(l10n.pickupDate, DateFormat('dd/MM/yyyy').format(reservation.pickupDate)),
              _buildDetailRow(l10n.totalAmountLabel, CurrencyHelper.formatVND(reservation.totalAmount)),
              _buildDetailRow(l10n.depositAmount, CurrencyHelper.formatVND(reservation.depositAmount)),
              _buildDetailRow(l10n.paidAmount, CurrencyHelper.formatVND(reservation.paidAmount)),
              _buildDetailRow(l10n.remainingAmount, CurrencyHelper.formatVND(reservation.remainingAmount)),
              _buildDetailRow(l10n.paymentMethod, reservation.paymentMethod == 'vnpay' ? 'VNPay' : 'Stripe'),
              
              const SizedBox(height: 24),
              Text(
                l10n.items,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...reservation.items.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: item['imageUrl'] != null
                          ? Image.network(
                              item['imageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.pets, size: 50),
                      title: Text(item['name'] ?? ''),
                      subtitle: Text('${item['breed']} - ${item['category']}'),
                      trailing: Text(
                        CurrencyHelper.formatVND(item['price']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          // Use theme color to ensure contrast (was transparent)
                          color: Colors.black,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
              context.read<ReservationBloc>().add(CancelReservation(reservation.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}
