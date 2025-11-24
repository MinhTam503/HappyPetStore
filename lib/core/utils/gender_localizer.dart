import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Helper class to localize pet gender based on species
class GenderLocalizer {
  /// Get localized gender display text based on species and gender
  /// Returns appropriate term for each species:
  /// - Dog/Cat: Đực/Cái (Male/Female)
  /// - Bird: Trống/Mái (Male/Female) 
  /// - Fish: Đực/Cái (Male/Female)
  static String getLocalizedGender(
    AppLocalizations l10n,
    String? category,
    String? gender,
  ) {
    if (gender == null || gender.isEmpty) return '';
    
    final normalizedGender = gender.toLowerCase();
    final normalizedCategory = category?.toLowerCase() ?? '';
    
    // Determine if male or female (accept both "Male"/"male" and "Female"/"female")
    final isMale = normalizedGender == 'male' || 
                   normalizedGender == 'đực' || 
                   normalizedGender == 'trống';
    
    // Special case for birds (chim or "Birds")
    if (normalizedCategory == 'birds' || 
        normalizedCategory == 'bird' ||
        normalizedCategory == 'chim') {
      return isMale ? l10n.maleBird : l10n.femaleBird;
    }
    
    // Default for Dogs, Cats, Fish and others
    return isMale ? l10n.male : l10n.female;
  }
  
  /// Normalize gender input to standard 'Male' or 'Female' for storage
  /// Accepts various inputs and returns standardized value with capital first letter
  static String normalizeGenderForStorage(String? gender) {
    if (gender == null || gender.isEmpty) return 'Male';
    
    final normalized = gender.toLowerCase().trim();
    
    // Male variants
    if (normalized == 'male' || 
        normalized == 'đực' || 
        normalized == 'trống' ||
        normalized == 'duc' ||
        normalized == 'trong') {
      return 'Male';
    }
    
    // Female variants
    if (normalized == 'female' || 
        normalized == 'cái' || 
        normalized == 'mái' ||
        normalized == 'cai' ||
        normalized == 'mai') {
      return 'Female';
    }
    
    // Default to Male if unknown
    return 'Male';
  }
  
  /// Get category display name with localization
  /// Works with both English names (Dogs, Cats, Birds, Fish) and Vietnamese
  static String getLocalizedCategory(AppLocalizations l10n, String? category) {
    if (category == null || category.isEmpty) return '';
    
    final normalized = category.toLowerCase();
    
    // Match exact category names from Firebase: Dogs, Cats, Birds, Fish
    if (normalized == 'dogs' || normalized == 'dog' || normalized == 'chó') {
      return l10n.dog;
    } else if (normalized == 'cats' || normalized == 'cat' || normalized == 'mèo') {
      return l10n.cat;
    } else if (normalized == 'birds' || normalized == 'bird' || normalized == 'chim') {
      return l10n.bird;
    } else if (normalized == 'fish' || normalized == 'cá') {
      return l10n.fish;
    }
    
    return category;
  }
}
