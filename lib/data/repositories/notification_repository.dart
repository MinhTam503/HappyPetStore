import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/data/models/notification_model.dart';

/// Repository để quản lý thông báo với Firestore
class NotificationRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'notifications';

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Tạo thông báo mới
  Future<String> createNotification(NotificationModel notification) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final notificationWithId = notification.copyWith(id: docRef.id);
      
      await docRef.set(notificationWithId.toMap());
      print('✅ Notification created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating notification: $e');
      throw Exception('Failed to create notification: $e');
    }
  }

  // Tạo nhiều thông báo cùng lúc (broadcast)
  Future<List<String>> createBroadcastNotification({
    required String title,
    required String content,
    required NotificationType type,
    required List<String> userIds,
    Map<String, dynamic>? data,
  }) async {
    try {
      final batch = _firestore.batch();
      final notificationIds = <String>[];
      final now = DateTime.now();

      for (String userId in userIds) {
        final docRef = _firestore.collection(_collection).doc();
        final notification = NotificationModel(
          id: docRef.id,
          userId: userId,
          title: title,
          content: content,
          type: type,
          createdAt: now,
          data: data,
        );

        batch.set(docRef, notification.toMap());
        notificationIds.add(docRef.id);
      }

      await batch.commit();
      print('✅ Broadcast notification created for ${userIds.length} users');
      return notificationIds;
    } catch (e) {
      print('❌ Error creating broadcast notification: $e');
      throw Exception('Failed to create broadcast notification: $e');
    }
  }

  // Lấy danh sách thông báo của user (real-time) - NO INDEX REQUIRED
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    try {
      print('🔄 Repository: getUserNotifications for userId: $userId');
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
            print('📨 Repository: Received snapshot with ${snapshot.docs.length} docs');
            final notifications = snapshot.docs
                .map((doc) {
                  try {
                    return NotificationModel.fromDocument(doc);
                  } catch (e) {
                    print('❌ Repository: Error parsing document ${doc.id}: $e');
                    return null;
                  }
                })
                .where((notification) => notification != null)
                .cast<NotificationModel>()
                .toList();
            
            print('✅ Repository: Parsed ${notifications.length} valid notifications');
            // Sort in memory to avoid Firestore index requirement
            notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            print('✅ Repository: Notifications sorted by createdAt');
            return notifications;
          });
    } catch (e) {
      print('❌ Repository: Error getting user notifications: $e');
      throw Exception('Failed to get notifications: $e');
    }
  }

  // Lấy số lượng thông báo chưa đọc
  Stream<int> getUnreadCount(String userId) {
    try {
      print('🔄 Repository: getUnreadCount for userId: $userId');
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            final count = snapshot.docs.length;
            print('📊 Repository: Found $count unread notifications');
            return count;
          });
    } catch (e) {
      print('❌ Repository: Error getting unread count: $e');
      throw Exception('Failed to get unread count: $e');
    }
  }

  // Đánh dấu thông báo đã đọc
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(notificationId)
          .update({'isRead': true});
      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // Đánh dấu tất cả thông báo của user đã đọc
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('✅ All notifications marked as read for user: $userId');
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  // Xóa thông báo
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).delete();
      print('✅ Notification deleted: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
      throw Exception('Failed to delete notification: $e');
    }
  }

  // Xóa tất cả thông báo của user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final userNotifications = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in userNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ All notifications deleted for user: $userId');
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
      throw Exception('Failed to delete all notifications: $e');
    }
  }

  // Tạo thông báo đơn hàng
  Future<String> createOrderNotification({
    required String userId,
    required String orderId,
    required NotificationType type,
    String? customerName,
  }) async {
    try {
      String title, content;
      
      switch (type) {
        case NotificationType.orderPlaced:
          title = 'Đơn hàng đã được đặt';
          content = 'Đơn hàng #$orderId đã được đặt thành công. Chúng tôi sẽ xử lý đơn hàng của bạn sớm nhất có thể.';
          break;
        case NotificationType.orderConfirmed:
          title = 'Đơn hàng đã được xác nhận';
          content = 'Đơn hàng #$orderId đã được xác nhận và đang được chuẩn bị.';
          break;
        case NotificationType.orderShipped:
          title = 'Đơn hàng đang được giao';
          content = 'Đơn hàng #$orderId đang trên đường giao đến bạn.';
          break;
        case NotificationType.orderDelivered:
          title = 'Đơn hàng đã giao thành công';
          content = 'Đơn hàng #$orderId đã được giao thành công. Cảm ơn bạn đã tin tưởng!';
          break;
        case NotificationType.orderCancelled:
          title = 'Đơn hàng đã bị hủy';
          content = 'Đơn hàng #$orderId đã bị hủy.';
          break;
        default:
          title = 'Cập nhật đơn hàng';
          content = 'Đơn hàng #$orderId có cập nhật mới.';
      }

      final notification = NotificationModel(
        id: '',
        userId: userId,
        title: title,
        content: content,
        type: type,
        createdAt: DateTime.now(),
        data: {
          'orderId': orderId,
          'customerName': customerName,
        },
      );

      return await createNotification(notification);
    } catch (e) {
      print('❌ Error creating order notification: $e');
      throw Exception('Failed to create order notification: $e');
    }
  }

  // Get unread notifications for a user (required by BLoC)
  Stream<List<NotificationModel>> getUnreadNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data()))
          .toList();
      
      // Sort by creation time (newest first) in memory
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return notifications;
    });
  }

  // Delete all notifications for a user (required by BLoC)
  Future<void> deleteAllUserNotifications(String userId) async {
    try {
      print('🗑️ Deleting all notifications for user: $userId');
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        print('ℹ️ No notifications found to delete for user: $userId');
        return;
      }

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ Deleted ${snapshot.docs.length} notifications for user: $userId');
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
      throw Exception('Failed to delete all notifications: $e');
    }
  }
}