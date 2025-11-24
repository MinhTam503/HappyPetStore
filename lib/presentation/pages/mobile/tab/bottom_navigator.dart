import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/cart_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/home/home_page.dart'
    show HomePage;
import 'package:pet_shop/presentation/pages/mobile/tab/profile_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/social/social_home_page.dart';
import 'package:pet_shop/presentation/pages/mobile/qr_scanner/qr_scanner_screen.dart';
import 'package:pet_shop/presentation/widgets/conditional_draggable_chat_bubble.dart';
import 'package:pet_shop/presentation/widgets/common/app_drawer.dart';
import 'package:pet_shop/core/services/push_notification_service.dart';

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
    const SocialHomePage(),
    // const FavoriteScreen(),
    const QRScannerScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    // Ensure FCM token is synced once user reaches the home shell
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.syncNow();
    });
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
      bottomNavigationBar: _FancyBottomBar(
        currentIndex: selectedIndex,
        onTap: (i) => setState(() => selectedIndex = i),
        labels: [
          l10n?.home ?? "Home",
          l10n?.social ?? "Social",
          // l10n?.favorite ?? "Yêu thích",
          l10n?.scanQRCode ?? "Quét QR",
          l10n?.cart ?? "Giỏ hàng",
          l10n?.profile ?? "Hồ sơ",
        ],
        icons: const [
          Icons.home_outlined,
          Icons.pets_outlined,
          // Icons.favorite_border,
          Icons.qr_code_scanner_outlined,
          Icons.shopping_cart_outlined,
          Icons.person_outline,
        ],
        activeIcons: const [
          Icons.home,
          Icons.pets,
          // Icons.favorite,
          Icons.qr_code_scanner,
          Icons.shopping_cart,
          Icons.person,
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

/// Modern bottom bar with gradient, smooth animations inspired by Viettel design
class _FancyBottomBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> activeIcons;

  const _FancyBottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.labels,
    required this.icons,
    required this.activeIcons,
  });

  @override
  State<_FancyBottomBar> createState() => _FancyBottomBarState();
}

class _FancyBottomBarState extends State<_FancyBottomBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(_FancyBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circleSize = 56.0;
    final elevationHeight = 25.0; // Nửa circle nhô lên

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height:60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main bar with items
              Positioned.fill(
                child: Row(
                  children: [
                    // Left items (Home, Social)
                    for (int i = 0; i < 2; i++)
                      Expanded(
                        child: _BarItem(
                          icon: widget.icons[i],
                          activeIcon: widget.activeIcons[i],
                          label: widget.labels[i],
                          selected: widget.currentIndex == i,
                          onTap: () => widget.onTap(i),
                        ),
                      ),
                    
                    // Center space for QR button
                    SizedBox(width: circleSize + 5),
                    
                    // Right items (Cart, Profile)
                    for (int i = 3; i < 5; i++)
                      Expanded(
                        child: _BarItem(
                          icon: widget.icons[i],
                          activeIcon: widget.activeIcons[i],
                          label: widget.labels[i],
                          selected: widget.currentIndex == i,
                          onTap: () => widget.onTap(i),
                        ),
                      ),
                  ],
                ),
              ),

              // Center elevated circle button (QR Scanner)
              Positioned(
                left: MediaQuery.of(context).size.width / 2 - circleSize / 2,
                top: -elevationHeight,
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: widget.currentIndex == 2 ? _scaleAnimation.value : 1.0,
                      child: GestureDetector(
                        onTap: () => widget.onTap(2),
                        child: Container(
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryColor,
                                primaryColor.withOpacity(0.85),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(circleSize / 2),
                              onTap: () => widget.onTap(2),
                              child: Center(
                                child: Icon(
                                  widget.currentIndex == 2
                                      ? widget.activeIcons[2]
                                      : widget.icons[2],
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Center label below circle
              Positioned(
                left: 0,
                right: 0,
                bottom: 7,
                child: GestureDetector(
                  onTap: () => widget.onTap(2),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: widget.currentIndex == 2
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: widget.currentIndex == 2
                            ? primaryColor
                            : Colors.grey[600],
                      ),
                      child: Text(widget.labels[2]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_BarItem> createState() => _BarItemState();
}

class _BarItemState extends State<_BarItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    if (widget.selected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_BarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        splashColor: primaryColor.withOpacity(0.1),
        highlightColor: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with background
                  SizedBox(
                    height: 32,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background circle when selected
                        if (widget.selected)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                          ),
                        // Icon
                        Transform.scale(
                          scale: widget.selected ? _iconScaleAnimation.value : 1.0,
                          child: Icon(
                            widget.selected ? widget.activeIcon : widget.icon,
                            color: widget.selected
                                ? primaryColor
                                : Colors.grey[600],
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Label
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: widget.selected
                          ? primaryColor
                          : Colors.grey[600],
                    ),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
