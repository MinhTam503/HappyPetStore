import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Modern download app section with animations for both mobile and desktop
class DownloadAppSection extends StatelessWidget {
  final bool isMobile;
  
  const DownloadAppSection({
    super.key,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return _MobileDownloadButtons();
    }
    return _DesktopDownloadButtons();
  }
}

/// Compact buttons for mobile AppBar
class _MobileDownloadButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedDownloadButton(
          icon: Icons.android,
          label: 'Android',
          onPressed: () => _downloadApp(context, 'android'),
          compact: true,
        ),
        const SizedBox(width: 8),
        _AnimatedDownloadButton(
          icon: Icons.apple,
          label: 'iOS',
          onPressed: () => _downloadApp(context, 'ios'),
          compact: true,
        ),
      ],
    );
  }
}

/// Larger buttons for desktop with more details
class _DesktopDownloadButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.05),
            secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            l10n?.downloadApp ?? 'Download Mobile App',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.downloadAppSubtitle ?? 'Get the best experience on your mobile device',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _AnimatedDownloadButton(
                    icon: Icons.android,
                    label: 'Android',
                    subtitle: l10n?.downloadForAndroid ?? 'Download for Android',
                    onPressed: () => _downloadApp(context, 'android'),
                    expanded: isWide,
                  ),
                  _AnimatedDownloadButton(
                    icon: Icons.apple,
                    label: 'iOS',
                    subtitle: l10n?.downloadForIOS ?? 'Download for iOS',
                    onPressed: () => _downloadApp(context, 'ios'),
                    expanded: isWide,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedDownloadButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onPressed;
  final bool compact;
  final bool expanded;

  const _AnimatedDownloadButton({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onPressed,
    this.compact = false,
    this.expanded = false,
  });

  @override
  State<_AnimatedDownloadButton> createState() => _AnimatedDownloadButtonState();
}

class _AnimatedDownloadButtonState extends State<_AnimatedDownloadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    if (_isDownloading) return;
    
    setState(() => _isDownloading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    
    widget.onPressed();
    
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.icon == Icons.apple;
    
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(widget.compact ? 10 : 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.expanded ? 250 : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 12 : 24,
              vertical: widget.compact ? 8 : 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isHovering
                    ? [
                        isDark ? Colors.black : primaryColor,
                        isDark ? Colors.grey[900]! : primaryColor.withOpacity(0.8),
                      ]
                    : [
                        Colors.white,
                        Colors.white,
                      ],
              ),
              borderRadius: BorderRadius.circular(widget.compact ? 10 : 16),
              border: Border.all(
                color: _isHovering
                    ? Colors.transparent
                    : (isDark ? Colors.black : primaryColor),
                width: 1.5,
              ),
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: (isDark ? Colors.black : primaryColor).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: _isDownloading
                ? SizedBox(
                    height: widget.compact ? 20 : 24,
                    width: widget.compact ? 20 : 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isHovering ? Colors.white : (isDark ? Colors.black : primaryColor),
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        size: widget.compact ? 20 : 32,
                        color: _isHovering
                            ? Colors.white
                            : (isDark ? Colors.black : primaryColor),
                      ),
                      SizedBox(width: widget.compact ? 6 : 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: widget.compact ? 14 : 18,
                              fontWeight: FontWeight.w600,
                              color: _isHovering
                                  ? Colors.white
                                  : (isDark ? Colors.black : primaryColor),
                            ),
                          ),
                          if (!widget.compact && widget.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isHovering
                                      ? Colors.white70
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

Future<void> _downloadApp(BuildContext context, String platform) async {
  final l10n = AppLocalizations.of(context);
  
  try {
    String url;
    if (platform == 'android') {
      // Option 1: Use Firebase Storage URL (recommended)
      url = 'https://firebasestorage.googleapis.com/v0/b/YOUR_PROJECT_ID.appspot.com/o/apps%2Fapp-release.apk?alt=media';
      
      // Option 2: Use direct server URL if you host the file
      // url = 'https://your-domain.com/downloads/app-release.apk';
      
      // Option 3: Use assets (for development only - not recommended for production)
      // Note: Assets cannot be downloaded directly in web, you need a server
      // url = 'assets/downloads/app-release.apk';
    } else {
      // iOS - Link to App Store or TestFlight
      url = 'https://apps.apple.com/app/your-app-id'; // Replace with your App Store ID
      // Or TestFlight: url = 'https://testflight.apple.com/join/YOUR_CODE';
    }
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              platform == 'android'
                  ? (l10n?.downloadingAndroid ?? 'Downloading Android app...')
                  : (l10n?.openingAppStore ?? 'Opening App Store...'),
            ),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      throw 'Could not launch $url';
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.downloadError ?? 'Error downloading app: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
