import 'package:flutter/material.dart';
import 'package:pet_shop/presentation/pages/mobile/chatBot/chatbot_page.dart';
import 'package:pet_shop/core/services/theme_manager.dart';

class DraggableChatBubbleWidget extends StatefulWidget {
  final SeasonalTheme seasonalTheme;
  
  const DraggableChatBubbleWidget({
    super.key,
    this.seasonalTheme = SeasonalTheme.defaultTheme,
  });

  @override
  State<DraggableChatBubbleWidget> createState() => _DraggableChatBubbleWidgetState();
}

class _DraggableChatBubbleWidgetState extends State<DraggableChatBubbleWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;

  Offset _position = const Offset(20, 20); // Initial position from bottom-right
  late Size _screenSize;
  final double _bubbleSize = 60;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for the glow effect
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Bounce animation for tap feedback
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));

    // Start pulse animation
    _pulseController.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Position bubble at bottom-right initially with safe area
    _position = Offset(
      _screenSize.width - _bubbleSize - 20,
      _screenSize.height - _bubbleSize - 120 - bottomPadding, // Account for new smaller bottom navigation + safe area
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    setState(() {
      _position = Offset(
        (_position.dx + details.delta.dx).clamp(0.0, _screenSize.width - _bubbleSize),
        (_position.dy + details.delta.dy).clamp(0.0, _screenSize.height - _bubbleSize - 120 - bottomPadding),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Snap to edges
    setState(() {
      final screenCenter = _screenSize.width / 2;
      if (_position.dx < screenCenter) {
        // Snap to left edge
        _position = Offset(20, _position.dy);
      } else {
        // Snap to right edge
        _position = Offset(_screenSize.width - _bubbleSize - 20, _position.dy);
      }
    });
  }

  void _onTap() async {
    await _bounceController.forward();
    await _bounceController.reverse();
    
    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
              const ChatBotPage(userId: 'user_123'),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  // Get colors based on seasonal theme
  List<Color> _getBubbleGradient() {
    switch (widget.seasonalTheme) {
      case SeasonalTheme.noel:
        return [
          const Color(0xFFD32F2F), // Christmas red
          const Color(0xFF1B5E20), // Christmas green
        ];
      case SeasonalTheme.tet:
        return [
          const Color(0xFFFFD700), // Gold
          const Color(0xFFFFC107), // Yellow
        ];
      case SeasonalTheme.summer:
        return [
          const Color(0xFF00BCD4), // Cyan blue
          const Color(0xFF4DD0E1), // Light cyan
        ];
      case SeasonalTheme.autumn:
        return [
          const Color(0xFFFF8F00), // Orange
          const Color(0xFFD84315), // Deep orange
        ];
      case SeasonalTheme.defaultTheme:
        return [
          const Color(0xff08A045), // App green
          const Color(0xff06803A), // Darker green
        ];
    }
  }

  Color _getBubbleShadowColor() {
    switch (widget.seasonalTheme) {
      case SeasonalTheme.noel:
        return const Color(0xFFD32F2F);
      case SeasonalTheme.tet:
        return const Color(0xFFFFD700); // Gold
      case SeasonalTheme.summer:
        return const Color(0xFF00BCD4);
      case SeasonalTheme.autumn:
        return const Color(0xFFFF8F00);
      case SeasonalTheme.defaultTheme:
        return const Color(0xff08A045);
    }
  }

  IconData _getBubbleIcon() {
    switch (widget.seasonalTheme) {
      case SeasonalTheme.noel:
        return Icons.ac_unit; // Gift for Christmas
      case SeasonalTheme.tet:
        return Icons.spa; // Flower/blossom for Tet
      case SeasonalTheme.summer:
        return Icons.beach_access; // Beach umbrella for Summer
      case SeasonalTheme.autumn:
        return Icons.eco; // Leaf for Autumn
      case SeasonalTheme.defaultTheme:
        return Icons.smart_toy; // Robot/chatbot icon
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getBubbleGradient();
    final shadowColor = _getBubbleShadowColor();
    final iconData = _getBubbleIcon();

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: _onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _bounceAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _bounceAnimation.value,
              child: Container(
                width: _bubbleSize,
                height: _bubbleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor.withOpacity(0.4 * _pulseAnimation.value),
                      spreadRadius: 8 * _pulseAnimation.value,
                      blurRadius: 20,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(_bubbleSize / 2),
                    onTap: _onTap,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              iconData,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          // Notification badge
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.red[600],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}