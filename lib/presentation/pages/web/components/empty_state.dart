import 'package:flutter/material.dart';

import 'package:pet_shop/core/constants/app_constants.dart';

class EmptyState extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.label,
    this.icon = Icons.info_outline,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: (iconColor ?? primaryColor).withOpacity(.6),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
