import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/data/models/notification_model.dart';
import 'package:pet_shop/data/repositories/notification_repository.dart';

/// Service cho việc quản lý thông báo từ phía admin
/// Sử dụng cho web admin hoặc dashboard quản trị
class AdminNotificationService {
  final NotificationRepository _notificationRepository;
  final FirebaseFirestore _firestore;

  AdminNotificationService({
    NotificationRepository? notificationRepository,
    FirebaseFirestore? firestore,
  })  : _notificationRepository = notificationRepository ?? NotificationRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  // ===================== ORDER NOTIFICATIONS =====================

  /// Gửi thông báo khi đơn hàng được đặt
  Future<String> notifyOrderPlaced({
    required String userId,
    required String orderId,
    String? customerName,
    double? totalAmount,
  }) async {
    print('📱 Sending order placed notification to user: $userId, order: $orderId');
    
    return await _notificationRepository.createOrderNotification(
      userId: userId,
      orderId: orderId,
      type: NotificationType.orderPlaced,
      customerName: customerName,
    );
  }

  /// Gửi thông báo khi đơn hàng được xác nhận
  Future<String> notifyOrderConfirmed({
    required String userId,
    required String orderId,
    String? customerName,
    String? estimatedDelivery,
  }) async {
    print('📱 Sending order confirmed notification to user: $userId, order: $orderId');
    
    final notification = NotificationModel(
      id: '',
      userId: userId,
      title: 'Đơn hàng đã được xác nhận',
      content: estimatedDelivery != null
          ? 'Đơn hàng #$orderId đã được xác nhận và sẽ được giao vào $estimatedDelivery'
          : 'Đơn hàng #$orderId đã được xác nhận và đang chuẩn bị',
      type: NotificationType.orderConfirmed,
      createdAt: DateTime.now(),
      data: {
        'orderId': orderId,
        'customerName': customerName,
        'estimatedDelivery': estimatedDelivery,
      },
    );

    return await _notificationRepository.createNotification(notification);
  }

  /// Gửi thông báo khi đơn hàng bị hủy
  Future<String> notifyOrderCancelled({
    required String userId,
    required String orderId,
    String? customerName,
    String? reason,
  }) async {
    print('📱 Sending order cancelled notification to user: $userId, order: $orderId');
    
    final notification = NotificationModel(
      id: '',
      userId: userId,
      title: 'Đơn hàng đã bị hủy',
      content: reason != null
          ? 'Đơn hàng #$orderId đã bị hủy. Lý do: $reason'
          : 'Đơn hàng #$orderId đã bị hủy',
      type: NotificationType.orderCancelled,
      createdAt: DateTime.now(),
      data: {
        'orderId': orderId,
        'customerName': customerName,
        'reason': reason,
      },
    );

    return await _notificationRepository.createNotification(notification);
  }

  /// Gửi thông báo khi đơn hàng được giao
  Future<String> notifyOrderShipped({
    required String userId,
    required String orderId,
    String? customerName,
    String? trackingNumber,
    String? shippingCompany,
  }) async {
    print('📱 Sending order shipped notification to user: $userId, order: $orderId');
    
    final notification = NotificationModel(
      id: '',
      userId: userId,
      title: 'Đơn hàng đang được giao',
      content: trackingNumber != null
          ? 'Đơn hàng #$orderId đang trên đường giao đến bạn. Mã vận đơn: $trackingNumber'
          : 'Đơn hàng #$orderId đang trên đường giao đến bạn',
      type: NotificationType.orderShipped,
      createdAt: DateTime.now(),
      data: {
        'orderId': orderId,
        'customerName': customerName,
        'trackingNumber': trackingNumber,
        'shippingCompany': shippingCompany,
      },
    );

    return await _notificationRepository.createNotification(notification);
  }

  /// Gửi thông báo khi đơn hàng được giao thành công
  Future<String> notifyOrderDelivered({
    required String userId,
    required String orderId,
    String? customerName,
    DateTime? deliveredAt,
  }) async {
    print('📱 Sending order delivered notification to user: $userId, order: $orderId');
    
    final notification = NotificationModel(
      id: '',
      userId: userId,
      title: 'Đơn hàng đã giao thành công',
      content: 'Đơn hàng #$orderId đã được giao thành công. Cảm ơn bạn đã tin tưởng!',
      type: NotificationType.orderDelivered,
      createdAt: DateTime.now(),
      data: {
        'orderId': orderId,
        'customerName': customerName,
        'deliveredAt': deliveredAt?.toIso8601String(),
      },
    );

    return await _notificationRepository.createNotification(notification);
  }

