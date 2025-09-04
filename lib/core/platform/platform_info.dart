import 'package:flutter/foundation.dart';

class PlatformInfo {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb;
  static bool get isDebug => kDebugMode;
  static bool get isRelease => kReleaseMode;
  static bool get isProfile => kProfileMode;
  
  static String get platformName {
    if (kIsWeb) return 'Web';
    return 'Mobile';
  }
  
  static String get buildMode {
    if (kDebugMode) return 'Debug';
    if (kReleaseMode) return 'Release';
    if (kProfileMode) return 'Profile';
    return 'Unknown';
  }
}
