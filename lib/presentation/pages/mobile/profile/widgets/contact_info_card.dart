import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class ContactInfoCard extends StatelessWidget {
  final String? currentEmail;
  final String? currentPhone;
  final VoidCallback onChangeEmail;
  final VoidCallback onChangePhone;

  const ContactInfoCard({
    super.key,
    required this.currentEmail,
    required this.currentPhone,
    required this.onChangeEmail,
    required this.onChangePhone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Liên kết tài khoản',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
            ),
            const SizedBox(height: 12),
            _row(
              context,
              label: 'Email',
              value: currentEmail,
              actionLabel: currentEmail?.isNotEmpty == true ? 'Đổi email' : 'Thêm email',
              onPressed: onChangeEmail,
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 12),
            _row(
              context,
              label: 'Số điện thoại',
              value: currentPhone,
              actionLabel: currentPhone?.isNotEmpty == true ? 'Đổi số điện thoại' : 'Thêm số điện thoại',
              onPressed: onChangePhone,
              icon: Icons.phone_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String? value,
    required String actionLabel,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: ListTile(
        leading: Icon(icon, color: primaryColor),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          hasValue ? value : 'Chưa liên kết',
          style: TextStyle(
            color: hasValue ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
        trailing: IconButton(
          tooltip: actionLabel,
          onPressed: onPressed,
          icon: Icon(
            hasValue ? Icons.edit_outlined : Icons.add_circle_outline,
            color: primaryColor,
          ),
        ),
      ),
    );
  }
}
