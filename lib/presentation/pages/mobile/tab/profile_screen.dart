import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/auth/login_or_register.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/auth/change_password_page.dart';
import 'package:pet_shop/presentation/pages/mobile/chat/chat_page.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';
import 'package:pet_shop/presentation/pages/mobile/viewed_pets/viewed_page.dart';
import 'package:pet_shop/presentation/pages/mobile/order/your_order_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/address/address_list_page.dart';
import 'package:pet_shop/presentation/pages/mobile/setting/settings_page.dart';

import '../profile/edit_profile.dart';
// Removed unused import for favorite_screen.dart

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userInfo;
  String? userIdentifier;
  final UserManager userManager = UserManager();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      await userManager.initialize();
      userIdentifier = await userManager.getUserIdentifier();
      userInfo = await userManager.getCurrentUserInfo();
      setState(() {});
    } catch (e) {
      print('Error fetching user data: $e');
      // Fallback to authService if UserManager fails
      try {
        final userData = await authService.value.getUserInfo();
        setState(() {
          userInfo = userData;
        });
      } catch (fallbackError) {
        print('Fallback auth service error: $fallbackError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final l10n = AppLocalizations.of(context);

    String displayName =
        (userInfo?['displayName'] as String?)?.trim().isNotEmpty == true
            ? userInfo!['displayName']
            : 'Guest';
    String email = (userInfo?['email'] as String?) ?? '';
    String? imageUrl = (userInfo?['imageUrl'] as String?);

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: secondaryColor,
        title: Text(
          l10n?.profile ?? "Hồ sơ",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: .3,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _fetchUserData(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = isWide ? width * 0.12 : 16.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
                  child: _ProfileHeader(
                    displayName: displayName,
                    email: email,
                    imageUrl: imageUrl,
                  ),
                ),

                // Các mục chức năng
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
                  child: Column(
                    children: [
                      _MenuCard(children: [
                        _MenuItem(
                          icon: Icons.favorite,
                          iconBg: const Color(0xfffde2e2),
                          iconColor: Colors.red,
                          title: l10n?.favorites ?? 'Favorites',
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BottomNavigator(initialIndex: 1),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        _MenuItem(
                          icon: Icons.production_quantity_limits,
                          iconBg: const Color(0xffe6f5ea),
                          iconColor: Colors.teal,
                          title: l10n?.yourOrder ?? 'Your order',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const YourOrderScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        _MenuItem(
                          icon: Icons.location_on,
                          iconBg: const Color(0xffe8f5e8),
                          iconColor: Colors.green,
                          title: l10n?.manageAddresses ?? 'Manage Addresses',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddressListPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        _MenuItem(
                          icon: Icons.pets,
                          iconBg: const Color(0xfffde2e2),
                          iconColor: primaryColor,
                          title: l10n?.viewedPets ?? 'Viewed Pets',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ViewedPage(),
                              ),
                            );
                          },
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _MenuCard(children: [
                        _MenuItem(
                          icon: Icons.edit,
                          iconBg: const Color(0xffe9ecff),
                          iconColor: Colors.indigo,
                          title: l10n?.editProfile ?? 'Edit Profile',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EditProfile(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        _MenuItem(
                          icon: Icons.message_outlined,
                          iconBg: const Color(0xfff0ecff),
                          iconColor: Colors.deepPurple,
                          title: l10n?.inbox ?? 'Inbox',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChatPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        _MenuItem(
                          icon: Icons.password_rounded,
                          iconBg: const Color(0xfffff2e5),
                          iconColor: Colors.orange,
                          title: l10n?.changePasswordMenu ?? 'Change Password',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordPage(),
                              ),
                            );
                          },
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _MenuCard(children: [
                        _MenuItem(
                            icon: Icons.settings,
                            iconBg: const Color(0xfffdeefe),
                            iconColor: Colors.grey,
                            title: l10n?.setting ?? 'Setting',
                            titleColor: Colors.black,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ),
                              );
                            }),
                      ]),
                      const SizedBox(height: 12),
                      _MenuCard(children: [
                        _MenuItem(
                            icon: Icons.logout_rounded,
                            iconBg: const Color(0xfffdeefe),
                            iconColor: Colors.pink,
                            title: l10n?.logout ?? 'Logout',
                            titleColor: Colors.red.shade600,
                            onTap: () {
                              _showLogoutDialog(context);
                            }),
                      ]),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _showLogoutDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);

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
                l10n?.logout ?? 'Đăng xuất',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                l10n?.logoutConfirm ??
                    'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                        l10n?.cancel ?? 'Hủy',
                        style: const TextStyle(
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
                        _logout(context);
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
                        l10n?.logout ?? 'Đăng xuất',
                        style: const TextStyle(
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

Future<void> _logout(BuildContext context) async {
  try {
    // Use AuthService signOut which handles Google, Facebook, and Firebase signOut
    await authService.value.signOut();

    // Clear UserManager data
    final userManager = UserManager();
    await userManager.clearUserData();

    if (context.mounted) {
      NotificationHelper.showSuccess(
        context,
        'Đăng xuất thành công',
        'Hẹn gặp lại bạn!',
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginOrRegister()),
        (route) => false,
      );
    }
  } catch (e) {
    if (context.mounted) {
      NotificationHelper.showError(
        context,
        'Lỗi đăng xuất',
        'Không thể đăng xuất. Vui lòng thử lại.',
      );
    }
  }
}

// Header: gradient + avatar + tên & email
class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? imageUrl;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    this.imageUrl,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1)
      return parts.first.characters.take(1).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            secondaryColor.withOpacity(.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(48),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: (imageUrl != null && imageUrl!.trim().isNotEmpty)
                  ? NetworkImage(imageUrl!)
                  : null,
              child: (imageUrl == null || imageUrl!.trim().isEmpty)
                  ? Text(
                      _initials(displayName),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          // Tên + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
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

// Thẻ nhóm menu (Card viền + bo tròn)
class _MenuCard extends StatelessWidget {
  final List<Widget> children;

  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

// Item menu dạng ListTile đẹp + icon nền
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: titleColor ?? Colors.black,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      horizontalTitleGap: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// Divider có inset để đẹp mắt
// Removed custom divider widget in favor of subtle spacing for a cleaner look.
