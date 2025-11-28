import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class NotificationHelper {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  // Hiển thị thông báo thành công
  static void showSuccess(
    BuildContext context,
    String title, [
    String? message,
    Duration? duration,
  ]) {
    _showNotification(
      context,
      title: title,
      message: message,
      icon: Icons.check_circle,
      backgroundColor: Colors.green,
      iconColor: Colors.white,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  // Hiển thị thông báo lỗi
  static void showError(
    BuildContext context,
    String title, [
    String? message,
    Duration? duration,
  ]) {
    _showNotification(
      context,
      title: title,
      message: message,
      icon: Icons.error,
      backgroundColor: Colors.red,
      iconColor: Colors.white,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  // Hiển thị thông báo cảnh báo
  static void showWarning(
    BuildContext context,
    String title, [
    String? message,
    Duration? duration,
  ]) {
    _showNotification(
      context,
      title: title,
      message: message,
      icon: Icons.warning,
      backgroundColor: Colors.orange,
      iconColor: Colors.white,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  // Hiển thị thông báo thông tin
  static void showInfo(
    BuildContext context,
    String title, [
    String? message,
    Duration? duration,
  ]) {
    _showNotification(
      context,
      title: title,
      message: message,
      icon: Icons.info,
      backgroundColor: Theme.of(context).colorScheme.primary,
      iconColor: Colors.white,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  // Core method để hiển thị notification
  static void _showNotification(
    BuildContext context, {
    required String title,
    String? message,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required Duration duration,
  }) {
    // Đóng notification hiện tại nếu có
    if (_isShowing) {
      _hideNotification();
    }

    _isShowing = true;
    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => _NotificationOverlay(
        title: title,
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        iconColor: iconColor,
        onTap: _hideNotification,
      ),
    );

    overlay.insert(_overlayEntry!);

    // Tự động ẩn sau khoảng thời gian
    Future.delayed(duration, () {
      if (_isShowing) {
        _hideNotification();
      }
    });
  }

  static void _hideNotification() {
    if (_overlayEntry != null && _isShowing) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isShowing = false;
    }
  }

  // Kiểm tra xem có notification đang hiển thị không
  static bool get isShowing => _isShowing;

  // Đóng notification hiện tại (nếu có)
  static void hide() {
    _hideNotification();
  }
}

class _NotificationOverlay extends StatefulWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _NotificationOverlay({
    required this.title,
    this.message,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Positioned(
      top: padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: size.width - 32,
                minHeight: 60,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              decoration: TextDecoration.none),
                        ),
                        if (widget.message != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.message!,
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                decoration: TextDecoration.none),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Close button
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
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
  }
}
