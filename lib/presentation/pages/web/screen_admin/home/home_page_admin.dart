import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/chat/inbox_page_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/dashboard/dashboard_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/notification/notification_management_panel.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet/pets_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet_analytics/pet_analytics_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/revenue/revenue_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/shop_info/shop_info.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/theme/theme_settings_admin.dart';
import 'package:pet_shop/presentation/widgets/settings_menu.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/social/social_posts_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/social/social_accounts_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/social/community_groups_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/social/sensitive_words_admin.dart';
import '../account/account_admin.dart';
import '../category/category_admin.dart';
import '../auth/login_admin_page.dart';
import '../order/orders_admin.dart';
import '../order/reservations_admin.dart';

// Helper class for navigation items
class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final List<NavigationItem>? subItems;

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.subItems,
  });
}

class HomePageAdmin extends StatefulWidget {
  const HomePageAdmin({super.key});

  @override
  State<HomePageAdmin> createState() => _HomePageAdminState();
}

class _HomePageAdminState extends State<HomePageAdmin> {
  int _selectedIndex = 0;
  String? _role;
  bool _loading = true;
  bool _socialMenuExpanded = false;
  bool _ordersMenuExpanded = false;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _initializePages();
    _fetchRole();
  }

  void _initializePages() {
    _pages = [
      DashboardPage(onNavigateToTab: _setIndex),
      const PetsAdmin(),
      const CategoryAdmin(),
      const AccountAdmin(),
      const ReservationsAdmin(), // Orders Management - Reservations
      const OrdersAdmin(), // Orders Management - Orders
      const NotificationManagementPanel(),
      const InboxPageAdmin(),
      const ShopInfo(),
      const PetAnalyticsPage(),
      const RevenuePage(),
      const SocialPostsAdmin(), // Social Network - Posts Management
      const SocialAccountsAdmin(), // Social Network - Accounts Management
      const CommunityGroupsAdmin(), // Social Network - Groups Management
      const SensitiveWordsAdmin(), // Social Network - Sensitive Words
      const ThemeSettingsAdmin(), // Theme Settings
      //  const ShippingManagementPage(),
      //  const GHNTestPage(), // GHN Test page
    ];
  }

  void _setIndex(int i) {
    if (i < 0 || i >= _pages.length) return;
    setState(() => _selectedIndex = i);
  }

  @override
  void dispose() {
    // Clean up any resources
    super.dispose();
  }

  Future<void> _fetchRole() async {
    try {
      final info = await authService.value.getUserInfo();
      if (mounted) {
        setState(() {
          _role = info?['role'] ?? 'user';
          _loading = false;
        });
      }
    } catch (e) {
      // Handle error gracefully
      print('Error fetching role: $e');
      if (mounted) {
        setState(() {
          _role = 'user'; // Default to non-admin
          _loading = false;
        });
      }
    }
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

  // Helper methods for navigation
  List<NavigationItem> _getNavigationItems() {
    final l10n = AppLocalizations.of(context)!;
    return [
      NavigationItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: l10n.dashboard,
      ),
      NavigationItem(
        icon: Icons.pets_outlined,
        selectedIcon: Icons.pets,
        label: l10n.pets,
      ),
      NavigationItem(
        icon: Icons.category_outlined,
        selectedIcon: Icons.category,
        label: l10n.category,
      ),
      NavigationItem(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: l10n.account,
      ),
      NavigationItem(
        icon: Icons.shopping_bag_outlined,
        selectedIcon: Icons.shopping_bag,
        label: l10n.ordersMenu,
        subItems: [
          NavigationItem(
            icon: Icons.book_online_outlined,
            selectedIcon: Icons.book_online,
            label: l10n.manageReservations,
          ),
          NavigationItem(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping,
            label: l10n.manageOrders,
          ),
        ],
      ),
      NavigationItem(
        icon: Icons.notifications_active_outlined,
        selectedIcon: Icons.notifications_active,
        label: l10n.notification,
      ),
      NavigationItem(
        icon: Icons.inbox_outlined,
        selectedIcon: Icons.inbox,
        label: l10n.inbox,
      ),
      NavigationItem(
        icon: Icons.store_outlined,
        selectedIcon: Icons.store,
        label: l10n.shopInfo,
      ),
      NavigationItem(
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics,
        label: l10n.petAnalytics,
      ),
      NavigationItem(
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        label: l10n.revenue,
      ),
      NavigationItem(
        icon: Icons.hub_outlined,
        selectedIcon: Icons.hub,
        label: l10n.socialNetwork,
        subItems: [
          NavigationItem(
            icon: Icons.article_outlined,
            selectedIcon: Icons.article,
            label: l10n.managePosts,
          ),
          NavigationItem(
            icon: Icons.people_outlined,
            selectedIcon: Icons.people,
            label: l10n.manageAccounts,
          ),
          NavigationItem(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            label: l10n.manageCommunityGroups,
          ),
          NavigationItem(
            icon: Icons.block_outlined,
            selectedIcon: Icons.block,
            label: l10n.manageSensitiveWords,
          ),
        ],
      ),
      NavigationItem(
        icon: Icons.palette_outlined,
        selectedIcon: Icons.palette,
        label: l10n.themeSettings,
      ),
      // NavigationItem(
      //   icon: Icons.local_shipping_outlined,
      //   selectedIcon: Icons.local_shipping,
      //   label: 'Giao hàng',
      // ),
      // NavigationItem(
      //   icon: Icons.bug_report_outlined,
      //   selectedIcon: Icons.bug_report,
      //   label: 'GHN Test',
      // ),
    ];
  }

  Widget _buildNavigationItem(int index, NavigationItem item) {
    if (!mounted) return const SizedBox.shrink();
    
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    final hasSubItems = item.subItems != null && item.subItems!.isNotEmpty;

    // Check if any sub-item is selected
    final isSubItemSelected = hasSubItems && 
        _selectedIndex >= index && 
        _selectedIndex < index + item.subItems!.length;

    if (hasSubItems) {
      // Determine which menu this is based on item properties
      final isSocialMenu = item.label == AppLocalizations.of(context)!.socialNetwork;
      final isOrdersMenu = item.label == AppLocalizations.of(context)!.ordersMenu;
      final isExpanded = isSocialMenu ? _socialMenuExpanded : (isOrdersMenu ? _ordersMenuExpanded : false);
      
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Material(
              color: (isSubItemSelected || isExpanded)
                  ? theme.colorScheme.primary.withOpacity(0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (mounted) {
                    setState(() {
                      if (isSocialMenu) {
                        _socialMenuExpanded = !_socialMenuExpanded;
                      } else if (isOrdersMenu) {
                        _ordersMenuExpanded = !_ordersMenuExpanded;
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isSubItemSelected ? item.selectedIcon : item.icon,
                        color: isSubItemSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: isSubItemSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight:
                                isSubItemSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        isExpanded 
                            ? Icons.keyboard_arrow_up 
                            : Icons.keyboard_arrow_down,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Sub-items
          if (isExpanded)
            ...item.subItems!.asMap().entries.map((entry) {
              final subIndex = index + entry.key;
              final subItem = entry.value;
              final isSubSelected = _selectedIndex == subIndex;
              
              return Container(
                margin: const EdgeInsets.only(left: 24, right: 8, top: 2, bottom: 2),
                child: Material(
                  color: isSubSelected
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (mounted) {
                        _setIndex(subIndex);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            isSubSelected ? subItem.selectedIcon : subItem.icon,
                            color: isSubSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subItem.label,
                              style: TextStyle(
                                color: isSubSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight:
                                    isSubSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (mounted) {
              _setIndex(index);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Error boundary - prevent complete crashes
    try {
      final l10n = AppLocalizations.of(context)!;

      if (_loading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      
      if (_role != 'admin') {
        return const LoginAdminPage();
      }
      
      final items = _getNavigationItems();
      
      // Calculate responsive sidebar width based on screen size
      final screenWidth = MediaQuery.of(context).size.width;
      final sidebarWidth = screenWidth < 1200 ? 200.0 : 220.0;
      final showSidebar = screenWidth >= 400;
      
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          leading: !showSidebar ? IconButton(
            icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ) : null,
          automaticallyImplyLeading: !showSidebar,
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
        drawer: !showSidebar ? Drawer(
          child: Column(
            children: [
              // Drawer header
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
                child: Center(
                  child: Text(
                    l10n.adminPanel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Navigation items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: Icon(
                      _selectedIndex == i ? items[i].selectedIcon : items[i].icon,
                      color: _selectedIndex == i
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      items[i].label,
                      style: TextStyle(
                        color: _selectedIndex == i
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: _selectedIndex == i ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    selected: _selectedIndex == i,
                    onTap: () {
                      _setIndex(i);
                      Navigator.of(context).pop(); // Close drawer
                    },
                  ),
                ),
              ),
            ],
          ),
        ) : null,
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate safe sidebar width with proper bounds checking
            final isVerySmall = constraints.maxWidth < 600;
            final maxSidebarWidth = constraints.maxWidth * (isVerySmall ? 0.4 : 0.3);
            final minSidebarWidth = isVerySmall ? 150.0 : 180.0;
            final safeSidebarWidth = maxSidebarWidth < minSidebarWidth 
                ? minSidebarWidth 
                : sidebarWidth.clamp(minSidebarWidth, maxSidebarWidth);
            
            return Row(
              children: [
                // Sidebar Navigation - Responsive
                if (showSidebar) // Use the showSidebar variable instead of checking width again
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxSidebarWidth,
                      minWidth: minSidebarWidth,
                    ),
                    child: Container(
                      width: safeSidebarWidth,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          // Calculate actual page index
                          // Parent items with subitems don't have their own page
                          // Only count actual pages before this item
                          int pageIndex = 0;
                          for (int j = 0; j < i; j++) {
                            if (items[j].subItems != null && items[j].subItems!.isNotEmpty) {
                              // Parent with subitems: count subitems but not parent itself
                              pageIndex += items[j].subItems!.length;
                            } else {
                              // Regular item: count it
                              pageIndex += 1;
                            }
                          }
                          return _buildNavigationItem(pageIndex, items[i]);
                        },
                      ),
                    ),
                  ),
                // Main content area - Takes remaining space
                Expanded(
                  child: SafeArea(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_selectedIndex),
                        child: _selectedIndex < _pages.length 
                            ? _pages[_selectedIndex] 
                            : _pages[0],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      // Fallback UI in case of any layout errors
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.adminPanel),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.somethingWentWrong,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      );
    }
  }
}
