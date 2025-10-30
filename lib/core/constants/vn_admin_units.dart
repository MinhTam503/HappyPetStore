import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// VNAdminUnits loads Vietnamese administrative units from an asset JSON
/// and exposes a flattened mapping of Province/City -> Wards/Communes.
///
/// JSON format expected (simplified):
/// {
///   "provinces": [
///     {"name": "Hồ Chí Minh", "wards": ["Bến Nghé", "Bến Thành", ...]},
///     {"name": "Hà Nội", "wards": ["Phúc Xá", "Trúc Bạch", ...]},
///     ...
///   ]
/// }
class VNAdminUnits {
  VNAdminUnits._();

  static final VNAdminUnits instance = VNAdminUnits._();

  List<String>? _provinces;
  Map<String, List<String>>? _wardsByProvince;

  bool get isLoaded => _provinces != null && _wardsByProvince != null;

  List<String> get provinces => _provinces ?? const [];
  Map<String, List<String>> get wardsByProvince => _wardsByProvince ?? const {};

  /// Loads the JSON dataset from assets. Safe to call multiple times; cached.
  Future<void> load() async {
    if (isLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/vn_admin_units.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final List<dynamic> provincesData = data['provinces'] as List<dynamic>;

      final List<String> provinces = [];
      final Map<String, List<String>> wardsByProvince = {};

      for (final item in provincesData) {
        final map = item as Map<String, dynamic>;
        final name = (map['name'] as String).trim();
        final wardsRaw = (map['wards'] as List<dynamic>? ?? const []);
        final wards = wardsRaw
            .map((e) => (e as String).trim())
            .where((e) => e.isNotEmpty)
            .toSet() // de-dup
            .toList()
          ..sort((a, b) => a.compareTo(b));
        provinces.add(name);
        wardsByProvince[name] = wards;
      }

      provinces.sort((a, b) => a.compareTo(b));

      _provinces = provinces;
      _wardsByProvince = wardsByProvince;
    } catch (e) {
      // If loading fails, leave as empty; caller may fallback.
    }
  }
}
