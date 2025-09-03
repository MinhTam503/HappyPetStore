import 'dart:io';

// Mobile implementation  
class PlatformInfo {
  static String getBrowserInfo() => 'Mobile App - ${Platform.operatingSystem}';
  static String getProtocol() => 'mobile://';
  static String getHost() => 'localhost';
  static bool isHttps() => false;
}
