import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/data/models/notification_model.dart';
import 'package:pet_shop/data/repositories/notification_repository.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_event.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _notificationRepository;
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  Completer<void>? _listenCompleter;

  NotificationBloc({
    required NotificationRepository notificationRepository,
  })  : _notificationRepository = notificationRepository,
        super(NotificationInitial()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<LoadUnreadNotifications>(_onLoadUnreadNotifications);
    on<MarkNotificationAsRead>(_onMarkNotificationAsRead);
    on<MarkAllNotificationsAsRead>(_onMarkAllNotificationsAsRead);
    on<DeleteNotification>(_onDeleteNotification);
    on<DeleteAllNotifications>(_onDeleteAllNotifications);
    on<CreateNotification>(_onCreateNotification);
    on<CreateOrderNotification>(_onCreateOrderNotification);
    on<CreateBroadcastNotification>(_onCreateBroadcastNotification);
    on<RefreshNotifications>(_onRefreshNotifications);
    on<ListenToNotifications>(_onListenToNotifications);
    on<StopListeningToNotifications>(_onStopListeningToNotifications);
    on<LoadUnreadCount>(_onLoadUnreadCount);
  }

  @override
  Future<void> close() {
    print('🔄 NotificationBloc: Closing and cancelling subscriptions...');
    _notificationSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    
    // Complete the listen completer if still active
    if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
      _listenCompleter!.complete();
    }
    
    print('✅ NotificationBloc: Subscriptions cancelled');
    return super.close();
  }

  // Load all notifications for user
  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      print('🔄 LoadNotifications: Starting for userId: ${event.userId}');
      emit(NotificationLoading());
      print('✅ LoadNotifications: Emitted NotificationLoading');

      final notificationsStream = _notificationRepository.getUserNotifications(event.userId);
      final unreadCountStream = _notificationRepository.getUnreadCount(event.userId);

      print('🔄 LoadNotifications: Getting first data from streams...');
      // Get initial data
      final notifications = await notificationsStream.first;
      final unreadCount = await unreadCountStream.first;

      print('✅ LoadNotifications: Got ${notifications.length} notifications, $unreadCount unread');
      emit(NotificationLoaded(
        notifications: notifications,
        unreadCount: unreadCount,
      ));
      print('✅ LoadNotifications: Emitted NotificationLoaded');
    } catch (e) {
      print('❌ LoadNotifications: Error - $e');
      emit(NotificationError(message: e.toString()));
    }
  }

  // Load unread notifications
  Future<void> _onLoadUnreadNotifications(
    LoadUnreadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      emit(NotificationLoading());

      final unreadNotifications = await _notificationRepository
          .getUserNotifications(event.userId)
          .first;

      emit(UnreadNotificationsLoaded(
        unreadNotifications: unreadNotifications,
        count: unreadNotifications.length,
      ));
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  // Mark notification as read
  Future<void> _onMarkNotificationAsRead(
    MarkNotificationAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      // Store current state before making changes
      final currentState = state;
      
      await _notificationRepository.markAsRead(event.notificationId);
      emit(NotificationMarkedAsRead(event.notificationId));
      
      // Refresh current state if we're in NotificationLoaded or NotificationListening state
      if (currentState is NotificationLoaded) {
        final updatedNotifications = currentState.notifications.map((notif) {
          if (notif.id == event.notificationId) {
            return notif.copyWith(isRead: true);
          }
          return notif;
        }).toList();
        
        final newUnreadCount = updatedNotifications.where((n) => !n.isRead).length;
        
        emit(NotificationLoaded(
          notifications: updatedNotifications,
          unreadCount: newUnreadCount,
        ));
      } else if (currentState is NotificationListening) {
        final updatedNotifications = currentState.notifications.map((notif) {
          if (notif.id == event.notificationId) {
            return notif.copyWith(isRead: true);
          }
          return notif;
        }).toList();
        
        final newUnreadCount = updatedNotifications.where((n) => !n.isRead).length;
        
        emit(NotificationListening(
          notifications: updatedNotifications,
          unreadCount: newUnreadCount,
        ));
      }
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  // Mark all notifications as read
  Future<void> _onMarkAllNotificationsAsRead(
    MarkAllNotificationsAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      // Store current state before making changes
      final currentState = state;
      
      await _notificationRepository.markAllAsRead(event.userId);
      emit(AllNotificationsMarkedAsRead(event.userId));
      
      // Refresh current state if we're in NotificationLoaded or NotificationListening state
      if (currentState is NotificationLoaded) {
        final updatedNotifications = currentState.notifications
            .map((notif) => notif.copyWith(isRead: true))
            .toList();
        
        emit(NotificationLoaded(
          notifications: updatedNotifications,
          unreadCount: 0,
        ));
      } else if (currentState is NotificationListening) {
        final updatedNotifications = currentState.notifications
            .map((notif) => notif.copyWith(isRead: true))
            .toList();
        
        emit(NotificationListening(
          notifications: updatedNotifications,
          unreadCount: 0,
        ));
      }
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  // Delete notification
  Future<void> _onDeleteNotification(
    DeleteNotification event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      // Store current state before making changes
      final currentState = state;
      
      await _notificationRepository.deleteNotification(event.notificationId);
      emit(NotificationDeleted(event.notificationId));
      
      // Refresh current state if we're in NotificationLoaded or NotificationListening state
      if (currentState is NotificationLoaded) {
        final updatedNotifications = currentState.notifications
            .where((notif) => notif.id != event.notificationId)
            .toList();
        
        final newUnreadCount = updatedNotifications.where((n) => !n.isRead).length;
        
        emit(NotificationLoaded(
          notifications: updatedNotifications,
          unreadCount: newUnreadCount,
        ));
      } else if (currentState is NotificationListening) {
        final updatedNotifications = currentState.notifications
            .where((notif) => notif.id != event.notificationId)
            .toList();
        
        final newUnreadCount = updatedNotifications.where((n) => !n.isRead).length;
        
        emit(NotificationListening(
          notifications: updatedNotifications,
          unreadCount: newUnreadCount,
        ));
      }
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  // Delete all notifications
  Future<void> _onDeleteAllNotifications(
    DeleteAllNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      // Store current state before making changes
      final currentState = state;
      
      await _notificationRepository.deleteAllNotifications(event.userId);
      emit(AllNotificationsDeleted(event.userId));
      
      // Maintain the current state type but with empty data
      if (currentState is NotificationListening) {
        emit(const NotificationListening(
          notifications: [],
          unreadCount: 0,
        ));
      } else {
        emit(const NotificationLoaded(
          notifications: [],
          unreadCount: 0,
        ));
      }
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  // Create notification
  Future<void> _onCreateNotification(
    CreateNotification event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final notificationId = await _notificationRepository
          .createNotification(event.notification);
      
      emit(NotificationCreated(notificationId: notificationId));
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  // Create order notification
  Future<void> _onCreateOrderNotification(
    CreateOrderNotification event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final notificationId = await _notificationRepository.createOrderNotification(
        userId: event.userId,
        orderId: event.orderId,
        type: event.type,
        customerName: event.customerName,
      );
      
      emit(NotificationCreated(
        notificationId: notificationId,
        message: 'Thông báo đơn hàng đã được gửi thành công',
      ));
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  // Create broadcast notification
  Future<void> _onCreateBroadcastNotification(
    CreateBroadcastNotification event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final notificationIds = await _notificationRepository.createBroadcastNotification(
        title: event.title,
        content: event.content,
        type: event.type,
        userIds: event.userIds,
        data: event.data,
      );
      
      emit(BroadcastNotificationCreated(
        notificationIds: notificationIds,
        message: 'Broadcast sent to ${event.userIds.length} users',
      ));
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  // Refresh notifications
  Future<void> _onRefreshNotifications(
    RefreshNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    add(LoadNotifications(event.userId));
  }

  // Listen to real-time notifications
  Future<void> _onListenToNotifications(
    ListenToNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      print('🔄 ListenToNotifications: Starting for userId: ${event.userId}');
      print('🔄 ListenToNotifications: Current state: ${state.runtimeType}');
      
      await _notificationSubscription?.cancel();
      await _unreadCountSubscription?.cancel();
      print('✅ ListenToNotifications: Cancelled previous subscriptions');

      // Only emit loading if not already listening or loaded
      if (state is NotificationInitial || state is NotificationError) {
        print('🔄 ListenToNotifications: Emitting loading (state was ${state.runtimeType})');
        emit(NotificationLoading());
      } else {
        print('ℹ️ ListenToNotifications: Skipping loading emit (state is ${state.runtimeType})');
      }

      print('🔄 ListenToNotifications: Setting up stream listener...');
      // Create a completer to keep the event handler alive
      _listenCompleter = Completer<void>();
      
      // Listen to notifications with proper emit checking
      _notificationSubscription = _notificationRepository
          .getUserNotifications(event.userId)
          .listen(
        (notifications) async {
          print('📨 ListenToNotifications: Received ${notifications.length} notifications');
          print('🔍 ListenToNotifications: emit.isDone: ${emit.isDone}, isClosed: $isClosed');
          
          // Fix: Use different condition for emit checking
          if (!isClosed) {
            // Get unread count from notifications directly
            final unreadCount = notifications.where((n) => !n.isRead).length;
            print('📊 ListenToNotifications: $unreadCount unread notifications');
            
            try {
              emit(NotificationListening(
                notifications: notifications,
                unreadCount: unreadCount,
              ));
              print('✅ ListenToNotifications: Emitted NotificationListening successfully');
            } catch (e) {
              print('❌ ListenToNotifications: Error emitting: $e');
            }
          } else {
            print('⚠️ ListenToNotifications: Skipped emit (isClosed: $isClosed)');
          }
        },
        onError: (error) {
          print('❌ ListenToNotifications: Stream error - $error');
          if (!isClosed) {
            try {
              emit(NotificationError(message: error.toString()));
              print('✅ ListenToNotifications: Emitted NotificationError');
            } catch (e) {
              print('❌ ListenToNotifications: Error emitting error: $e');
            }
          }
        },
        onDone: () {
          print('ℹ️ ListenToNotifications: Stream completed');
          if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
            _listenCompleter!.complete();
          }
        },
      );
      print('✅ ListenToNotifications: Stream listener setup complete');
      
      // Keep the event handler alive indefinitely for real-time listening
      // Only complete when the stream is done or cancelled
      await _listenCompleter!.future;
    } catch (e) {
      print('❌ ListenToNotifications: Exception - $e');
      if (!emit.isDone && !isClosed) {
        emit(NotificationError(message: e.toString()));
        print('✅ ListenToNotifications: Emitted NotificationError for exception');
      }
    }
  }

  // Stop listening to notifications
  Future<void> _onStopListeningToNotifications(
    StopListeningToNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    print('🛑 StopListeningToNotifications: Stopping streams...');
    await _notificationSubscription?.cancel();
    await _unreadCountSubscription?.cancel();
    _notificationSubscription = null;
    _unreadCountSubscription = null;
    
    // Complete the listen completer to stop the event handler
    if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
      _listenCompleter!.complete();
      _listenCompleter = null;
    }
    
    // Don't emit any state change here to avoid interfering with other operations
    print('✅ StopListeningToNotifications: All streams stopped and nullified');
  }

  // Load unread count
  Future<void> _onLoadUnreadCount(
    LoadUnreadCount event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final unreadCount = await _notificationRepository
          .getUnreadCount(event.userId)
          .first;
      
      emit(UnreadCountLoaded(unreadCount));
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  // Helper methods for common notification types

  // Send order placed notification
  void sendOrderPlacedNotification({
    required String userId,
    required String orderId,
    String? customerName,
  }) {
    add(CreateOrderNotification(
      userId: userId,
      orderId: orderId,
      type: NotificationType.orderPlaced,
      customerName: customerName,
    ));
  }

  // Send order confirmed notification
  void sendOrderConfirmedNotification({
    required String userId,
    required String orderId,
    String? customerName,
  }) {
    add(CreateOrderNotification(
      userId: userId,
      orderId: orderId,
      type: NotificationType.orderConfirmed,
      customerName: customerName,
    ));
  }

  // Send order cancelled notification
  void sendOrderCancelledNotification({
    required String userId,
    required String orderId,
    String? customerName,
  }) {
    add(CreateOrderNotification(
      userId: userId,
      orderId: orderId,
      type: NotificationType.orderCancelled,
      customerName: customerName,
    ));
  }

  // Send order shipped notification
  void sendOrderShippedNotification({
    required String userId,
    required String orderId,
    String? customerName,
  }) {
    add(CreateOrderNotification(
      userId: userId,
      orderId: orderId,
      type: NotificationType.orderShipped,
      customerName: customerName,
    ));
  }

  // Send order delivered notification
  void sendOrderDeliveredNotification({
    required String userId,
    required String orderId,
    String? customerName,
  }) {
    add(CreateOrderNotification(
      userId: userId,
      orderId: orderId,
      type: NotificationType.orderDelivered,
      customerName: customerName,
    ));
  }

  // Send promotion notification to multiple users
  void sendPromotionNotification({
    required String title,
    required String content,
    required List<String> userIds,
    String? promoCode,
    DateTime? expiryDate,
  }) {
    add(CreateBroadcastNotification(
      title: title,
      content: content,
      type: NotificationType.promotion,
      userIds: userIds,
      data: {
        'promoCode': promoCode,
        'expiryDate': expiryDate?.toIso8601String(),
      },
    ));
  }
}