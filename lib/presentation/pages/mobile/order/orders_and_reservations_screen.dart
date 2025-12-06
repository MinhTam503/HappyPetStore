import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/order/your_order_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/reservation/my_reservations_screen.dart';

/// Unified screen with tabs for Orders and Reservations
class OrdersAndReservationsScreen extends StatefulWidget {
  final String? initialOrderId;
  final int initialTabIndex; // 0 = Orders, 1 = Reservations

  const OrdersAndReservationsScreen({
    Key? key,
    this.initialOrderId,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<OrdersAndReservationsScreen> createState() => _OrdersAndReservationsScreenState();
}

class _OrdersAndReservationsScreenState extends State<OrdersAndReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        elevation: 0,
        title: Text(
          'Đơn hàng & Đặt trước',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: .2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.shopping_bag_outlined),
              text: l10n.yourOrder,
            ),
            Tab(
              icon: const Icon(Icons.book_online_outlined),
              text: l10n.myReservations,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          YourOrderScreen(
            initialOrderId: widget.initialOrderId,
            isEmbedded: true, // Flag to hide AppBar
          ),
          const MyReservationsScreen(
            isEmbedded: true, // Flag to hide AppBar
          ),
        ],
      ),
    );
  }
}
