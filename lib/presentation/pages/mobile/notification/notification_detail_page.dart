import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_shop/data/models/notification_model.dart';

class NotificationDetailPage extends StatelessWidget {
  final NotificationModel notification;
  const NotificationDetailPage({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final createdAt = notification.createdAt;
    final formattedDate = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('Chi tiết thông báo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card with icon, title and date
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.primaryContainer,
                      Color.alphaBlend(color.primary.withOpacity(0.08), color.surface),
                    ],
                  ),
                  border: Border.all(color: color.outlineVariant.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.onPrimaryContainer.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: color.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: color.onPrimaryContainer,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 14, color: color.onPrimaryContainer.withOpacity(0.8)),
                                  const SizedBox(width: 6),
                                  Text(
                                    formattedDate,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: color.onPrimaryContainer.withOpacity(0.85),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: color.primary.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Thông báo',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: color.primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content card
              Card(
                elevation: 0,
                color: color.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: color.outlineVariant.withOpacity(0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nội dung',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.content,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: notification.content));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Đã sao chép nội dung'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: color.primary,
                                  ),
                                );
                              }
                            },
                            icon: Icon(Icons.copy_rounded, color: color.primary),
                            label: Text('Sao chép', style: TextStyle(color: color.primary)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: color.primary.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (notification.data != null && notification.data!.isNotEmpty)
                _DataPreview(data: notification.data!),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataPreview extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DataPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: color.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.outlineVariant.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin thêm',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            ...data.entries.map(
              (e) => Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: color.outlineVariant.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
                      child: Text(
                        e.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: color.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        '${e.value}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
