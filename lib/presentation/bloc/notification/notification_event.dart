import 'package:equatable/equatable.dart';
import 'package:pet_shop/data/models/notification_model.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

// Load notifications
class LoadNotifications extends NotificationEvent {
  final String userId;

  const LoadNotifications(this.userId);

  @override
  List<Object?> get props => [userId];
}

// Load unread notifications
class LoadUnreadNotifications extends NotificationEvent {
  final String userId;

  const LoadUnreadNotifications(this.userId);

  @override
  List<Object?> get props => [userId];
}

// Mark notification as read
class MarkNotificationAsRead extends NotificationEvent {
  final String notificationId;

  const MarkNotificationAsRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

// Mark all notifications as read
class MarkAllNotificationsAsRead extends NotificationEvent {
  final String userId;

  const MarkAllNotificationsAsRead(this.userId);

  @override
  List<Object?> get props => [userId];
}

// Delete notification
class DeleteNotification extends NotificationEvent {
  final String notificationId;

  const DeleteNotification(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

// Delete all notifications
class DeleteAllNotifications extends NotificationEvent {
  final String userId;

  const DeleteAllNotifications(this.userId);

  @override
  List<Object?> get props => [userId];
}

// Create notification (for admin/system)
class CreateNotification extends NotificationEvent {
  final NotificationModel notification;

  const CreateNotification(this.notification);

  @override
  List<Object?> get props => [notification];
}

// Create order notification
class CreateOrderNotification extends NotificationEvent {
  final String userId;
  final String orderId;
  final NotificationType type;
  final String? customerName;

  const CreateOrderNotification({
    required this.userId,
    required this.orderId,
    required this.type,
    this.customerName,
  });

  @override
  List<Object?> get props => [userId, orderId, type, customerName];
}

// Create broadcast notification
class CreateBroadcastNotification extends NotificationEvent {
  final String title;
  final String content;
  final NotificationType type;
  final List<String> userIds;
  final Map<String, dynamic>? data;

  const CreateBroadcastNotification({
    required this.title,
    required this.content,
    required this.type,
    required this.userIds,
    this.data,
  });

  @override
  List<Object?> get props => [title, content, type, userIds, data];
}

// Refresh notifications
class RefreshNotifications extends NotificationEvent {
  final String userId;

  const RefreshNotifications(this.userId);

  @override
  List<Object?> get props => [userId];
}

// Listen to notification updates (real-time)
class ListenToNotifications extends NotificationEvent {
  final String userId;

  const ListenToNotifications(this.userId);

  @override
  List<Object?> get props => [userId];
}

// Stop listening to notifications
class StopListeningToNotifications extends NotificationEvent {}

// Get unread count
class LoadUnreadCount extends NotificationEvent {
  final String userId;

  const LoadUnreadCount(this.userId);

  @override
  List<Object?> get props => [userId];
}