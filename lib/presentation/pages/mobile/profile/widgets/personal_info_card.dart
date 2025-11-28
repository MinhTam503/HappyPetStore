import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
// Phone/Email verify rows moved to ContactInfoCard

class PersonalInfoCard extends StatelessWidget {
  final TextEditingController displayNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final DateTime? selectedBirthDate;
  final VoidCallback onSelectBirthDate;
  final String? selectedGender;
  final ValueChanged<String?> onGenderChanged;
  // Contact details and verification UI have been moved out to ContactInfoCard

  const PersonalInfoCard({
    super.key,
    required this.displayNameController,
    required this.phoneController,
    required this.emailController,
    required this.selectedBirthDate,
    required this.onSelectBirthDate,
    required this.selectedGender,
    required this.onGenderChanged,
  });

  InputDecoration _inputDecorationWithIcon(BuildContext context,
      {required String label, required IconData icon}) {
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary, width: 1.6),
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
              style:
                  TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: displayNameController,
              decoration: _inputDecorationWithIcon(
                context,
                label: 'Tên hiển thị',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 12),
            // Phone/Email inputs moved to ContactInfoCard
            const SizedBox(height: 8),
            InkWell(
              onTap: onSelectBirthDate,
              child: InputDecorator(
                decoration: _inputDecorationWithIcon(
                  context,
                  label: 'Ngày sinh',
                  icon: Icons.cake_outlined,
                ),
                child: Text(
                  selectedBirthDate != null
                      ? DateFormat('dd/MM/yyyy').format(selectedBirthDate!)
                      : 'Chưa chọn ngày sinh',
                  style: TextStyle(
                    color: selectedBirthDate != null
                        ? Colors.black
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedGender,
              decoration: _inputDecorationWithIcon(
                context,
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
