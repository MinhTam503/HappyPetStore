import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('vi'); // Default to Vietnamese

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  void _loadLocale() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('language_code');
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  void setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    
    _locale = locale;
    notifyListeners();
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
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
