import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'payment/keys.dart';

class StripeHelper {
  static bool _initialized = false;
  
  /// Initialize Stripe with proper web/mobile handling
  static Future<bool> initialize() async {
    if (_initialized) {
      if (kDebugMode) {
        print('Stripe already initialized, skipping...');
      }
      return true;
    }
    
    try {
      final publishableKey = PublishableKey;
      if (publishableKey.isEmpty) {
        if (kDebugMode) {
          print(' Stripe publishable key is empty; skipping initialization.');
        }
        return false;
      }
      
      // Skip Stripe initialization entirely on web for now
      // Web payments will use Stripe.js directly in payment screens
      if (kIsWeb) {
        if (kDebugMode) {
          print(' Web platform detected - Stripe.js will be used for payments');
          print(' Publishable key available: ${publishableKey.substring(0, 20)}...');
        }
        _initialized = true;
        return true;
      }
      
      // Only initialize Flutter Stripe on mobile platforms
      if (kDebugMode) {
        print(' Initializing Stripe for mobile platform...');
      }
      Stripe.publishableKey = publishableKey;
      
      try {
        await Stripe.instance.applySettings();
        if (kDebugMode) {
          print('Stripe mobile settings applied successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print(' Stripe mobile settings failed, continuing anyway: $e');
        }
        // Continue execution - this is not fatal
      }
      
      _initialized = true;
      if (kDebugMode) {
        print(' Stripe mobile initialized successfully with key: ${publishableKey.substring(0, 20)}...');
      }
      return true;
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(' Stripe initialization failed: $e');
        print('Stack trace: $stackTrace');
      }
      return false;
    }
  }
  
  /// Check if Stripe is initialized and ready for payment sheet
  static bool get isInitialized => _initialized;
  
  /// Check if Stripe can be used for payment (more thorough check)
  static Future<bool> canUseStripe() async {
    if (!_initialized) {
      return await initialize();
    }
    
    // Additional check: try to access Stripe instance
    if (!kIsWeb) {
      try {
        // Just check if we can access the publishable key
        final key = Stripe.publishableKey;
        return key.isNotEmpty;
      } catch (e) {
        if (kDebugMode) {
          print('Stripe instance check failed: $e');
        }
        return false;
      }
    }
    
    return true;
  }
  
  /// Force re-initialization (for testing purposes)
  static void reset() {
    _initialized = false;
  }
  
  /// Get publishable key (works on both web and mobile)
  static String get publishableKey => PublishableKey;
}
