import 'package:flutter/material.dart';

import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/view/mobile/tab/cart_screen.dart';
import 'package:pet_shop/view/mobile/tab/favorite_screen.dart';
import 'package:pet_shop/view/mobile/tab/home_page.dart' show HomePage;
import 'package:pet_shop/view/mobile/tab/profile_screen.dart';

class BottomNavigator extends StatefulWidget {
  const BottomNavigator({super.key});

  @override
  State<BottomNavigator> createState() => _HomePageState();
}

class _HomePageState extends State<BottomNavigator> {
  int selectedIndex = 0;
  final List pages = [
    const HomePage(),
    const FavoriteScreen(),
    // const ChatScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: primaryColor,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        elevation: 0,
        backgroundColor: secondaryColor,
        type: BottomNavigationBarType.fixed,
        onTap: (value) {
          setState(() {
            selectedIndex = value;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: "Favorite",
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Iconsax.message),
          //   activeIcon: Icon(Iconsax.heart5),
          //   label: "Messages",
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: "Cart",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
      body: pages[selectedIndex],
    );
  }
}
