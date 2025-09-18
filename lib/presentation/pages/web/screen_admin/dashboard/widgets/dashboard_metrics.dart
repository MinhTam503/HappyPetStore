import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';

class DashboardMetrics extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isLoading;
  
  const DashboardMetrics({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const CircularProgressIndicator();
    }
    
    return Column(
      children: [
        _buildMetricCard(
          context,
          AppLocalizations.of(context)!.totalRevenue,
          CurrencyHelper.formatVND(data['revenue'] ?? 0),
          Icons.attach_money,
          Colors.green,
          '+12.5%',
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          context,
          AppLocalizations.of(context)!.orders,
          '${data['orders'] ?? 0}',
          Icons.shopping_cart,
          Colors.blue,
          '+5.2%',
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          context,
          AppLocalizations.of(context)!.users,
          '${data['users'] ?? 0}',
          Icons.people,
          Colors.orange,
          '+8.1%',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              change,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRetry;
  
  const ErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return child; // In a real implementation, this would handle errors
  }
}
