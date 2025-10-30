import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class SaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onPressed;

  const SaveButton({super.key, required this.isSaving, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor, 
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : const Text('Lưu thay đổi'),
      ),
    );
  }
}
