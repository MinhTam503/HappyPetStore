import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

import 'package:pet_shop/presentation/pages/mobile/auth/change_password_page.dart';
import 'package:pet_shop/presentation/pages/mobile/chat_page.dart';
import 'package:pet_shop/presentation/pages/mobile/your_order_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/settings_page.dart';

import '../edit_profile.dart';
import 'favorite_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? user;
  Map<String, dynamic>? order;

  @override
  void initState() {
    fetchDataUser();
    super.initState();
  }

  Future<void> fetchDataUser() async {
    final userData = await authService.value.getUserInfo();
    setState(() {
      user = userData;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    String displayName =
        (user?['displayName'] as String?)?.trim().isNotEmpty == true
            ? user!['displayName']
            : 'Guest';
    String email = (user?['email'] as String?) ?? '';
    String? imageUrl = (user?['imageUrl'] as String?);

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: secondaryColor,
        title: Text(
          'Profile',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: .3,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => fetchDataUser(),
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
                          title: 'Favorites',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FavoriteScreen(),
                              ),
                            );
                          },
                        ),
                        _DividerInset(),
                        _MenuItem(
                          icon: Icons.production_quantity_limits,
                          iconBg: const Color(0xffe6f5ea),
                          iconColor: Colors.teal,
                          title: 'Your order',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const YourOrderScreen(),
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
                          title: 'Edit Profile',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EditProfile(),
                              ),
                            );
                          },
                        ),
                        _DividerInset(),
                        _MenuItem(
                          icon: Icons.message_outlined,
                          iconBg: const Color(0xfff0ecff),
                          iconColor: Colors.deepPurple,
                          title: 'Inbox',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChatPage(),
                              ),
                            );
                          },
                        ),
                        _DividerInset(),
                        _MenuItem(
                          icon: Icons.password_rounded,
                          iconBg: const Color(0xfffff2e5),
                          iconColor: Colors.orange,
                          title: 'Change Password',
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
                            title: 'Setting',
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
                          title: 'Logout',
                          titleColor: Colors.red.shade600,
                          onTap: () => showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) =>
                                AlertDialog(
                              title: const Text("Xác nhận đăng xuất"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, 'Cancel'),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    // Đóng dialog trước
                                    Navigator.pop(context);

                                    debugPrint(
                                        '🚪 User clicked logout, calling signOut()');

                                    try {
                                      // Chỉ signOut và để authStateChanges handle navigation
                                      await authService.value.signOut();
                                      debugPrint(
                                          '✅ signOut() completed successfully');
                                    } catch (e) {
                                      debugPrint('❌ signOut() error: $e');
                                      // Show error message to user
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Đăng xuất thất bại: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text("Ok"),
                                ),
                              ],
                            ),
                          ),
                        ),
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

// Header: gradient + avatar + tên & email
class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? imageUrl;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    this.imageUrl,
    super.key,
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

  const _MenuCard({required this.children, super.key});

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
    super.key,
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
class _DividerInset extends StatelessWidget {
  const _DividerInset({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 0,
      indent: 16 + 44 + 12, // leading padding + icon size + gap
      endIndent: 12,
    );
  }
}
