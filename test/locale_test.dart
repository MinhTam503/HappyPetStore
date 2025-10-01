import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_shop/core/providers/locale_provider.dart';

void main() {
  group('LocaleProvider Tests', () {
    test('Should initialize with Vietnamese locale by default', () {
      final localeProvider = LocaleProvider();
      expect(localeProvider.locale.languageCode, equals('vi'));
    });

    test('Should change locale correctly', () async {
      final localeProvider = LocaleProvider();
      
      // Initially Vietnamese
      expect(localeProvider.locale.languageCode, equals('vi'));
      
      // Change to English
      localeProvider.setLocale(const Locale('en'));
      expect(localeProvider.locale.languageCode, equals('en'));
      
      // Change back to Vietnamese
      localeProvider.setLocale(const Locale('vi'));
      expect(localeProvider.locale.languageCode, equals('vi'));
    });

    test('Should not accept unsupported locales', () {
      final localeProvider = LocaleProvider();
      final originalLocale = localeProvider.locale;
      
      // Try to set unsupported locale
      localeProvider.setLocale(const Locale('fr')); // French is not supported
      
      // Should remain unchanged
      expect(localeProvider.locale, equals(originalLocale));
    });

    test('Should have correct supported locales', () {
      expect(LocaleProvider.supportedLocales, contains(const Locale('en')));
      expect(LocaleProvider.supportedLocales, contains(const Locale('vi')));
      expect(LocaleProvider.supportedLocales.length, equals(2));
    });

    test('Should have correct language names', () {
      expect(LocaleProvider.languageNames['en'], equals('English'));
      expect(LocaleProvider.languageNames['vi'], equals('Tiếng Việt'));
    });
  });
}