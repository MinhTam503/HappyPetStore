import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/presentation/bloc/spending/spending_bloc.dart';
import 'package:pet_shop/presentation/bloc/spending/spending_event.dart';
import 'package:pet_shop/presentation/bloc/spending/spending_state.dart';
import 'package:pet_shop/presentation/pages/mobile/order/your_order_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/presentation/pages/mobile/reservation/my_reservations_screen.dart';

class SpendingScreen extends StatefulWidget {
  final String userId;

  const SpendingScreen({super.key, required this.userId});

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _currentPeriod = 'month';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    // Load initial data
    context.read<SpendingBloc>().add(LoadSpending(
          userId: widget.userId,
          period: _currentPeriod,
        ));
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      String period;
      switch (_tabController.index) {
        case 0:
          period = 'week';
          break;
        case 1:
          period = 'month';
          break;
        case 2:
          period = 'year';
          break;
        default:
          period = 'month';
      }
      
      if (period != _currentPeriod) {
        setState(() => _currentPeriod = period);
        context.read<SpendingBloc>().add(LoadSpending(
              userId: widget.userId,
              period: period,
            ));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n?.spendingTitle ?? 'Biến động thu chi',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: l10n?.spendingWeek ?? 'Theo tuần'),
            Tab(text: l10n?.spendingMonth ?? 'Theo tháng'),
            Tab(text: l10n?.spendingYear ?? 'Theo năm'),
          ],
        ),
      ),
      body: BlocBuilder<SpendingBloc, SpendingState>(
        builder: (context, state) {
          if (state is SpendingLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SpendingError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (state is SpendingLoaded) {
            if (state.data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 72, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      l10n?.spendingEmpty ?? 'Chưa có dữ liệu chi tiêu',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            return _buildChart(context, state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildChart(BuildContext context, SpendingLoaded state) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Prepare data for chart
    final sortedKeys = state.data.keys.toList()..sort();
    final maxAmount = state.data.values
        .map((e) => e.totalAmount)
        .reduce((a, b) => a > b ? a : b);

    // Calculate total spending
    final totalSpending = state.data.values
        .fold<double>(0, (sum, item) => sum + item.totalAmount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total spending card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet,
                      size: 40, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.spendingTotal(_getPeriodLabel(state.period, l10n)) ?? 'Tổng chi ${_getPeriodLabel(state.period, l10n)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyHelper.formatVND(totalSpending),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Chart title
          Text(
            l10n?.spendingChart ?? 'Biểu đồ chi tiêu',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Bar chart
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxAmount * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent && response?.spot != null) {
                      final index = response!.spot!.touchedBarGroupIndex;
                      if (index >= 0 && index < sortedKeys.length) {
                        final key = sortedKeys[index];
                        _showPeriodDetails(context, key, state.data[key]!, state.period);
                      }
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final key = sortedKeys[groupIndex];
                      return BarTooltipItem(
                        '$key\n${CurrencyHelper.formatVND(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              sortedKeys[value.toInt()],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatAmount(value),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxAmount / 5,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  sortedKeys.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: state.data[sortedKeys[index]]!.totalAmount,
                        color: theme.colorScheme.primary,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Hint text
          Row(
            children: [
              Icon(Icons.touch_app, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n?.spendingHint ?? 'Nhấn vào cột để xem chi tiết',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel(String period, AppLocalizations? l10n) {
    switch (period) {
      case 'week':
        return l10n?.spendingPeriodWeek ?? 'tuần này';
      case 'month':
        return l10n?.spendingPeriodMonth ?? 'tháng này';
      case 'year':
        return l10n?.spendingPeriodYear ?? 'năm này';
      default:
        return '';
    }
  }

  String _formatPeriodKeyForDisplay(String periodKey, String period) {
    // Convert short format to full display format
    if (period == 'month') {
      // Convert "T1" to "Tuần 1"
      if (periodKey.startsWith('T')) {
        final weekNum = periodKey.substring(1);
        return 'Tuần $weekNum';
      }
    } else if (period == 'year') {
      // Convert "T1" to "Tháng 1"
      if (periodKey.startsWith('T')) {
        final monthNum = periodKey.substring(1);
        return 'Tháng $monthNum';
      }
    }
    return periodKey;
  }

  String _formatAmount(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  void _showPeriodDetails(BuildContext context, String periodKey, SpendingData data, String period) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatPeriodKeyForDisplay(periodKey, period),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyHelper.formatVND(data.totalAmount),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Pet list
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: data.orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = data.orders[index];
                      return _buildOrderCard(context, order, l10n);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderItem order, AppLocalizations? l10n) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Close bottom sheet and show order/reservation details
          Navigator.pop(context);
          _showOrderOrReservationDetails(order);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Order header
            ListTile(
              title: Text(
                '${l10n?.orderLabel ?? 'Đơn hàng'} #${order.orderId.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _formatDateTime(order.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Text(
                CurrencyHelper.formatVND(order.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const Divider(height: 1),

            // Pets in order
            if (order.pets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Không có thông tin thú cưng',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ...order.pets.map((pet) => ListTile(
                    leading: pet.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              pet.imageUrl!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.pets),
                              ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.pets),
                          ),
                    title: Text(pet.name),
                    // subtitle: Text('${l10n?.quantity ?? 'SL'}: ${pet.quantity}'),
                    trailing: Text(
                      CurrencyHelper.formatVND(pet.price),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _showOrderOrReservationDetails(OrderItem order) async {
    // Check if this is a reservation or order by querying both collections
    try {
      final reservationDoc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(order.orderId)
          .get();

      if (reservationDoc.exists) {
        // It's a reservation - navigate to MyReservationsScreen with reservationId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MyReservationsScreen(
              initialReservationId: order.orderId,
            ),
          ),
        );
      } else {
        // It's an order - navigate to YourOrderScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => YourOrderScreen(initialOrderId: order.orderId),
          ),
        );
      }
    } catch (e) {
      print('Error checking order type: $e');
      // Default to order screen on error
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => YourOrderScreen(initialOrderId: order.orderId),
        ),
      );
    }
  }



  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