  // ===================== PROMOTION NOTIFICATIONS =====================

  /// Gửi thông báo khuyến mãi cho tất cả users
  Future<List<String>> sendPromotionToAllUsers({
    required String title,
    required String content,
    String? promoCode,
    double? discountPercentage,
    DateTime? expiryDate,
  }) async {
    print('📱 Sending promotion notification to all users');
    
    // Lấy tất cả user IDs
    final userIds = await _getAllUserIds();
    
    return await _notificationRepository.createBroadcastNotification(
      title: title,
      content: content,
      type: NotificationType.promotion,
      userIds: userIds,
      data: {
        'promoCode': promoCode,
        'discountPercentage': discountPercentage,
        'expiryDate': expiryDate?.toIso8601String(),
      },
    );
  }

  /// Gửi thông báo khuyến mãi cho users cụ thể
  Future<List<String>> sendPromotionToSpecificUsers({
    required String title,
    required String content,
    required List<String> userIds,
    String? promoCode,
    double? discountPercentage,
    DateTime? expiryDate,
  }) async {
    print('📱 Sending promotion notification to ${userIds.length} specific users');
    
    return await _notificationRepository.createBroadcastNotification(
      title: title,
      content: content,
      type: NotificationType.promotion,
      userIds: userIds,
      data: {
        'promoCode': promoCode,
        'discountPercentage': discountPercentage,
        'expiryDate': expiryDate?.toIso8601String(),
      },
    );
  }

  /// Gửi thông báo khuyến mãi cho users VIP (đã mua trên X đơn hàng)
  Future<List<String>> sendPromotionToVIPUsers({
    required String title,
    required String content,
    int minOrderCount = 5,
    String? promoCode,
    double? discountPercentage,
    DateTime? expiryDate,
  }) async {
    print('📱 Sending promotion notification to VIP users (min $minOrderCount orders)');
    
    // Lấy VIP user IDs dựa trên số đơn hàng
    final vipUserIds = await _getVIPUserIds(minOrderCount);
    
    return await _notificationRepository.createBroadcastNotification(
      title: title,
      content: content,
      type: NotificationType.promotion,
      userIds: vipUserIds,
      data: {
        'promoCode': promoCode,
        'discountPercentage': discountPercentage,
        'expiryDate': expiryDate?.toIso8601String(),
        'isVIPPromo': true,
      },
    );
  }

  // ===================== APPOINTMENT NOTIFICATIONS =====================

  /// Gửi thông báo lịch hẹn
  Future<String> notifyAppointmentScheduled({
    required String userId,
    required String appointmentId,
    required DateTime appointmentDate,
    required String serviceType,
    String? petName,
  }) async {
    print('📱 Sending appointment scheduled notification to user: $userId');
    
    final notification = NotificationModel(
      id: '',
      userId: userId,
      title: 'Lịch hẹn đã được đặt',
      content: petName != null
          ? 'Lịch hẹn $serviceType cho $petName đã được đặt vào ${_formatDateTime(appointmentDate)}'
          : 'Lịch hẹn $serviceType đã được đặt vào ${_formatDateTime(appointmentDate)}',
      type: NotificationType.appointment,
      createdAt: DateTime.now(),
      data: {
        'appointmentId': appointmentId,
        'appointmentDate': appointmentDate.toIso8601String(),
        'serviceType': serviceType,
        'petName': petName,
      },
    );

    return await _notificationRepository.createNotification(notification);
  }

  /// Gửi thông báo nhắc nhở lịch hẹn (trước 1 ngày)
  Future<String> sendAppointmentReminder({
    required String userId,
    required String appointmentId,
    required DateTime appointmentDate,
    required String serviceType,
    String? petName,
  }) async {
    print('📱 Sending appointment reminder to user: $userId');
    
    final notification = NotificationModel(
      id: '',
      userId: userId,
      title: 'Nhắc nhở lịch hẹn',
      content: petName != null
          ? 'Nhắc nhở: Bạn có lịch hẹn $serviceType cho $petName vào ngày mai ${_formatDateTime(appointmentDate)}'
          : 'Nhắc nhở: Bạn có lịch hẹn $serviceType vào ngày mai ${_formatDateTime(appointmentDate)}',
      type: NotificationType.appointment,
      createdAt: DateTime.now(),
      data: {
        'appointmentId': appointmentId,
        'appointmentDate': appointmentDate.toIso8601String(),
        'serviceType': serviceType,
        'petName': petName,
        'isReminder': true,
      },
    );

    return await _notificationRepository.createNotification(notification);
  }

