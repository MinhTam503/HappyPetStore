import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Seasonal themes for app-wide styling and effects
enum SeasonalTheme {
  defaultTheme,
  noel, // Christmas - Winter
  tet, // Lunar New Year - Spring
  summer, // Summer
  autumn, // Autumn/Fall
}

class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal() {
    _loadThemeFromFirestore();
    _setupFirestoreListener();
  }

  final _controller = StreamController<SeasonalTheme>.broadcast();
  SeasonalTheme _current = SeasonalTheme.defaultTheme;
  final _firestore = FirebaseFirestore.instance;

  Stream<SeasonalTheme> get stream => _controller.stream;
  SeasonalTheme get current => _current;

  void _setupFirestoreListener() {
    _firestore.collection('appConfig').doc('theme').snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          final themeName = snapshot.data()?['currentTheme'] as String?;
          if (themeName != null) {
            final theme = SeasonalTheme.values.firstWhere(
              (t) => t.name == themeName,
              orElse: () => SeasonalTheme.defaultTheme,
            );
            if (_current != theme) {
              _current = theme;
              _controller.add(theme);
              debugPrint('🎨 Theme changed to: ${theme.name}');
            }
          }
        }
      },
      onError: (error) {
        debugPrint('Error listening to theme changes: $error');
      },
    );
  }

  Future<void> _loadThemeFromFirestore() async {
    try {
      final doc = await _firestore.collection('appConfig').doc('theme').get();
      if (doc.exists) {
        final themeName = doc.data()?['currentTheme'] as String?;
        if (themeName != null) {
          final theme = SeasonalTheme.values.firstWhere(
            (t) => t.name == themeName,
            orElse: () => SeasonalTheme.defaultTheme,
          );
          _current = theme;
          _controller.add(theme);
        }
      }
    } catch (e) {
      debugPrint('Error loading theme from Firestore: $e');
    }
  }

  Future<void> setTheme(SeasonalTheme theme) async {
    if (_current == theme) return;
    _current = theme;
    _controller.add(theme);

    // Save to Firestore
    try {
      await _firestore.collection('appConfig').doc('theme').set({
        'currentTheme': theme.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving theme to Firestore: $e');
      rethrow;
    }
  }

  ColorScheme colorSchemeFor(SeasonalTheme theme, Brightness brightness) {
    switch (theme) {
      case SeasonalTheme.noel:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C), // deep red
          brightness: Brightness.light,
          primary: const Color(0xFFD32F2F),
          secondary: const Color(0xFF2E7D32), // pine green
          surface: const Color.fromARGB(255, 251, 247, 247), // Very light red/pink background
          background: const Color(0xFFFFF5F5),
        );
      case SeasonalTheme.tet:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFA000), // amber/gold
          brightness: Brightness.light,
          primary: const Color(0xFFFFA000), // Amber gold
          secondary: const Color(0xFFFFD54F), // Light gold
          surface: const Color(0xFFFFF8E1), // Very light amber background
          background: const Color(0xFFFFF8E1),
        );
      case SeasonalTheme.summer:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4), // cyan blue
          brightness: Brightness.light,
          primary: const Color(0xFF00ACC1),
          secondary: const Color(0xFFFFEB3B), // sunny yellow
          surface: const Color(0xFFE0F7FA), // Very light cyan background
          background: const Color(0xFFE0F7FA),
        );
      case SeasonalTheme.autumn:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6F00), // deep orange
          brightness: Brightness.light,
          primary: const Color(0xFFFF8F00),
          secondary: const Color(0xFF8D6E63), // brown
          surface: const Color(0xFFFFF3E0), // Very light orange background
          background: const Color(0xFFFFF3E0),
        );
      case SeasonalTheme.defaultTheme:
        return ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: const Color(0xff08A045), // Original green color
          primary: const Color(0xff08A045),
          surface: const Color(0xFFE7FAE7), // Light green background
          background: const Color(0xFFE7FAE7),
        );
    }
  }
}
