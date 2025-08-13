import 'package:flutter/material.dart';

import '../../../../../utils/contants.dart';

class EmptyState extends StatelessWidget {
  const EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets_outlined,
              size: 64, color: primaryColor.withOpacity(.6)),
          const SizedBox(height: 8),
          const Text('No pets available'),
        ],
      ),
    );
  }
}