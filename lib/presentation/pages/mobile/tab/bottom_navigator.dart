import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/cart_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/favorite_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/home/home_page.dart'
    show HomePage;
import 'package:pet_shop/presentation/pages/mobile/tab/profile_screen.dart';
import 'package:pet_shop/presentation/widgets/conditional_draggable_chat_bubble.dart';
import 'package:pet_shop/presentation/widgets/common/app_drawer.dart';

class BottomNavigator extends StatefulWidget {
  final int initialIndex;
  const BottomNavigator({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<BottomNavigator> createState() => _HomePageState();
}

class _HomePageState extends State<BottomNavigator> {
  late int selectedIndex;
  final List pages = [
    const HomePage(),
    const FavoriteScreen(),
    // const ChatScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    // Gently close any remaining loading dialogs when navigating to home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DialogHelper.isDialogShowing) {
        debugPrint('BottomNavigator: Found lingering dialog, closing it');
        DialogHelper.forceCloseIfShowing();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: secondaryColor,
      drawer: const AppDrawer(),
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
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l10n?.home ?? "Home",
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_border),
            activeIcon: const Icon(Icons.favorite),
            label: l10n?.favorite ?? "Favorite",
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Iconsax.message),
          //   activeIcon: Icon(Iconsax.heart5),
          //   label: "Messages",
          // ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.shopping_cart_outlined),
            activeIcon: const Icon(Icons.shopping_cart),
            label: l10n?.cart ?? "Cart",
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l10n?.profile ?? "Profile",
          ),
        ],
      ),
      body: Stack(
        children: [
          pages[selectedIndex],
          const ConditionalDraggableChatBubble(),
        ],
      ),
    );
  }
}
