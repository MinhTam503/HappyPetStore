import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/pet_colors.dart';

/// Widget hiển thị một dòng thông tin thú cưng với icon và text
class PetInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const PetInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget hiển thị một dòng thông tin màu sắc với color preview
class PetInfoRowWithColor extends StatelessWidget {
  final IconData icon;
  final String title;
  final String colorKey;

  const PetInfoRowWithColor({
    super.key,
    required this.icon,
    required this.title,
    required this.colorKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: PetColors.getColorFromKey(colorKey),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              PetColors.getLocalizedColor(l10n, colorKey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
