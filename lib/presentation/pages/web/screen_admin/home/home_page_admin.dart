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
import 'package:pet_shop/presentation/pages/web/screen_admin/shop_info/shop_info.dart';
import 'package:pet_shop/presentation/widgets/settings_menu.dart';

import '../account/account_admin.dart';
import '../category/category_admin.dart';
import '../auth/login_admin_page.dart';
import '../order/orders_admin.dart';

class HomePageAdmin extends StatefulWidget {
  const HomePageAdmin({super.key});

  @override
  State<HomePageAdmin> createState() => _HomePageAdminState();
}

class _HomePageAdminState extends State<HomePageAdmin> {
  int _selectedIndex = 0;
  String? _role;
  bool _loading = true;

  final List<Widget> _pages = [
    const DashboardPage(),
    const PetsAdmin(),
    const CategoryAdmin(),
    const AccountAdmin(),
    const OrdersAdmin(),
    const NotificationManagementPanel(),
    const InboxPageAdmin(),
    const ShopInfo(),
    const PetAnalyticsPage(),
    const RevenuePage(),
  ];

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
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  label: Text(l10n.dashboard)),
              NavigationRailDestination(
                  icon: const Icon(Icons.pets_outlined),
                  label: Text(l10n.pets)),
              NavigationRailDestination(
                  icon: const Icon(Icons.category_outlined),
                  label: Text(l10n.category)),
              NavigationRailDestination(
                  icon: const Icon(Icons.group_outlined),
                  label: Text(l10n.account)),
              NavigationRailDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(l10n.orders)),
              NavigationRailDestination(
                  icon: const Icon(Icons.notifications_active),
                  label: Text(l10n.notification)),
              NavigationRailDestination(
                  icon: const Icon(Icons.inbox_outlined),
                  label: Text(l10n.inbox)),
              NavigationRailDestination(
                  icon: const Icon(Icons.store_outlined),
                  label: Text(l10n.shopInfo)),
              NavigationRailDestination(
                  icon: const Icon(Icons.analytics_outlined),
                  label: Text(l10n.petAnalytics)),
              NavigationRailDestination(
                  icon: const Icon(Icons.bar_chart_outlined),
                  label: Text(l10n.revenue)),
            ],
          ),
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
