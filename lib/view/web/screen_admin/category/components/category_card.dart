import 'package:flutter/material.dart';

import '../../../../../utils/contants.dart';

class CategoryCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final int breedCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageBreeds;

  const CategoryCard({
    required this.name,
    required this.imageUrl,
    required this.breedCount,
    required this.onEdit,
    required this.onDelete,
    required this.onManageBreeds,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: secondaryColor,
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.contain, // hiển thị nguyên hình
                child: Image.network(
                  imageUrl,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                      size: 56, color: Colors.grey),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('$breedCount breeds',
                          style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                    if (v == 'breeds') onManageBreeds();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'breeds', child: Text('Manage breeds')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.more_vert),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onManageBreeds,
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Breeds'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style:
                    FilledButton.styleFrom(backgroundColor: primaryColor),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text('Edit',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}