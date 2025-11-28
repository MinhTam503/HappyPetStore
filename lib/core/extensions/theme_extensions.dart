import 'package:flutter/material.dart';

/// Extension to easily get theme colors from BuildContext
/// This helps migrate from static constants to dynamic theme colors
extension ThemeColors on BuildContext {
  /// Get primary color from current theme
  Color get primaryColor => Theme.of(this).colorScheme.primary;
  
  /// Get secondary color from current theme
  Color get secondaryColor => Theme.of(this).colorScheme.secondary;
  
  /// Get surface color from current theme
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  
  /// Get background color from current theme
  Color get backgroundColor => Theme.of(this).colorScheme.background;
  
  /// Get error color from current theme
  Color get errorColor => Theme.of(this).colorScheme.error;
}
