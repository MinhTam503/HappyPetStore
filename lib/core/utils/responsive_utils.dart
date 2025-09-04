import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BP {
  static const mobile = 600.0;   // <600
  static const tablet = 1024.0;  // 600-1024
  static const desktop = 1440.0; // 1024-1440
}

bool isMobile(BuildContext c) => MediaQuery.of(c).size.width < BP.mobile;
bool isTablet(BuildContext c) {
  final w = MediaQuery.of(c).size.width;
  return w >= BP.mobile && w < BP.tablet;
}
bool isDesktop(BuildContext c) => MediaQuery.of(c).size.width >= BP.tablet;

int gridCountForWidth(double w) {
  if (w < 600) return 2;
  if (w < 900) return 3;
  if (w < 1200) return 4;
  if (w < 1600) return 5;
  return 6;
}

double pageMaxWidth(BuildContext c) {
  final w = MediaQuery.of(c).size.width;
  return math.min(w, 1200); // khóa nội dung ở 1200px max trên desktop
}

EdgeInsets responsivePagePadding(BuildContext c) {
  final w = MediaQuery.of(c).size.width;
  if (w < 600) return const EdgeInsets.symmetric(horizontal: 12);
  if (w < 1024) return const EdgeInsets.symmetric(horizontal: 16);
  return const EdgeInsets.symmetric(horizontal: 20);
}

double responsiveSpacing(BuildContext c) {
  final w = MediaQuery.of(c).size.width;
  if (w < 600) return 10;
  if (w < 1024) return 14;
  return 18;
}

double categoryHeaderHeight(BuildContext c) {
  return isDesktop(c) ? 110 : 90;
}

bool get isWeb => kIsWeb;
