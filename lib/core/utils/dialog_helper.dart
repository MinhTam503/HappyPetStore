import 'package:flutter/material.dart';

class DialogHelper {
  static bool _isDialogShowing = false;
  
  static void showLoadingDialog(BuildContext context, {String message = "Đang xử lý..."}) {
    if (!_isDialogShowing) {
      _isDialogShowing = true;
      
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) {
          return Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.pink,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        },
      ).then((_) {
        // Reset flag when dialog is dismissed
        _isDialogShowing = false;
      });
    }
  }
  
  static Future<void> hideLoadingDialog(BuildContext context) async {
    if (_isDialogShowing) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
        _isDialogShowing = false;
        // Small delay to ensure dialog is fully closed
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        // Dialog might already be closed
        _isDialogShowing = false;
      }
    }
  }
  
  static bool get isDialogShowing => _isDialogShowing;
  
  static void forceReset() {
    _isDialogShowing = false;
  }
}
