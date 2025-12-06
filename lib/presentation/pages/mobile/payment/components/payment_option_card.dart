import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';

class PaymentOptionCard extends StatelessWidget {
  final bool isPayingDeposit;
  final double depositAmount;
  final double totalAmount;
  final int depositPercentage;
  final ValueChanged<bool> onChanged;

  const PaymentOptionCard({
    super.key,
    required this.isPayingDeposit,
    required this.depositAmount,
    required this.totalAmount,
    required this.depositPercentage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.paymentOption,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            RadioListTile<bool>(
              value: true,
              groupValue: isPayingDeposit,
              onChanged: (val) => onChanged(val ?? true),
              title: Text(
                l10n.payDeposit(depositPercentage),
              ),
              subtitle: Text(
                CurrencyHelper.formatVND(depositAmount),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              activeColor: primaryColor,
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: isPayingDeposit,
              onChanged: (val) => onChanged(val ?? true),
              title: Text(l10n.payFull),
              subtitle: Text(
                CurrencyHelper.formatVND(totalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
