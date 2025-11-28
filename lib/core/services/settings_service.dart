import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SettingsService {
  static const String _chatBubbleKey = 'show_chat_bubble';
  static const String _languageKey = 'selected_language';
  static const String _searchHistoryKey = 'save_search_history';
  static const String _viewedPetsHistoryKey = 'save_viewed_pets_history';
  static const String _useAdminThemeKey = 'use_admin_theme'; // true = follow admin, false = default theme

  // Singleton instance
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Stream controllers for settings changes
  final _chatBubbleController = StreamController<bool>.broadcast();
  final _languageController = StreamController<String>.broadcast();
  final _searchHistoryController = StreamController<bool>.broadcast();
  final _viewedPetsHistoryController = StreamController<bool>.broadcast();
  final _useAdminThemeController = StreamController<bool>.broadcast();

  // Streams for listening to changes
  Stream<bool> get chatBubbleVisibilityStream => _chatBubbleController.stream;
  Stream<String> get languageStream => _languageController.stream;
  Stream<bool> get searchHistoryStream => _searchHistoryController.stream;
  Stream<bool> get viewedPetsHistoryStream => _viewedPetsHistoryController.stream;
  Stream<bool> get useAdminThemeStream => _useAdminThemeController.stream;

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

  // Search History Settings
  Future<bool> getSearchHistoryEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_searchHistoryKey) ?? true; // Default to true
    } catch (e) {
      return true; // Default fallback
    }
  }

  Future<void> setSearchHistoryEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_searchHistoryKey, enabled);
      // Notify listeners
      _searchHistoryController.add(enabled);
    } catch (e) {
      // Handle error silently or log
    }
  }

  // Viewed Pets History Settings
  Future<bool> getViewedPetsHistoryEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_viewedPetsHistoryKey) ?? true; // Default to true
    } catch (e) {
      return true; // Default fallback
    }
  }

  Future<void> setViewedPetsHistoryEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_viewedPetsHistoryKey, enabled);
      // Notify listeners
      _viewedPetsHistoryController.add(enabled);
    } catch (e) {
      // Handle error silently or log
    }
  }

  // Theme Preference Settings
  Future<bool> getUseAdminTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_useAdminThemeKey) ?? true; // Default to follow admin theme
    } catch (e) {
      return true; // Default fallback
    }
  }

  Future<void> setUseAdminTheme(bool useAdminTheme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useAdminThemeKey, useAdminTheme);
      // Notify listeners
      _useAdminThemeController.add(useAdminTheme);
    } catch (e) {
      // Handle error silently or log
    }
  }

  // Dispose method to close stream controllers
  void dispose() {
    _chatBubbleController.close();
    _languageController.close();
    _searchHistoryController.close();
    _viewedPetsHistoryController.close();
    _useAdminThemeController.close();
  }
}