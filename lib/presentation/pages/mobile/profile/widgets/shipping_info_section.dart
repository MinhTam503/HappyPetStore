import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/section_title.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/delivery_info_tile.dart';

class ShippingInfoSection extends StatelessWidget {
  final List<Map<String, dynamic>> deliveryInfos;
  final VoidCallback onEditPressed;
  final void Function(int) onDeleteAt;
  final void Function(int) onSetDefaultAt;

  const ShippingInfoSection({
    super.key,
    required this.deliveryInfos,
    required this.onEditPressed,
    required this.onDeleteAt,
    required this.onSetDefaultAt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: 'Thông tin giao hàng'),
            ElevatedButton.icon(
              onPressed: onEditPressed,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Chỉnh sửa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                textStyle: const TextStyle(fontSize: 14),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (deliveryInfos.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.black54),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chưa có thông tin giao hàng nào',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: deliveryInfos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => DeliveryInfoTile(
              deliveryInfo: deliveryInfos[index],
              onDelete: () => onDeleteAt(index),
              onSetDefault: () => onSetDefaultAt(index),
            ),
          ),
      ],
    );
  }
}
