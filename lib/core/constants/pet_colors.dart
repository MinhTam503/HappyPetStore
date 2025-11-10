import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Danh sách tất cả các màu sắc thú cưng được hỗ trợ
class PetColors {
  static const List<String> colorKeys = [
    'colorBrown',
    'colorBlack',
    'colorWhite',
    'colorGray',
    'colorGolden',
    'colorCream',
    'colorOrange',
    'colorBlue',
    'colorGreen',
    'colorRed',
    'colorMixed'
  ];

  /// Lấy màu Flutter Color từ color key
  static Color getColorFromKey(String colorKey) {
    switch (colorKey) {
      case 'colorBrown':
        return Colors.brown;
      case 'colorBlack':
        return Colors.black;
      case 'colorWhite':
        return Colors.white;
      case 'colorGray':
        return Colors.grey;
      case 'colorGolden':
        return Colors.amber;
      case 'colorCream':
        return const Color(0xFFF5DEB3);
      case 'colorOrange':
        return Colors.orange;
      case 'colorBlue':
        return Colors.blue;
      case 'colorGreen':
        return Colors.green;
      case 'colorRed':
        return Colors.red;
      case 'colorMixed':
        return Colors.grey.shade400;
      default:
        return Colors.grey;
    }
  }

  /// Lấy tên màu đã được localize từ color key
  static String getLocalizedColor(AppLocalizations l10n, String colorKey) {
    switch (colorKey) {
      case 'colorBrown':
        return l10n.colorBrown;
      case 'colorBlack':
        return l10n.colorBlack;
      case 'colorWhite':
        return l10n.colorWhite;
      case 'colorGray':
        return l10n.colorGray;
      case 'colorGolden':
        return l10n.colorGolden;
      case 'colorCream':
        return l10n.colorCream;
      case 'colorOrange':
        return l10n.colorOrange;
      case 'colorBlue':
        return l10n.colorBlue;
      case 'colorGreen':
        return l10n.colorGreen;
      case 'colorRed':
        return l10n.colorRed;
      case 'colorMixed':
        return l10n.colorMixed;
      default:
        return colorKey;
    }
  }
}
