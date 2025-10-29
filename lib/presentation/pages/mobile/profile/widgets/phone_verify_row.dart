import 'package:flutter/material.dart';

class PhoneVerifyRow extends StatelessWidget {
  final bool phoneVerified;
  final VoidCallback onVerify;

  const PhoneVerifyRow({super.key, required this.phoneVerified, required this.onVerify});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Chip(
          label: Text(phoneVerified ? 'Đã xác minh SĐT' : 'Chưa xác minh SĐT'),
          backgroundColor: phoneVerified ? Colors.green.shade100 : Colors.orange.shade100,
        ),
        const Spacer(),
        if (!phoneVerified)
          TextButton(
            onPressed: onVerify,
            child: const Text('Xác minh ngay'),
          ),
      ],
    );
  }
}
