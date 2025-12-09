import 'package:flutter/material.dart';

/// Tiện ích để quản lý bàn phím
class KeyboardUtils {
  /// Đóng bàn phím hiện tại
  static void hideKeyboard(BuildContext context) {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// Wrap widget với GestureDetector để đóng bàn phím khi tap ra ngoài
  /// Sử dụng: KeyboardUtils.dismissOnTap(context, child: yourWidget)
  static Widget dismissOnTap(BuildContext context, {required Widget child}) {
    return GestureDetector(
      onTap: () => hideKeyboard(context),
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
