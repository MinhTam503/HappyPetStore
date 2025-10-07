import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class OrderCard extends StatelessWidget {
  final String orderId;
  final String email;
  final String total;
  final String? subtotal;
  final String? shippingFee;
  final String status;
  final String address;
  final dynamic createdAt;
  final Color statusColor;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String?) onChangeStatus;
  final List<String> allStatuses;

  const OrderCard({
    required this.orderId,
    required this.email,
    required this.total,
    this.subtotal,
    this.shippingFee,
    required this.status,
    required this.address,
    required this.createdAt,
    required this.statusColor,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onChangeStatus,
    required this.allStatuses,
  });

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  String _getLocalizedStatus(BuildContext context, String rawStatus) {
    final l10n = AppLocalizations.of(context)!;
    switch (rawStatus) {
      case 'Pending':
        return l10n.pending;
      case 'Processing':
        return l10n.processing;
      case 'Completed':
        return l10n.completed;
      case 'Cancelled':
        return l10n.cancelled;
      default:
        return rawStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: ID + email + total (compact)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order: $orderId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 1),
                        Text(email,
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Compact shipping breakdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (shippingFee != null && double.tryParse(shippingFee!) != null && double.tryParse(shippingFee!)! > 0) ...[
                        Text(
                          'Hàng: ${CurrencyHelper.formatVND(subtotal ?? "0")}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        Text(
                          'Ship: ${CurrencyHelper.formatVND(shippingFee!)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ],
                      Text(CurrencyHelper.formatVND(total),
                          style: const TextStyle(
                              color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Row 2: Address and date (compact)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54, fontSize: 11),
                    )
                  ),
                  const SizedBox(width: 8),
                  Text(_formatDate(createdAt),
                      style: const TextStyle(color: Colors.black54, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),

              // Row 3: Status + Actions (compact)
              Row(
                children: [
                  // Status chip (compact)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: statusColor),
                        const SizedBox(width: 4),
                        Text(_getLocalizedStatus(context, status), 
                             style: TextStyle(color: statusColor, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  
                  // Compact dropdown and actions
                  SizedBox(
                    height: 30,
                    child: DropdownButton<String>(
                      value: status,
                      underline: Container(),
                      isDense: true,
                      style: const TextStyle(fontSize: 11),
                      items: allStatuses
                          .map((s) => DropdownMenuItem(
                              value: s, 
                              child: Text(_getLocalizedStatus(context, s), style: const TextStyle(fontSize: 11))
                          ))
                          .toList(),
                      onChanged: onChangeStatus,
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.edit, color: Colors.blue, size: 16),
                        onPressed: onEdit),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                        onPressed: onDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}