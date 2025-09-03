import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Use getters so values are read from dotenv at runtime (after dotenv.load()).
// Guard access because dotenv.load() may fail (for example on web or if .env
// is missing). Returning an empty string is a safe fallback.
String get PublishableKey {
	try {
		// For web deployment, use hardcoded key since .env is not deployed
		if (kIsWeb) {
			return 'pk_test_51OBgBVK5lhkPHoduBFGnQNzV5OVqSMc3Lv2GNMtN8o03NxqVReD9HyhypOyylJ07JIxoIskPjNUnOwBVEo8VQq0p00rO0dSYCa';
		}
		
		final key = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
		if (key.isEmpty) {
			debugPrint('⚠️ STRIPE_PUBLISHABLE_KEY not found in dotenv, using fallback');
			return 'pk_test_51OBgBVK5lhkPHoduBFGnQNzV5OVqSMc3Lv2GNMtN8o03NxqVReD9HyhypOyylJ07JIxoIskPjNUnOwBVEo8VQq0p00rO0dSYCa';
		}
		return key;
	} catch (e) {
		debugPrint('❌ Error accessing STRIPE_PUBLISHABLE_KEY: $e');
		// Fallback for both web and mobile if dotenv fails
		return 'pk_test_51OBgBVK5lhkPHoduBFGnQNzV5OVqSMc3Lv2GNMtN8o03NxqVReD9HyhypOyylJ07JIxoIskPjNUnOwBVEo8VQq0p00rO0dSYCa';
	}
}

String get SecretKey {
	try {
		final key = dotenv.env['STRIPE_SECRET_KEY'] ?? '';
		if (key.isEmpty) {
			debugPrint('STRIPE_SECRET_KEY not found in dotenv, returning empty');
			return '';
		}
		return key;
	} catch (e) {
		debugPrint('Error accessing STRIPE_SECRET_KEY: $e');
		return '';
	}
}