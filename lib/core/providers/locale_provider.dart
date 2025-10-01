import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('vi'); // Default to Vietnamese
  final SettingsService _settingsService = SettingsService();

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  void _loadLocale() async {
    try {
      // Try to get from SettingsService first
      String languageCode = await _settingsService.getSelectedLanguage();
      
      // Fallback to SharedPreferences if SettingsService returns default
      if (languageCode == 'vi') {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? savedLanguageCode = prefs.getString('language_code');
        if (savedLanguageCode != null) {
          languageCode = savedLanguageCode;
        }
      }
      
      if (supportedLocales.any((locale) => locale.languageCode == languageCode)) {
        _locale = Locale(languageCode);
        notifyListeners();
        
        // Sync SettingsService with the loaded locale
        await _settingsService.setSelectedLanguage(languageCode);
      }
    } catch (e) {
      debugPrint('Error loading locale: $e');
    }
  }

  void setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    
    _locale = locale;
    notifyListeners();
    
    try {
      // Save to both SharedPreferences and SettingsService
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', locale.languageCode);
      await _settingsService.setSelectedLanguage(locale.languageCode);
    } catch (e) {
      debugPrint('Error saving locale: $e');
    }
  }

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('vi'), // Vietnamese
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'vi': 'Tiếng Việt',
  };
}
