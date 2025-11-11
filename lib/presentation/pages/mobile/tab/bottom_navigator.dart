import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/cart_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/favorite_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/home/home_page.dart'
    show HomePage;
import 'package:pet_shop/presentation/pages/mobile/tab/profile_screen.dart';
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
    const FavoriteScreen(),
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
          l10n?.favorite ?? "Yêu thích",
          l10n?.scanQRCode ?? "Quét QR",
          l10n?.cart ?? "Giỏ hàng",
          l10n?.profile ?? "Hồ sơ",
        ],
        icons: const [
          Icons.home_outlined,
          Icons.favorite_border,
          Icons.qr_code_scanner_outlined,
          Icons.shopping_cart_outlined,
          Icons.person_outline,
        ],
        activeIcons: const [
          Icons.home,
          Icons.favorite,
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

/// Fancy curved bottom bar with a center notch and elevated middle action, inspired by the provided design.
class _FancyBottomBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
  final height = 82.0;
  final notchRadius = 32.0;
  final circleSize = 56.0;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: height + 12,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Background with center notch
            SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _NavBarPainter(
                  background: secondaryColor,
                  shadowColor: Colors.black.withOpacity(0.06),
                  notchRadius: notchRadius,
                  notchDepth: 18,
                ),
              ),
            ),

            // Row of items (leave gap for center circle)
            Positioned.fill(
              bottom: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 0; i < 5; i++)
                    if (i == 2)
                      SizedBox(width: circleSize + 16) // gap for center
                    else
                      _BarItem(
                        icon: icons[i],
                        activeIcon: activeIcons[i],
                        label: labels[i],
                        selected: currentIndex == i,
                        onTap: () => onTap(i),
                      ),
                ],
              ),
            ),

            // Center elevated circle button (QR)
            Positioned(
              bottom: height - notchRadius - 15,
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    currentIndex == 2 ? activeIcons[2] : icons[2],
                    color: Colors.white,
                    size: 24, // slightly smaller center icon
                  ),
                ),
              ),
            ),

            // Center label under the circle
            Positioned(
              bottom: 16, // align baseline with other labels
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Text(
                  labels[2],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: currentIndex == 2 ? FontWeight.w700 : FontWeight.w500,
                    color: currentIndex == 2
                        ? primaryColor
                        : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = selected ? primaryColor : Theme.of(context).iconTheme.color?.withOpacity(0.6);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? primaryColor
                      : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarPainter extends CustomPainter {
  final Color background;
  final Color shadowColor;
  final double notchRadius;
  final double notchDepth;

  _NavBarPainter({
    required this.background,
    required this.shadowColor,
    required this.notchRadius,
    required this.notchDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = background
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;

    // Rounded rectangle with a smooth concave notch at the top center
    path.moveTo(0, 12);
    path.quadraticBezierTo(0, 0, 12, 0);
    // Left to notch start
    final notchStart = centerX - notchRadius * 1.4;
    final notchEnd = centerX + notchRadius * 1.4;
    path.lineTo(notchStart, 0);

    // Notch curve down and back up
    path.cubicTo(
      notchStart + notchRadius * 0.4, 0,
      centerX - notchRadius * 0.9, notchDepth,
      centerX, notchDepth + 2,
    );
    path.cubicTo(
      centerX + notchRadius * 0.9, notchDepth,
      notchEnd - notchRadius * 0.4, 0,
      notchEnd, 0,
    );

    // Top-right corner
    path.lineTo(w - 12, 0);
    path.quadraticBezierTo(w, 0, w, 12);
    path.lineTo(w, h - 12);
    path.quadraticBezierTo(w, h, w - 12, h);
    path.lineTo(12, h);
    path.quadraticBezierTo(0, h, 0, h - 12);
    path.close();

    // Shadow
    canvas.drawShadow(path, shadowColor, 6, true);
    // Fill
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
