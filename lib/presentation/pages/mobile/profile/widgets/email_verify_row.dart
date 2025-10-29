import 'package:flutter/material.dart';

class EmailVerifyRow extends StatelessWidget {
  final bool emailVerified;
  final VoidCallback onSendVerify;
  final VoidCallback onRefresh;

  const EmailVerifyRow({
    super.key,
    required this.emailVerified,
    required this.onSendVerify,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Chip(
          label: Text(emailVerified ? 'Đã xác minh email' : 'Chưa xác minh email'),
          backgroundColor: emailVerified ? Colors.green.shade100 : Colors.orange.shade100,
        ),
        const Spacer(),
        if (!emailVerified)
          TextButton(
            onPressed: onSendVerify,
            child: const Text('Gửi xác minh'),
          ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}
