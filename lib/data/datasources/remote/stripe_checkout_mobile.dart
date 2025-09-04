import 'package:url_launcher/url_launcher.dart';

// Mobile implementation for Stripe checkout
class StripeWebUtils {
  static String getOrigin() => 'https://your-app.com';
  
  static void redirectToUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  static String getCurrentPathname() => '/mobile';
  static String getCurrentHref() => 'https://your-app.com/mobile';
}
