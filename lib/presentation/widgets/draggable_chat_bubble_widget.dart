import 'package:flutter/material.dart';
import 'package:pet_shop/presentation/pages/mobile/chatBot/chatbot_page.dart';

class DraggableChatBubbleWidget extends StatefulWidget {
  const DraggableChatBubbleWidget({super.key});

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
    
    // Position bubble at bottom-right initially
    _position = Offset(
      _screenSize.width - _bubbleSize - 20,
      _screenSize.height - _bubbleSize - 100, // Account for bottom navigation
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position = Offset(
        (_position.dx + details.delta.dx).clamp(0.0, _screenSize.width - _bubbleSize),
        (_position.dy + details.delta.dy).clamp(0.0, _screenSize.height - _bubbleSize - 80),
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

  @override
  Widget build(BuildContext context) {
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
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3 * _pulseAnimation.value),
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
                          const Center(
                            child: Icon(
                              Icons.pets,
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