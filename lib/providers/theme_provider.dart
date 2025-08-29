import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  static const String _themeKey = 'isDarkMode';

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  // Light theme with beautiful colors - keeping original green theme
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.green,
    primaryColor: const Color(0xff08A045), // Original green
    scaffoldBackgroundColor: const Color(0xfff2f6f2), // Original background
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE0E0E0),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xfff2f6f2), // backgroundColorWeb
      foregroundColor: Colors.black87,
      elevation: 0.5,
      centerTitle: false,
    ),
    
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.grey.withOpacity(0.1),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff08A045), // Original green
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xffe7fae7), // secondaryColor
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff08A045), width: 2), // Original green
      ),
    ),
    
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xff08A045).withOpacity(.15),
      labelStyle: const TextStyle(color: Colors.black87),
      secondaryLabelStyle: const TextStyle(color: Color(0xff08A045)),
    ),
    
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xffe7fae7), // secondaryColor
      selectedIconTheme: IconThemeData(color: Color(0xff08A045)),
      unselectedIconTheme: IconThemeData(color: Colors.black54),
      selectedLabelTextStyle: TextStyle(color: Color(0xff08A045)),
      unselectedLabelTextStyle: TextStyle(color: Colors.black54),
    ),
    
    colorScheme: const ColorScheme.light(
      primary: Color(0xff08A045), // Original green
      secondary: Color(0xffe7fae7), // Original light green
      surface: Colors.white,
      background: Color(0xfff2f6f2), // Original background
      error: Color(0xFFB00020),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.black87,
      onBackground: Colors.black87,
      onError: Colors.white,
    ),
  );

  // Dark theme with harmonious colors that complement the green theme
  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: Colors.green,
    primaryColor: const Color(0xff4CAF50), // Softer green for dark theme
    scaffoldBackgroundColor: const Color(0xFF0F1419), // Deep dark blue-grey
    cardColor: const Color(0xFF1C2127), // Dark grey with subtle warmth
    dividerColor: const Color(0xFF2F3640),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1C2127), // Dark card color
      foregroundColor: Color(0xFFE8F5E8), // Very light green tint
      elevation: 0.5,
      centerTitle: false,
    ),
    
    cardTheme: CardTheme(
      color: const Color(0xFF1C2127), // Dark grey cards
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.black.withOpacity(0.3),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff4CAF50), // Softer green
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2F3640), // Darker input background
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF404B5A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF404B5A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff4CAF50), width: 2), // Softer green
      ),
    ),
    
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF2F3640), // Dark chip background
      selectedColor: const Color(0xff4CAF50).withOpacity(.15),
      labelStyle: const TextStyle(color: Color(0xFFE8F5E8)),
      secondaryLabelStyle: const TextStyle(color: Color(0xff4CAF50)),
    ),
    
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF2F3640), // Dark navigation rail
      selectedIconTheme: IconThemeData(color: Color(0xff4CAF50)),
      unselectedIconTheme: IconThemeData(color: Color(0xFFE8F5E8)),
      selectedLabelTextStyle: TextStyle(color: Color(0xff4CAF50)),
      unselectedLabelTextStyle: TextStyle(color: Color(0xFFE8F5E8)),
    ),
    
    colorScheme: const ColorScheme.dark(
      primary: Color(0xff4CAF50), // Softer green for dark
      secondary: Color(0xFF2E7D32), // Darker green accent
      surface: Color(0xFF1C2127), // Dark card surface
      background: Color(0xFF0F1419), // Deep dark background
      error: Color(0xFFEF5350), // Softer red for dark
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFFE8F5E8), // Light green tinted text
      onBackground: Color(0xFFE8F5E8), // Light green tinted text
      onError: Colors.white,
    ),
  );
}
