import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../utils/contants.dart';

class OrderCard extends StatelessWidget {
  final String orderId;
  final String email;
  final String total;
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: ID + email + total
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order: $orderId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(email,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('\$$total',
                      style: const TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      )),
                  const SizedBox(width: 8),
                  Text(_formatDate(createdAt),
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),

              // Row 2: status chip + address + date + actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: statusColor),
                        const SizedBox(width: 6),
                        Text(status, style: TextStyle(color: statusColor)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: status,
                    underline: Container(),
                    items: allStatuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: onChangeStatus,
                  ),
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: onEdit),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}