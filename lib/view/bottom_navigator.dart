import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/view/tab/cart_screen.dart';
import 'package:pet_shop/view/tab/favorite_screen.dart';
import 'package:pet_shop/view/tab/home_page.dart';
import 'package:pet_shop/view/tab/profile_screen.dart';

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
            icon: Icon(Iconsax.home),
            activeIcon: Icon(Iconsax.home5),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.heart),
            activeIcon: Icon(Iconsax.heart5),
            label: "Favorite",
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Iconsax.message),
          //   activeIcon: Icon(Iconsax.heart5),
          //   label: "Messages",
          // ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.shopping_cart),
            activeIcon: Icon(Iconsax.shopping_cart5),
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
