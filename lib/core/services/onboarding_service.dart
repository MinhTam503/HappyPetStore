import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _hasSeenGetStartedKey = 'hasSeenGetStarted';

  /// Kiểm tra xem người dùng đã xem màn hình GetStarted chưa
  static Future<bool> hasSeenGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenGetStartedKey) ?? false;
  }

  /// Đánh dấu người dùng đã xem màn hình GetStarted
  static Future<void> setHasSeenGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenGetStartedKey, true);
  }

  /// Reset trạng thái (dùng cho testing)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasSeenGetStartedKey);
  }
}
