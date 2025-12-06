import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';

class ReservationSummaryCard extends StatelessWidget {
  final double totalAmount;
  final double paymentAmount;
  final double remainingAmount;
  final bool isPayingDeposit;

  const ReservationSummaryCard({
    super.key,
    required this.totalAmount,
    required this.paymentAmount,
    required this.remainingAmount,
    required this.isPayingDeposit,
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
          children: [
            _buildRow('Tổng tiền', CurrencyHelper.formatVND(totalAmount)),
            const Divider(height: 24),
            _buildRow(
              isPayingDeposit ? l10n.depositAmount : 'Thanh toán ngay',
              CurrencyHelper.formatVND(paymentAmount),
              valueColor: primaryColor,
              valueBold: true,
            ),
            if (remainingAmount > 0) ...[
              const SizedBox(height: 8),
              _buildRow(
                l10n.remainingAmount,
                CurrencyHelper.formatVND(remainingAmount),
                valueColor: Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value,
      {Color? valueColor, bool valueBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: valueBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
