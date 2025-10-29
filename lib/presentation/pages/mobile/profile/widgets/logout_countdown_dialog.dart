import 'dart:async';
import 'package:flutter/material.dart';

Future<void> showLogoutCountdownDialog(
  BuildContext context, {
  required int seconds,
  String? reason,
  required VoidCallback onLogoutNow,
}) async {
  int remaining = seconds;
  Timer? timer;

  void closeAndLogout() {
    timer?.cancel();
    timer = null;
    Navigator.of(context).pop();
    onLogoutNow();
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setStateDialog) {
        timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
          if (remaining <= 1) {
            t.cancel();
            timer = null;
            closeAndLogout();
          } else {
            setStateDialog(() => remaining--);
          }
        });

        return AlertDialog(
          title: const Text('Phiên đăng nhập đã hết hạn'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email của bạn đã được xác minh. Ứng dụng sẽ đăng xuất để đồng bộ lại tài khoản.',
              ),
              const SizedBox(height: 8),
              if (reason != null) ...[
                Text(
                  'Chi tiết: $reason',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
              ],
              Text('Tự động chuyển đến màn hình đăng nhập sau $remaining giây...'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: closeAndLogout,
              child: const Text('Đăng nhập ngay'),
            ),
          ],
        );
      });
    },
  ).whenComplete(() {
    timer?.cancel();
    timer = null;
  });
}
