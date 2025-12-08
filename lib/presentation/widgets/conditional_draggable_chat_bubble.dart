import 'package:flutter/material.dart';
import 'package:pet_shop/presentation/widgets/draggable_chat_bubble_widget.dart';
import 'package:pet_shop/core/services/settings_service.dart';
import 'package:pet_shop/core/services/theme_manager.dart';
import 'dart:async';

class ConditionalDraggableChatBubble extends StatefulWidget {
  const ConditionalDraggableChatBubble({super.key});

  @override
  State<ConditionalDraggableChatBubble> createState() => _ConditionalDraggableChatBubbleState();
}

class _ConditionalDraggableChatBubbleState extends State<ConditionalDraggableChatBubble> {
  bool _isVisible = true;
  bool _useAdminTheme = true;
  final SettingsService _settingsService = SettingsService();
  StreamSubscription<bool>? _visibilitySubscription;
  StreamSubscription<bool>? _themeSubscription;

  @override
  void initState() {
    super.initState();
    _loadVisibilitySetting();
    _loadThemeSetting();
    _listenToSettingsChanges();
  }

  Future<void> _loadVisibilitySetting() async {
    try {
      final isVisible = await _settingsService.getChatBubbleVisibility();
      if (mounted) {
        setState(() {
          _isVisible = isVisible;
        });
      }
    } catch (e) {
      debugPrint('Error loading chat bubble visibility: $e');
      // Default to visible if error occurs
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    }
  }

  Future<void> _loadThemeSetting() async {
    try {
      final useAdminTheme = await _settingsService.getUseAdminTheme();
      if (mounted) {
        setState(() {
          _useAdminTheme = useAdminTheme;
        });
      }
    } catch (e) {
      debugPrint('Error loading theme setting: $e');
      if (mounted) {
        setState(() {
          _useAdminTheme = true;
        });
      }
    }
  }

  void _listenToSettingsChanges() {
    _visibilitySubscription = _settingsService.chatBubbleVisibilityStream.listen(
      (isVisible) {
        if (mounted) {
          setState(() {
            _isVisible = isVisible;
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to chat bubble visibility changes: $error');
      },
    );
    
    _themeSubscription = _settingsService.useAdminThemeStream.listen(
      (useAdminTheme) {
        if (mounted) {
          setState(() {
            _useAdminTheme = useAdminTheme;
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to theme setting changes: $error');
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload settings when dependencies change (e.g., coming back from settings page)
    _loadVisibilitySetting();
    _loadThemeSetting();
  }

  @override
  void dispose() {
    _visibilitySubscription?.cancel();
    _themeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }
    
    // If user chose default theme, always use default theme
    if (!_useAdminTheme) {
      return const DraggableChatBubbleWidget(seasonalTheme: SeasonalTheme.defaultTheme);
    }
    
    // Otherwise follow admin theme
    final themeManager = ThemeManager();
    return StreamBuilder<SeasonalTheme>(
      stream: themeManager.stream,
      initialData: themeManager.current,
      builder: (context, snapshot) {
        final theme = snapshot.data ?? SeasonalTheme.defaultTheme;
        return DraggableChatBubbleWidget(seasonalTheme: theme);
      },
    );
  }
}