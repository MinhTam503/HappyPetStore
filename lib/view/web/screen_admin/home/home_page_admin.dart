import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/utils/contants.dart'; // Chứa primaryColor, secondaryColor
import 'package:pet_shop/view/web/screen_admin/chat/inbox_page_admin.dart';
import 'package:pet_shop/view/web/screen_admin/pet/pets_admin.dart';
import 'package:pet_shop/view/web/screen_admin/revenue/revenue_page.dart';
import 'package:pet_shop/view/web/screen_admin/shop_info/shop_info.dart';
import 'package:pet_shop/view/web/screen_admin/dashboard/optimized_dashboard_page.dart';

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

  final List<Widget> _pages = const [
    OptimizedDashboardPage(),
    PetsAdmin(),
    CategoryAdmin(),
    AccountAdmin(),
    OrdersAdmin(),
    InboxPageAdmin(),
    ShopInfo(),
    RevenuePage(),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đăng xuất')),
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
        backgroundColor: primaryColor,
        title: const Text('Admin Panel', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: secondaryColor,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme:
                const IconThemeData(color: primaryColor, size: 28),
            unselectedIconTheme:
                IconThemeData(color: Colors.grey.shade600, size: 24),
            selectedLabelTextStyle: const TextStyle(
                color: primaryColor, fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade700),
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined), label: Text('Dashboard')),
              NavigationRailDestination(
                  icon: Icon(Icons.pets_outlined), label: Text('Pets')),
              NavigationRailDestination(
                  icon: Icon(Icons.category_outlined), label: Text('Category')),
              NavigationRailDestination(
                  icon: Icon(Icons.group_outlined), label: Text('Account')),
              NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: Text('Orders')),
              NavigationRailDestination(
                  icon: Icon(Icons.inbox_outlined), label: Text('Inbox')),
              NavigationRailDestination(
                  icon: Icon(Icons.store_outlined), label: Text('Shop Info')),
              NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined), label: Text('Revenue')),
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
