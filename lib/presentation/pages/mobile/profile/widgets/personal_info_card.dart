import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/phone_verify_row.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/email_verify_row.dart';

class PersonalInfoCard extends StatelessWidget {
  final TextEditingController displayNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final DateTime? selectedBirthDate;
  final VoidCallback onSelectBirthDate;
  final String? selectedGender;
  final ValueChanged<String?> onGenderChanged;
  final bool phoneVerified;
  final bool emailVerified;
  final VoidCallback onPhoneVerify;
  final VoidCallback onEmailSendVerify;
  final VoidCallback onEmailRefresh;

  const PersonalInfoCard({
    super.key,
    required this.displayNameController,
    required this.phoneController,
    required this.emailController,
    required this.selectedBirthDate,
    required this.onSelectBirthDate,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.phoneVerified,
    required this.emailVerified,
    required this.onPhoneVerify,
    required this.onEmailSendVerify,
    required this.onEmailRefresh,
  });

  InputDecoration _inputDecorationWithIcon({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primaryColor, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin cá nhân',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: displayNameController,
              decoration: _inputDecorationWithIcon(
                label: 'Tên hiển thị',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecorationWithIcon(
                label: 'Số điện thoại',
                icon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: 8),
            PhoneVerifyRow(phoneVerified: phoneVerified, onVerify: onPhoneVerify),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: true,
              decoration: _inputDecorationWithIcon(
                label: 'Email',
                icon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 8),
            EmailVerifyRow(
              emailVerified: emailVerified,
              onSendVerify: onEmailSendVerify,
              onRefresh: onEmailRefresh,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onSelectBirthDate,
              child: InputDecorator(
                decoration: _inputDecorationWithIcon(
                  label: 'Ngày sinh',
                  icon: Icons.cake_outlined,
                ),
                child: Text(
                  selectedBirthDate != null
                      ? DateFormat('dd/MM/yyyy').format(selectedBirthDate!)
                      : 'Chưa chọn ngày sinh',
                  style: TextStyle(
                    color: selectedBirthDate != null ? Colors.black : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedGender,
              decoration: _inputDecorationWithIcon(
                label: 'Giới tính',
                icon: Icons.person_outline,
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Nam')),
                DropdownMenuItem(value: 'female', child: Text('Nữ')),
                DropdownMenuItem(value: 'other', child: Text('Khác')),
              ],
              onChanged: onGenderChanged,
            ),
          ],
        ),
      ),
    );
  }
}