  // ===================== GENERAL NOTIFICATIONS =====================

  /// Gửi thông báo chung cho tất cả users
  Future<List<String>> sendGeneralNotificationToAll({
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    print('📱 Sending general notification to all users');
    
    final userIds = await _getAllUserIds();
    
    return await _notificationRepository.createBroadcastNotification(
      title: title,
      content: content,
      type: NotificationType.general,
      userIds: userIds,
      data: additionalData,
    );
  }

  /// Gửi thông báo cá nhân
  Future<String> sendPersonalNotification({
    required String userId,
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    print('📱 Sending personal notification to user: $userId');
    
    final notification = NotificationModel(
      id: '',
      userId: userId,
      title: title,
      content: content,
      type: NotificationType.general,
      createdAt: DateTime.now(),
      data: additionalData,
    );

    return await _notificationRepository.createNotification(notification);
  }

  // ===================== UTILITY METHODS =====================

  /// Lấy tất cả user IDs từ Firestore
  Future<List<String>> _getAllUserIds() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      return usersSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting all user IDs: $e');
      return [];
    }
  }

  /// Lấy VIP user IDs dựa trên số đơn hàng
  Future<List<String>> _getVIPUserIds(int minOrderCount) async {
    try {
      // Giả sử bạn có collection 'orders' với field 'userId'
      final ordersSnapshot = await _firestore.collection('orders').get();
      
      // Đếm số đơn hàng của mỗi user
      final Map<String, int> userOrderCounts = {};
      for (var doc in ordersSnapshot.docs) {
        final userId = doc.data()['userId'] as String?;
        if (userId != null) {
          userOrderCounts[userId] = (userOrderCounts[userId] ?? 0) + 1;
        }
      }
      
      // Lọc users có số đơn hàng >= minOrderCount
      return userOrderCounts.entries
          .where((entry) => entry.value >= minOrderCount)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      print('Error getting VIP user IDs: $e');
      return [];
    }
  }

  /// Format DateTime thành string dễ đọc
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} lúc ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // ===================== ANALYTICS METHODS =====================

  /// Lấy thống kê thông báo
  Future<Map<String, dynamic>> getNotificationStats() async {
    try {
      final notificationsSnapshot = await _firestore.collection('notifications').get();
      
      int total = notificationsSnapshot.docs.length;
      int unread = 0;
      Map<String, int> typeStats = {};
      
      for (var doc in notificationsSnapshot.docs) {
        final data = doc.data();
        
        // Đếm unread
        if (data['isRead'] == false) {
          unread++;
        }
        
        // Đếm theo loại
        final type = data['type'] as String? ?? 'unknown';
        typeStats[type] = (typeStats[type] ?? 0) + 1;
      }
      
      return {
        'total': total,
        'unread': unread,
        'read': total - unread,
        'typeStats': typeStats,
      };
    } catch (e) {
      print('Error getting notification stats: $e');
      return {};
    }
  }

  /// Lấy danh sách users có nhiều thông báo chưa đọc nhất
  Future<List<Map<String, dynamic>>> getUsersWithMostUnreadNotifications({int limit = 10}) async {
    try {
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      
      // Đếm thông báo chưa đọc của mỗi user
      Map<String, int> userUnreadCounts = {};
      for (var doc in notificationsSnapshot.docs) {
        final userId = doc.data()['userId'] as String?;
        if (userId != null) {
          userUnreadCounts[userId] = (userUnreadCounts[userId] ?? 0) + 1;
        }
      }
      
      // Sắp xếp và giới hạn
      final sortedUsers = userUnreadCounts.entries
          .map((entry) => {'userId': entry.key, 'unreadCount': entry.value})
          .toList()
        ..sort((a, b) => (b['unreadCount'] as int).compareTo(a['unreadCount'] as int));
      
      return sortedUsers.take(limit).toList();
    } catch (e) {
      print('Error getting users with most unread notifications: $e');
      return [];
    }
  }
}