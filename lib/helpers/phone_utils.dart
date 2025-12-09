// Pure Dart helpers for Vietnam phone normalization
// Accept user input in 0XXXXXXXX, +84XXXXXXXX, or 84XXXXXXXX (flexible prefixes)
// Store in E.164 format: +84XXXXXXXX (8–10 national digits supported)
class PhoneUtils {
  /// Returns E.164 +84 format or null if invalid
  static String? normalizeVN(String input) {
    if (input.isEmpty) return null;
    final digits = input.replaceAll(RegExp(r'\D'), '');
    String national;
    if (digits.startsWith('84')) {
      national = digits.substring(2);
    } else if (digits.startsWith('0')) {
      national = digits.substring(1);
    } else {
      national = digits;
    }
    // Accept national part between 8 and 10 digits to be more flexible
    if (national.isEmpty || national.length < 8 || national.length > 10) {
      return null;
    }
    if (!RegExp(r'^\d{8,10}$').hasMatch(national)) {
      return null;
    }
    return '+84$national';
  }

  /// True if input can be normalized to a valid +84 E.164 VN mobile
  static bool isValidVN(String input) => normalizeVN(input) != null;

  /// Convert E.164 +84XXXXXXXXX to local 0XXXXXXXXX display
  static String toDisplay09(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('84') && digits.length >= 10) {
      // Convert +84 + national (8–10 digits) => 0 + national
      return '0${digits.substring(2)}';
    }
    // Already local 0 + national (9–11 total)
    if (digits.startsWith('0') && digits.length >= 9 && digits.length <= 11) return digits;
    return e164; // fallback
  }

  /// Compare two phone strings by normalized form
  static bool equals(String a, String b) {
    final na = normalizeVN(a);
    final nb = normalizeVN(b);
    return na != null && nb != null && na == nb;
  }

  /// Return potential legacy variants for searching existing data
  /// Includes: +84XXXXXXXXX and 0XXXXXXXXX
  static List<String> variants(String input) {
    final e164 = normalizeVN(input);
    if (e164 == null) return [];
    final local = toDisplay09(e164);
    return {e164, local}.toList();
  }
}
