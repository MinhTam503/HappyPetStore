import 'package:equatable/equatable.dart';
import 'package:pet_shop/data/models/notification_model.dart';

abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

// Initial state
class NotificationInitial extends NotificationState {}

// Loading state
class NotificationLoading extends NotificationState {}

// Success states
class NotificationLoaded extends NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;

  const NotificationLoaded({
    required this.notifications,
    this.unreadCount = 0,
  });

  @override
  List<Object?> get props => [notifications, unreadCount];

  NotificationLoaded copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
  }) {
    return NotificationLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class UnreadNotificationsLoaded extends NotificationState {
  final List<NotificationModel> unreadNotifications;
  final int count;

  const UnreadNotificationsLoaded({
    required this.unreadNotifications,
    required this.count,
  });

  @override
  List<Object?> get props => [unreadNotifications, count];
}

class NotificationCreated extends NotificationState {
  final String notificationId;
  final String message;

  const NotificationCreated({
    required this.notificationId,
    this.message = 'Notification created successfully',
  });

  @override
  List<Object?> get props => [notificationId, message];
}

class BroadcastNotificationCreated extends NotificationState {
  final List<String> notificationIds;
  final String message;

  const BroadcastNotificationCreated({
    required this.notificationIds,
    this.message = 'Broadcast notification sent successfully',
  });

  @override
  List<Object?> get props => [notificationIds, message];
}

class NotificationMarkedAsRead extends NotificationState {
  final String notificationId;

  const NotificationMarkedAsRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class AllNotificationsMarkedAsRead extends NotificationState {
  final String userId;

  const AllNotificationsMarkedAsRead(this.userId);

  @override
  List<Object?> get props => [userId];
}

class NotificationDeleted extends NotificationState {
  final String notificationId;

  const NotificationDeleted(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class AllNotificationsDeleted extends NotificationState {
  final String userId;

  const AllNotificationsDeleted(this.userId);

  @override
  List<Object?> get props => [userId];
}

class UnreadCountLoaded extends NotificationState {
  final int count;

  const UnreadCountLoaded(this.count);

  @override
  List<Object?> get props => [count];
}

// Error state
class NotificationError extends NotificationState {
  final String message;
  final String? errorCode;

  const NotificationError({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}

// Listening state (for real-time updates)
class NotificationListening extends NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;

  const NotificationListening({
    required this.notifications,
    this.unreadCount = 0,
  });

  @override
  List<Object?> get props => [notifications, unreadCount];

  NotificationListening copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
  }) {
    return NotificationListening(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}