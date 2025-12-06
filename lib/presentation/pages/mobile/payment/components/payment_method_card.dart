import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class PaymentMethodCard extends StatelessWidget {
  final String selectedMethod;
  final ValueChanged<String> onChanged;

  const PaymentMethodCard({
    super.key,
    required this.selectedMethod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phương thức thanh toán',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            RadioListTile<String>(
              value: 'vnpay',
              groupValue: selectedMethod,
              onChanged: (val) => onChanged(val ?? 'vnpay'),
              title: const Text('VNPay'),
              subtitle: const Text('Thanh toán qua VNPay'),
              activeColor: primaryColor,
            ),
            RadioListTile<String>(
              value: 'stripe',
              groupValue: selectedMethod,
              onChanged: (val) => onChanged(val ?? 'vnpay'),
              title: const Text('Stripe'),
              subtitle: const Text('Thanh toán bằng thẻ quốc tế'),
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
