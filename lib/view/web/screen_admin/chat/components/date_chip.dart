import 'package:flutter/material.dart';

import '../../../../../utils/contants.dart';

class DateChip extends StatelessWidget {
  final String label;

  const DateChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: secondaryColor.withOpacity(.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.black87),
        ),
      ),
    );
  }
}
