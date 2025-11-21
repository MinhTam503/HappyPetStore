import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/social/social_posts_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/social/social_accounts_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/social/community_groups_admin.dart';

class SocialNetworkAdmin extends StatefulWidget {
  const SocialNetworkAdmin({Key? key}) : super(key: key);

  @override
  State<SocialNetworkAdmin> createState() => _SocialNetworkAdminState();
}

class _SocialNetworkAdminState extends State<SocialNetworkAdmin> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    SocialPostsAdmin(),
    SocialAccountsAdmin(),
    CommunityGroupsAdmin(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Drawer Menu
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hub_outlined,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.socialNetworkMenu,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pet Community',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.article_outlined,
                  selectedIcon: Icons.article,
                  title: l10n.managePosts,
                  index: 0,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.people_outlined,
                  selectedIcon: Icons.people,
                  title: l10n.manageAccounts,
                  index: 1,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.groups_outlined,
                  selectedIcon: Icons.groups,
                  title: l10n.manageCommunityGroups,
                  index: 2,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? primaryColor : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? primaryColor : theme.textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
