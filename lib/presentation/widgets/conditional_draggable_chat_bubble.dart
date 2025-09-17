import 'package:flutter/material.dart';
import 'package:pet_shop/presentation/widgets/draggable_chat_bubble_widget.dart';
import 'package:pet_shop/core/services/settings_service.dart';
import 'dart:async';

class ConditionalDraggableChatBubble extends StatefulWidget {
  const ConditionalDraggableChatBubble({super.key});

  @override
  State<ConditionalDraggableChatBubble> createState() => _ConditionalDraggableChatBubbleState();
}

class _ConditionalDraggableChatBubbleState extends State<ConditionalDraggableChatBubble> {
  bool _isVisible = true;
  final SettingsService _settingsService = SettingsService();
  StreamSubscription<bool>? _visibilitySubscription;

  @override
  void initState() {
    super.initState();
    _loadVisibilitySetting();
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload settings when dependencies change (e.g., coming back from settings page)
    _loadVisibilitySetting();
  }

  @override
  void dispose() {
    _visibilitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }
    
    return const DraggableChatBubbleWidget();
  }
}