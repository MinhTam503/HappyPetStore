import 'package:intl/intl.dart';

class CurrencyHelper {
  static final NumberFormat _vndFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static String formatVND(dynamic value) {
    if (value == null) return '0 ₫';
    // value có thể là String '5000000' hoặc number
    num? number;
    if (value is num) {
      number = value;
    } else if (value is String) {
      // loại bỏ ký tự không phải số
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.isEmpty) return '0 ₫';
      number = num.tryParse(cleaned) ?? 0;
    } else {
      return '0 ₫';
    }
    return _vndFormat.format(number);
  }
}
