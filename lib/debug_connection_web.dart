import 'dart:html' as html;

// Web implementation
class PlatformInfo {
  static String getBrowserInfo() => html.window.navigator.userAgent;
  static String getProtocol() => html.window.location.protocol;
  static String getHost() => html.window.location.host;
  static bool isHttps() => html.window.location.protocol == 'https:';
}
