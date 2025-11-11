import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/auth/login_or_register.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/infoStore/StoreInfoScreen.dart';
import 'package:pet_shop/presentation/pages/mobile/order/your_order_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/setting/settings_page.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';
import 'package:pet_shop/presentation/pages/mobile/notification/nofi_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Map<String, dynamic>? userInfo;
  String? userIdentifier;
  final UserManager userManager = UserManager();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    await userManager.initialize();
    userIdentifier = await userManager.getUserIdentifier();
    userInfo = await userManager.getCurrentUserInfo();
    setState(() {});

    // Subscribe to realtime updates so avatar/name/email refresh live
    await _userSub?.cancel();
    if (userIdentifier != null) {
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(userIdentifier)
          .snapshots()
          .listen((snap) {
        final data = snap.data();
        if (data != null) {
          setState(() {
            userInfo = data;
          });
        }
      });
    }
  }

  String _getDisplayName() {
    if (userInfo?['displayName'] != null &&
        userInfo!['displayName'].toString().isNotEmpty) {
      return userInfo!['displayName'];
    }
    if (userInfo?['email'] != null) {
      return userInfo!['email'].toString().split('@')[0];
    }
    // Localized fallback display name
    return AppLocalizations.of(context)?.user ?? 'User';
  }

  String _getEmailDisplay() {
    return userInfo?['email'] ?? 'email@example.com';
  }

  String _getAvatarUrl() {
    return userInfo?['imageUrl'] ?? '';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1)
      return parts.first.characters.take(1).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 10),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.red.shade400,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalizations.of(context)!.logout,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  AppLocalizations.of(context)!.logoutConfirm,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 30),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _logout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.logout,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      DialogHelper.showLoadingDialog(context, message: AppLocalizations.of(context)!.loggingOut);
      await authService.value.signOut();

      // Clear UserManager data
      final userManager = UserManager();
      await userManager.clearUserData();

      if (mounted) {
        NotificationHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.logoutSuccessTitle,
          AppLocalizations.of(context)!.logoutSuccessMessage,
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginOrRegister()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(
          context,
          AppLocalizations.of(context)!.logoutErrorTitle,
          AppLocalizations.of(context)!.logoutErrorMessage,
        );
      }
    } finally {
      await DialogHelper.safeHideLoadingDialog();
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getDisplayName();
    final avatarUrl = _getAvatarUrl();

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header with user info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
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
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            _getInitials(displayName),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),

                // Email
                Text(
                  _getEmailDisplay(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications,
                  title: AppLocalizations.of(context)!.notificationTitle,
                  onTap: () {
                    Navigator.pop(context);
                    if (userIdentifier != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NofiScreen(userId: userIdentifier!),
                        ),
                      );
                    }
                  },
                ),
                _DrawerItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  title: AppLocalizations.of(context)!.store,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StoreInfoScreen(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.shopping_bag_outlined,
                  activeIcon: Icons.shopping_bag,
                  title: AppLocalizations.of(context)!.yourOrders,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const YourOrderScreen(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.favorite_border,
                  activeIcon: Icons.favorite,
                  title: AppLocalizations.of(context)!.favorites,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const BottomNavigator(initialIndex: 1),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.shopping_cart_outlined,
                  activeIcon: Icons.shopping_cart,
                  title: AppLocalizations.of(context)!.cart,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const BottomNavigator(initialIndex: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 32),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  title: AppLocalizations.of(context)!.settings,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.logout_outlined,
                  activeIcon: Icons.logout,
                  title: AppLocalizations.of(context)!.logout,
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'Pet Shop App v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    this.activeIcon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade400 : Colors.black87;
    final iconColor =
        isDestructive ? Colors.red.shade400 : Colors.grey.shade600;

    return ListTile(
      leading: Icon(
        icon,
        color: iconColor,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      hoverColor:
          isDestructive ? Colors.red.shade50 : primaryColor.withOpacity(0.1),
    );
  }
}
