import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import '../../order/orders_admin.dart';
import 'package:pet_shop/presentation/bloc/recentOrders/recent_orders_bloc.dart';
import 'package:pet_shop/presentation/bloc/recentOrders/recent_orders_state.dart';

class RecentOrdersSection extends StatelessWidget {
  final void Function(int index)? onNavigateToTab;
  const RecentOrdersSection({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String localizedStatus(String raw) {
      switch (raw) {
        case 'Pending':
          return l10n.pending;
        case 'Processing':
          return l10n.processing;
        case 'Completed':
          return l10n.completed;
        case 'Cancelled':
          return l10n.cancelled;
        default:
          return raw;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.recentOrders,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineSmall?.color,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  if (onNavigateToTab != null) {
                    onNavigateToTab!(4);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrdersAdmin()),
                    );
                  }
                },
                child: Text(l10n.viewAll),
              ),
            ],
          ),
          const SizedBox(height: 24),
          BlocBuilder<RecentOrdersBloc, RecentOrdersState>(
            builder: (context, state) {
              if (state is RecentOrdersInitial ||
                  state is RecentOrdersLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is RecentOrdersFailure) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      state.message,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                );
              }
              if (state is RecentOrdersEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      l10n.noDataAvailable,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                );
              }

              if (state is RecentOrdersSuccess) {
                final orders = state.orders;
                return Column(
                  children: orders.map((o) {
                    print(o.id);
                    return _OrderRow(
                      id: o.id,
                      customerName: o.customerName,
                      status: localizedStatus(o.status),
                      totalAmount: o.totalAmount,
                      source: o.source,
                    );
                  }).toList(),
                );
              }

              // Fallback (should not reach here): show empty
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    l10n.noDataAvailable,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final String id;
  final String customerName;
  final String status;
  final double totalAmount;
  final String source;

  const _OrderRow({
    required this.id,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.1),
                  primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: source == 'Mobile'
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.1))
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.purple.withOpacity(0.2)
                                : Colors.purple.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        source,
                        style: TextStyle(
                          color: source == 'Mobile'
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.lightBlueAccent
                                  : Colors.blue[700])
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.purpleAccent
                                  : Colors.purple[700]),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Order #${id.substring(0, 8)}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status == 'Completed'
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.withOpacity(0.2)
                          : Colors.green.withOpacity(0.1))
                      : status == 'Pending'
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.orange.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.1))
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: status == 'Completed'
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.lightGreenAccent
                            : Colors.green[700])
                        : status == 'Pending'
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.orangeAccent
                                : Colors.orange[700])
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.lightBlueAccent
                                : Colors.blue[700]),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                CurrencyHelper.formatVND(totalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
