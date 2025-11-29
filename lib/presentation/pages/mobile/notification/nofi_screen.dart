import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/data/models/notification_model.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_bloc.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_event.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_state.dart';
import 'package:pet_shop/presentation/pages/mobile/notification/notification_detail_page.dart';
import 'package:pet_shop/presentation/pages/mobile/order/your_order_screen.dart';

class NofiScreen extends StatefulWidget {
  final String userId;

  const NofiScreen({
    super.key,
    required this.userId,
  });

  @override
  State<NofiScreen> createState() => _NofiScreenState();
}

class _NofiScreenState extends State<NofiScreen> {
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    if (_isInitializing) {
      print('⚠️ NofiScreen: Already initializing, skipping');
      return;
    }

    print(
        '🔄 NofiScreen: Starting initialization for userId: ${widget.userId}');
    setState(() {
      _isInitializing = true;
    });

    // Start listening to real-time notifications with delay to avoid context issues
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        print('🔄 NofiScreen: Post frame callback executing');
        // Show loading dialog during initialization
        DialogHelper.showLoadingDialog(context,
            message: 'Đang tải thông báo...');
        print('✅ NofiScreen: Loading dialog shown');

        try {
          context
              .read<NotificationBloc>()
              .add(ListenToNotifications(widget.userId));
          print('✅ NofiScreen: ListenToNotifications event added');

          // Timeout protection - force hide loading after 3 seconds
          await Future.any([
            Future.delayed(const Duration(milliseconds: 800)),
            Future.delayed(const Duration(seconds: 3)), // Max timeout
          ]);

          if (mounted && _isInitializing) {
            print('⏰ NofiScreen: Timeout reached, hiding loading dialog');
            DialogHelper.hideLoadingDialog(context);
            setState(() {
              _isInitializing = false;
            });
          }
        } catch (e) {
          print('❌ NofiScreen: Error during initialization: $e');
          if (mounted) {
            DialogHelper.hideLoadingDialog(context);
            setState(() {
              _isInitializing = false;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    // Mark all notifications as read when leaving the screen
    if (mounted) {
      context
          .read<NotificationBloc>()
          .add(MarkAllNotificationsAsRead(widget.userId));
      context.read<NotificationBloc>().add(StopListeningToNotifications());
    }

    // Force close any remaining dialogs
    DialogHelper.forceCloseIfShowing();

    super.dispose();
  }

  // Get icon for notification type
  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.orderPlaced:
      case NotificationType.orderConfirmed:
      case NotificationType.orderShipped:
      case NotificationType.orderDelivered:
        return Icons.shopping_bag;
      case NotificationType.orderCancelled:
        return Icons.cancel;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.appointment:
        return Icons.calendar_today;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  // Get color for notification type
  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.orderPlaced:
        return Colors.blue;
      case NotificationType.orderConfirmed:
        return Colors.green;
      case NotificationType.orderShipped:
        return Colors.orange;
      case NotificationType.orderDelivered:
        return Colors.green;
      case NotificationType.orderCancelled:
        return Colors.red;
      case NotificationType.promotion:
        return Colors.purple;
      case NotificationType.appointment:
        return primaryColor;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  // Format time ago
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        centerTitle: true,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)?.notificationTitle ?? 'Thông báo',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Mark all as read button
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              final hasUnread =
                  state is NotificationListening && state.unreadCount > 0;

              return IconButton(
                icon: Icon(
                  Icons.mark_email_read,
                  color: hasUnread ? Theme.of(context)
                                    .colorScheme.primary : Colors.grey,
                ),
                onPressed: hasUnread
                    ? () {
                        context.read<NotificationBloc>().add(
                              MarkAllNotificationsAsRead(widget.userId),
                            );
                      }
                    : null,
                tooltip: 'Đánh dấu tất cả đã đọc',
              );
            },
          ),
          // Delete all button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              _showDeleteAllDialog();
            },
            tooltip: 'Xóa tất cả',
          ),
        
        ],
      ),
      body: BlocConsumer<NotificationBloc, NotificationState>(
        listener: (context, state) {
          print('NofiScreen: BLoC state changed to ${state.runtimeType}');

          // Hide loading dialog when data arrives OR when error occurs
          if (state is NotificationListening ||
              state is NotificationLoaded ||
              state is NotificationError) {
            if (_isInitializing) {
              print(
                  '✅ NofiScreen: Data received, hiding loading dialog and stopping initialization');
              DialogHelper.safeHideLoadingDialog();
              if (mounted) {
                setState(() {
                  _isInitializing = false;
                });
              }
            }
          }

          if (state is NotificationError) {
            print('NofiScreen: Error state received: ${state.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is AllNotificationsMarkedAsRead) {
            print('✅ NofiScreen: All notifications marked as read');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is AllNotificationsDeleted) {
            print('✅ NofiScreen: All notifications deleted');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã xóa tất cả thông báo'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          print(
              '🔄 NofiScreen: Building UI with state: ${state.runtimeType}, _isInitializing: $_isInitializing');

          // Show empty state immediately if initializing with DialogHelper
          if (state is NotificationLoading && _isInitializing) {
            print(
                'ℹ️ NofiScreen: Showing empty state during initialization (DialogHelper active)');
            return const SizedBox
                .shrink(); // Don't show anything, DialogHelper handles loading
          }

          // Only show CircularProgressIndicator for non-initialization loading
          if (state is NotificationLoading && !_isInitializing) {
            print(
                '🔄 NofiScreen: Showing CircularProgressIndicator (not initializing)');
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NotificationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Có lỗi xảy ra',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<NotificationBloc>().add(
                            ListenToNotifications(widget.userId),
                          );
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          List<NotificationModel> notifications = [];
          int unreadCount = 0;

          if (state is NotificationListening) {
            notifications = state.notifications;
            unreadCount = state.unreadCount;
            print(
                '📊 NofiScreen: NotificationListening - ${notifications.length} notifications, $unreadCount unread');
          } else if (state is NotificationLoaded) {
            notifications = state.notifications;
            unreadCount = state.unreadCount;
            print(
                '📊 NofiScreen: NotificationLoaded - ${notifications.length} notifications, $unreadCount unread');
          }

          if (notifications.isEmpty) {
            print(
                '📭 NofiScreen: No notifications to display, showing empty state');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không có thông báo nào',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Các thông báo sẽ xuất hiện ở đây',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          print(
              '📱 NofiScreen: Rendering notification list with ${notifications.length} items');
          return Column(
            children: [
              // Unread count header
              if (unreadCount > 0)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: primaryColor.withOpacity(0.1),
                  child: Text(
                    'Bạn có $unreadCount thông báo chưa đọc',
                    style: TextStyle(
                      color: Theme.of(context)
                                    .colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // Notifications list
              Expanded(
                child: ListView.builder(
                  itemCount: notifications.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];

                    return Dismissible(
                      key: Key(notification.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        context.read<NotificationBloc>().add(
                              DeleteNotification(notification.id),
                            );
                      },
                      child: Card(
                        elevation: notification.isRead ? 1 : 3,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: notification.isRead ? null : Colors.blue.shade50,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _getNotificationColor(notification.type)
                                    .withOpacity(0.2),
                            child: Icon(
                              _getNotificationIcon(notification.type),
                              color: _getNotificationColor(notification.type),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontWeight: notification.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                    .colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                notification.content,
                                style: TextStyle(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimeAgo(notification.createdAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          onTap: () {
                            // Mark as read when tapped
                            if (!notification.isRead) {
                              context.read<NotificationBloc>().add(
                                    MarkNotificationAsRead(notification.id),
                                  );
                            }

                            // Handle notification tap based on type
                            _handleNotificationTap(notification);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả thông báo'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa tất cả thông báo? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NotificationBloc>().add(
                    DeleteAllNotifications(widget.userId),
                  );
            },
            child: const Text(
              'Xóa tất cả',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showDebugOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧪 Debug UI Tests'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Test Mark As Read'),
              subtitle: const Text(
                  'Test UI update when marking notification as read'),
              onTap: () {
                Navigator.pop(context);
                _testMarkAsRead();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Test Delete'),
              subtitle: const Text('Test UI update when deleting notification'),
              onTap: () {
                Navigator.pop(context);
                _testDelete();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Log Current State'),
              subtitle: const Text('Print current BLoC state to console'),
              onTap: () {
                Navigator.pop(context);
                _logCurrentState();
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Test State Flow'),
              subtitle: const Text('Monitor complete state transition flow'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Validate UI'),
              subtitle: const Text('Check UI stability and correctness'),
              onTap: () {
                Navigator.pop(context);
                _validateUI();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _testMarkAsRead() {
    final bloc = context.read<NotificationBloc>();
    if (bloc.state is NotificationListening) {
      final state = bloc.state as NotificationListening;
      final unread = state.notifications.where((n) => !n.isRead).toList();
      if (unread.isNotEmpty) {
        print('🧪 Testing Mark As Read: ${unread.first.title}');
        bloc.add(MarkNotificationAsRead(unread.first.id));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No unread notifications to test with')),
        );
      }
    }
  }

  void _testDelete() {
    final bloc = context.read<NotificationBloc>();
    if (bloc.state is NotificationListening) {
      final state = bloc.state as NotificationListening;
      if (state.notifications.isNotEmpty) {
        print('🧪 Testing Delete: ${state.notifications.first.title}');
        bloc.add(DeleteNotification(state.notifications.first.id));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No notifications to test with')),
        );
      }
    }
  }

  void _logCurrentState() {
    final bloc = context.read<NotificationBloc>();
    final state = bloc.state;
    print('🔍 Current State: ${state.runtimeType}');

    if (state is NotificationListening) {
      print(
          '📊 Notifications: ${state.notifications.length}, Unread: ${state.unreadCount}');
      for (var notif in state.notifications) {
        print('  - ${notif.title} (${notif.isRead ? 'read' : 'unread'})');
      }
    } else if (state is NotificationLoaded) {
      print(
          '📊 Notifications: ${state.notifications.length}, Unread: ${state.unreadCount}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('State logged: ${state.runtimeType}')),
    );
  }

  void _validateUI() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UI validation logged - check console')),
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Handle different notification types
    switch (notification.type) {
      case NotificationType.orderPlaced:
      case NotificationType.orderConfirmed:
      case NotificationType.orderShipped:
      case NotificationType.orderDelivered:
      case NotificationType.orderCancelled:
        // Navigate to orders screen and open the specific order details
        final orderId = notification.data?['orderId']?.toString();
        if (orderId != null && orderId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => YourOrderScreen(initialOrderId: orderId),
            ),
          );
        } else {
          // Fallback: just open orders list
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const YourOrderScreen(),
            ),
          );
        }
        break;
      case NotificationType.promotion:
        // Navigate to notification detail page for admin-created content
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationDetailPage(notification: notification),
          ),
        );
        break;
      case NotificationType.appointment:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationDetailPage(notification: notification),
          ),
        );
        break;
      case NotificationType.general:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationDetailPage(notification: notification),
          ),
        );
        break;
    }
  }
}
