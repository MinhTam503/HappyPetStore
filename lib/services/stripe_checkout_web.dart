import 'dart:html' as html;

// Web implementation for Stripe checkout
class StripeWebUtils {
  static String getOrigin() => html.window.location.origin;
  static void redirectToUrl(String url) {
    html.window.location.href = url;
  }
  static String getCurrentPathname() => html.window.location.pathname ?? '/';
  static String getCurrentHref() => html.window.location.href;
}
