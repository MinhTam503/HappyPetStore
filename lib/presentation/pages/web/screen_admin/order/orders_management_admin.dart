import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/order/reservations_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/order/orders_admin.dart';

/// Orders Management Admin - Parent page with nested tabs
/// Tab 1: Reservations (Đặt trước)
/// Tab 2: Orders (Đơn hàng)
class OrdersManagementAdmin extends StatefulWidget {
  const OrdersManagementAdmin({Key? key}) : super(key: key);

  @override
  State<OrdersManagementAdmin> createState() => _OrdersManagementAdminState();
}

class _OrdersManagementAdminState extends State<OrdersManagementAdmin> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ReservationsAdmin(),
    OrdersAdmin(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sidebar Menu
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.ordersMenu,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Store & Delivery',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.book_online_outlined,
                  selectedIcon: Icons.book_online,
                  title: l10n.manageReservations,
                  index: 0,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.local_shipping_outlined,
                  selectedIcon: Icons.local_shipping,
                  title: l10n.manageOrders,
                  index: 1,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? primaryColor : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? primaryColor : theme.textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
