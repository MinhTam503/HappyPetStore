import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart'; // Chứa primaryColor, secondaryColor
import 'package:pet_shop/presentation/pages/web/screen_admin/chat/inbox_page_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/dashboard/dashboard_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/notification/notification_management_panel.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet/pets_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet_analytics/pet_analytics_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/revenue/revenue_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/shipping/shipping_management_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/shop_info/shop_info.dart';
import 'package:pet_shop/presentation/widgets/settings_menu.dart';

import '../account/account_admin.dart';
import '../category/category_admin.dart';
import '../auth/login_admin_page.dart';
import '../order/orders_admin.dart';

// Helper class for navigation items
class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class HomePageAdmin extends StatefulWidget {
  const HomePageAdmin({super.key});

  @override
  State<HomePageAdmin> createState() => _HomePageAdminState();
}

class _HomePageAdminState extends State<HomePageAdmin> {
  int _selectedIndex = 0;
  String? _role;
  bool _loading = true;

  late final List<Widget> _pages = [
    DashboardPage(onNavigateToTab: _setIndex),
    const PetsAdmin(),
    const CategoryAdmin(),
    const AccountAdmin(),
    const OrdersAdmin(),
    const NotificationManagementPanel(),
    const InboxPageAdmin(),
    const ShopInfo(),
    const PetAnalyticsPage(),
    const RevenuePage(),
   const ShippingManagementPage(),
  ];

  void _setIndex(int i) {
    if (i < 0 || i >= _pages.length) return;
    setState(() => _selectedIndex = i);
  }

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    final info = await authService.value.getUserInfo();
    setState(() {
      _role = info?['role'] ?? 'user';
      _loading = false;
    });
  }

  void _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirm),
        content: Text(l10n.areYouSureLogout),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.logout)),
        ],
      ),
    );
    if (confirm == true) {
      await authService.value.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginAdminPage()),
      );
    }
  }

  // Helper methods for navigation
  List<NavigationItem> _getNavigationItems() {
    final l10n = AppLocalizations.of(context)!;
    return [
      NavigationItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: l10n.dashboard,
      ),
      NavigationItem(
        icon: Icons.pets_outlined,
        selectedIcon: Icons.pets,
        label: l10n.pets,
      ),
      NavigationItem(
        icon: Icons.category_outlined,
        selectedIcon: Icons.category,
        label: l10n.category,
      ),
      NavigationItem(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: l10n.account,
      ),
      NavigationItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: l10n.orders,
      ),
      NavigationItem(
        icon: Icons.notifications_active_outlined,
        selectedIcon: Icons.notifications_active,
        label: l10n.notification,
      ),
      NavigationItem(
        icon: Icons.inbox_outlined,
        selectedIcon: Icons.inbox,
        label: l10n.inbox,
      ),
      NavigationItem(
        icon: Icons.store_outlined,
        selectedIcon: Icons.store,
        label: l10n.shopInfo,
      ),
      NavigationItem(
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics,
        label: l10n.petAnalytics,
      ),
      NavigationItem(
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        label: l10n.revenue,
      ),
      NavigationItem(
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
        label: 'Giao hàng',
      ),
    ];
  }

  Widget _buildNavigationItem(int index, NavigationItem item) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected 
          ? theme.colorScheme.primary.withOpacity(0.1)
          : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }
    if (_role != 'admin') {
      return const LoginAdminPage();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(l10n.adminPanel,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        actions: [
          const SettingsMenu(),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.logout,
                color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _logout,
            tooltip: l10n.logout,
          ),
        ],
      ),
      body: Row(
        children: [
          // Scrollable NavigationRail để xử lý overflow
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Leading space
                  const SizedBox(height: 8),
                  
                  // Navigation items
                  for (int i = 0; i < _getNavigationItems().length; i++)
                    _buildNavigationItem(i, _getNavigationItems()[i]),
                    
                  // Trailing space
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Main content area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
