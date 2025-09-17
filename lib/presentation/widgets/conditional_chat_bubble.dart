import 'package:flutter/material.dart';
import 'package:pet_shop/presentation/widgets/chat_bubble_widget.dart';
import 'package:pet_shop/core/services/settings_service.dart';

class ConditionalChatBubble extends StatefulWidget {
  const ConditionalChatBubble({super.key});

  @override
  State<ConditionalChatBubble> createState() => _ConditionalChatBubbleState();
}

class _ConditionalChatBubbleState extends State<ConditionalChatBubble> {
  bool _isVisible = true;
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadVisibilitySetting();
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

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }
    
    return const ChatBubbleWidget();
  }
}