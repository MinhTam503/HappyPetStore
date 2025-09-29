import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class DialogHelper {
  static OverlayEntry? _overlayEntry;
  static bool _isDialogShowing = false;

  static void showLoadingDialog(BuildContext context,
      {String message = "Đang xử lý..."}) {
    if (!_isDialogShowing && _overlayEntry == null) {
      debugPrint('🔄 DialogHelper: Showing overlay dialog with message: "$message"');
      _isDialogShowing = true;

      _overlayEntry = OverlayEntry(
        builder: (context) => Material(
          color: Colors.black54,
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Lottie.asset(
                      'assets/loading.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      );

      // Insert the overlay
      try {
        Overlay.of(context).insert(_overlayEntry!);
        debugPrint('✅ DialogHelper: Overlay dialog inserted successfully');
      } catch (e) {
        debugPrint('❌ DialogHelper: Error inserting overlay: $e');
        _cleanup();
      }
    } else {
      debugPrint('ℹ️ DialogHelper: Dialog already showing (showing: $_isDialogShowing) or overlay exists ($_overlayEntry)');
    }
  }

  static Future<void> hideLoadingDialog(BuildContext context) async {
    if (_isDialogShowing && _overlayEntry != null) {
      try {
        debugPrint('🔄 DialogHelper: Removing overlay dialog...');
        _overlayEntry?.remove();
        _cleanup();
        debugPrint('✅ DialogHelper: Overlay dialog removed successfully');

        // Small delay to ensure overlay is fully removed
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('❌ DialogHelper: Error removing overlay: $e');
        _cleanup();
      }
    } else {
      debugPrint('ℹ️ DialogHelper: No dialog to hide (showing: $_isDialogShowing, entry: $_overlayEntry)');
    }
  }

  /// Safe version of hideLoadingDialog that doesn't require context
  static Future<void> safeHideLoadingDialog() async {
    if (_isDialogShowing && _overlayEntry != null) {
      try {
        debugPrint('🔄 DialogHelper: Safely removing overlay dialog...');
        _overlayEntry?.remove();
        _cleanup();
        debugPrint('✅ DialogHelper: Overlay dialog safely removed');
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        debugPrint('❌ DialogHelper: Error safely removing overlay: $e');
        _cleanup();
      }
    } else {
      debugPrint('ℹ️ DialogHelper: No dialog to safely hide (showing: $_isDialogShowing, entry: $_overlayEntry)');
    }
  }

  static void _cleanup() {
    _overlayEntry = null;
    _isDialogShowing = false;
  }

  static bool get isDialogShowing => _isDialogShowing;

  static void forceReset() {
    try {
      _overlayEntry?.remove();
    } catch (e) {
      debugPrint('Force reset error: $e');
    } finally {
      _cleanup();
    }
  }

  /// Force close dialog if it's showing
  static void forceCloseIfShowing() {
    if (_isDialogShowing) {
      try {
        _overlayEntry?.remove();
      } catch (e) {
        debugPrint('Force close overlay error: $e');
      } finally {
        _cleanup();
      }
    }
  }
}
