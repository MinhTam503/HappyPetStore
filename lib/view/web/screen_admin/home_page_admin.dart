import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/view/web/screen_admin/inbox_page_admin.dart';
import 'package:pet_shop/view/web/screen_admin/pets_admin.dart';
import 'package:pet_shop/view/web/screen_admin/revenue_page.dart';
import 'package:pet_shop/view/web/screen_admin/shop_info.dart';


import '../../../auth/login_or_register.dart';
import 'account_admin.dart';
import 'category_admin.dart';
import 'orders_admin.dart';

class HomePageAdmin extends StatefulWidget {
  const HomePageAdmin({super.key});

  @override
  State<HomePageAdmin> createState() => _HomePageAdminState();
}

class _HomePageAdminState extends State<HomePageAdmin> {
  Future<String?> fetchUserRole() async {
    Map<String, dynamic>? userInfo = await authService.value.getUserInfo();
    setState(() {});
    return userInfo?['role'] ?? "user";
  }

  int _selectedIndex = 0;
  final List<Widget> _pages = [
    // const DashboardPage(),
    const PetsAdmin(),
    const CategoryAdmin(),
    const AccountAdmin(),
    const OrdersAdmin(),
    const InboxPageAdmin(),
    const ShopInfo(),
    const RevenuePage(),
    // const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: fetchUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            if (!snapshot.hasData) {
              return const Scaffold(
                backgroundColor: secondaryColor,
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
          }
          String role = snapshot.data ?? "user";
          if (role != "admin") {
            return const LoginOrRegister();
          }
          return Scaffold(
            body: Column(
              children: [
                // Thanh Navigation
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  color: Colors.blue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Admin Panel",
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          navButton("Pets", 0),
                          navButton("Category", 1),
                          navButton("Account", 2),
                          navButton("Orders", 3),
                          navButton("Inbox", 4),
                          navButton("ShopInfo", 5),
                          navButton("Revenue", 6),
                          navButton("Logout", -1),
                        ],
                      ),
                    ],
                  ),
                ),
                // Nội dung trang
                Expanded(
                  child: _selectedIndex == -1
                      ? const Center(
                          child: Text("Đang đăng xuất...",
                              style: TextStyle(fontSize: 18)))
                      : _pages[_selectedIndex],
                ),
              ],
            ),
          );
        });
  }

  Widget navButton(String text, int index) {
    return TextButton(
      onPressed: () {
        if (index == -1) {
          authService.value.signOut();
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const LoginOrRegister()));
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}
