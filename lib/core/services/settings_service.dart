import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SettingsService {
  static const String _chatBubbleKey = 'show_chat_bubble';
  static const String _languageKey = 'selected_language';

  // Singleton instance
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Stream controllers for settings changes
  final _chatBubbleController = StreamController<bool>.broadcast();
  final _languageController = StreamController<String>.broadcast();

  // Streams for listening to changes
  Stream<bool> get chatBubbleVisibilityStream => _chatBubbleController.stream;
  Stream<String> get languageStream => _languageController.stream;

  // Chat Bubble Settings
  Future<bool> getChatBubbleVisibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_chatBubbleKey) ?? true; // Default to true
    } catch (e) {
      return true; // Default fallback
    }
  }

  Future<void> setChatBubbleVisibility(bool isVisible) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatBubbleKey, isVisible);
      // Notify listeners
      _chatBubbleController.add(isVisible);
    } catch (e) {
      // Handle error silently or log
    }
  }

  // Language Settings
  Future<String> getSelectedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languageKey) ?? 'vi'; // Default to Vietnamese
    } catch (e) {
      return 'vi'; // Default fallback
    }
  }

  Future<void> setSelectedLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      // Notify listeners
      _languageController.add(languageCode);
    } catch (e) {
      // Handle error silently or log
    }
  }

  // Dispose method to close stream controllers
  void dispose() {
    _chatBubbleController.close();
    _languageController.close();
  }
}