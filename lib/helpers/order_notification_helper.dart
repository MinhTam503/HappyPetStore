import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/services/admin_notification_service.dart';

/// Helper class để tích hợp notification service vào order flow
class OrderNotificationHelper {
  static final AdminNotificationService _adminNotificationService = AdminNotificationService();

  // ===================== ORDER STATUS CHANGE NOTIFICATIONS =====================

  /// Gửi thông báo khi đơn hàng được đặt thành công
  /// Sử dụng trong orderSuccess hoặc khi tạo order mới
  static Future<void> sendOrderPlacedNotification({
    required String userId,
    required String orderId,
    String? customerName,
    double? totalAmount,
  }) async {
    try {
      await _adminNotificationService.notifyOrderPlaced(
        userId: userId,
        orderId: orderId,
        customerName: customerName,
        totalAmount: totalAmount,
      );
      print('✅ Order placed notification sent successfully');
    } catch (e) {
      print('❌ Error sending order placed notification: $e');
    }
  }

  /// Gửi thông báo khi admin xác nhận đơn hàng
  /// Sử dụng trong orders_admin.dart khi update status sang "Processing"
  static Future<void> sendOrderConfirmedNotification({
    required String userId,
    required String orderId,
    String? customerName,
    String? estimatedDelivery,
  }) async {
    try {
      await _adminNotificationService.notifyOrderConfirmed(
        userId: userId,
        orderId: orderId,
        customerName: customerName,
        estimatedDelivery: estimatedDelivery,
      );
      print('✅ Order confirmed notification sent successfully');
    } catch (e) {
      print('❌ Error sending order confirmed notification: $e');
    }
  }

  /// Gửi thông báo khi đơn hàng bị hủy
  /// Sử dụng trong orders_admin.dart khi update status sang "Cancelled"
  static Future<void> sendOrderCancelledNotification({
    required String userId,
    required String orderId,
    String? customerName,
    String? reason,
  }) async {
    try {
      await _adminNotificationService.notifyOrderCancelled(
        userId: userId,
        orderId: orderId,
        customerName: customerName,
        reason: reason,
      );
      print('✅ Order cancelled notification sent successfully');
    } catch (e) {
      print('❌ Error sending order cancelled notification: $e');
    }
  }

  /// Gửi thông báo khi đơn hàng được giao
  /// Sử dụng trong orders_admin.dart khi update status sang "Shipped"
  static Future<void> sendOrderShippedNotification({
    required String userId,
    required String orderId,
    String? customerName,
    String? trackingNumber,
    String? shippingCompany,
  }) async {
    try {
      await _adminNotificationService.notifyOrderShipped(
        userId: userId,
        orderId: orderId,
        customerName: customerName,
        trackingNumber: trackingNumber,
        shippingCompany: shippingCompany,
      );
      print('✅ Order shipped notification sent successfully');
    } catch (e) {
      print('❌ Error sending order shipped notification: $e');
    }
  }

  /// Gửi thông báo khi đơn hàng hoàn thành
  /// Sử dụng trong orders_admin.dart khi update status sang "Completed"
  static Future<void> sendOrderDeliveredNotification({
    required String userId,
    required String orderId,
    String? customerName,
    DateTime? deliveredAt,
  }) async {
    try {
      await _adminNotificationService.notifyOrderDelivered(
        userId: userId,
        orderId: orderId,
        customerName: customerName,
        deliveredAt: deliveredAt,
      );
      print('✅ Order delivered notification sent successfully');
    } catch (e) {
      print('❌ Error sending order delivered notification: $e');
    }
  }

  // ===================== AUTO NOTIFICATION BASED ON STATUS =====================

  /// Tự động gửi thông báo dựa trên status change
  /// Sử dụng trong orders_admin.dart onChangeStatus
  static Future<void> sendOrderStatusChangeNotification({
    required String userId,
    required String orderId,
    required String newStatus,
    required String oldStatus,
    String? customerName,
    String? email,
    Map<String, dynamic>? additionalData,
  }) async {
    print('📱 Sending notification for status change: $oldStatus -> $newStatus');
    
    switch (newStatus) {
      case 'Processing':
        await sendOrderConfirmedNotification(
          userId: userId,
          orderId: orderId,
          customerName: customerName,
          estimatedDelivery: additionalData?['estimatedDelivery'],
        );
        break;
      
      case 'Shipped':
        await sendOrderShippedNotification(
          userId: userId,
          orderId: orderId,
          customerName: customerName,
          trackingNumber: additionalData?['trackingNumber'],
          shippingCompany: additionalData?['shippingCompany'],
        );
        break;
      
      case 'Completed':
        await sendOrderDeliveredNotification(
          userId: userId,
          orderId: orderId,
          customerName: customerName,
          deliveredAt: DateTime.now(),
        );
        break;
      
      case 'Cancelled':
        await sendOrderCancelledNotification(
          userId: userId,
          orderId: orderId,
          customerName: customerName,
          reason: additionalData?['cancellationReason'] ?? 'Đơn hàng bị hủy bởi admin',
        );
        break;
      
      default:
        print('⚠️ No notification configured for status: $newStatus');
    }
  }

  // ===================== UTILITY METHODS =====================

  /// Lấy userId từ email trong order
  static Future<String?> getUserIdFromEmail(String email) async {
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (userSnapshot.docs.isNotEmpty) {
        return userSnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('❌ Error getting userId from email: $e');
      return null;
    }
  }

  /// Lấy thông tin customer từ email
  static Future<Map<String, dynamic>?> getCustomerInfoFromEmail(String email) async {
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (userSnapshot.docs.isNotEmpty) {
        final userData = userSnapshot.docs.first.data();
        return {
          'userId': userSnapshot.docs.first.id,
          'displayName': userData['displayName'] ?? userData['name'] ?? 'Khách hàng',
          'email': userData['email'],
          'phone': userData['phone'],
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting customer info from email: $e');
      return null;
    }
  }

  // ===================== BULK OPERATIONS =====================

  /// Gửi thông báo khuyến mãi cho tất cả khách hàng
  static Future<void> sendPromotionToAllCustomers({
    required String title,
    required String content,
    String? promoCode,
    double? discountPercentage,
    DateTime? expiryDate,
  }) async {
    try {
      await _adminNotificationService.sendPromotionToAllUsers(
        title: title,
        content: content,
        promoCode: promoCode,
        discountPercentage: discountPercentage,
        expiryDate: expiryDate,
      );
      print('✅ Promotion sent to all customers successfully');
    } catch (e) {
      print('❌ Error sending promotion to all customers: $e');
    }
  }

  /// Gửi thông báo cho khách hàng VIP
  static Future<void> sendPromotionToVIPCustomers({
    required String title,
    required String content,
    int minOrderCount = 5,
    String? promoCode,
    double? discountPercentage,
    DateTime? expiryDate,
  }) async {
    try {
      await _adminNotificationService.sendPromotionToVIPUsers(
        title: title,
        content: content,
        minOrderCount: minOrderCount,
        promoCode: promoCode,
        discountPercentage: discountPercentage,
        expiryDate: expiryDate,
      );
      print('✅ Promotion sent to VIP customers successfully');
    } catch (e) {
      print('❌ Error sending promotion to VIP customers: $e');
    }
  }

  /// Gửi thông báo chung cho tất cả users
  static Future<void> sendGeneralNotificationToAll({
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _adminNotificationService.sendGeneralNotificationToAll(
        title: title,
        content: content,
        additionalData: additionalData,
      );
      print('✅ General notification sent to all users successfully');
    } catch (e) {
      print('❌ Error sending general notification: $e');
    }
  }

  /// Gửi thông báo cá nhân cho một user
  static Future<void> sendPersonalNotification({
    required String userId,
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _adminNotificationService.sendPersonalNotification(
        userId: userId,
        title: title,
        content: content,
        additionalData: additionalData,
      );
      print('✅ Personal notification sent to user $userId successfully');
    } catch (e) {
      print('❌ Error sending personal notification: $e');
    }
  }

  // ===================== ANALYTICS =====================

  /// Lấy thống kê thông báo
  static Future<Map<String, dynamic>> getNotificationAnalytics() async {
    try {
      return await _adminNotificationService.getNotificationStats();
    } catch (e) {
      print('❌ Error getting notification analytics: $e');
      return {};
    }
  }

  /// Lấy danh sách users có nhiều thông báo chưa đọc
  static Future<List<Map<String, dynamic>>> getUsersWithMostUnreadNotifications({int limit = 10}) async {
    try {
      return await _adminNotificationService.getUsersWithMostUnreadNotifications(limit: limit);
    } catch (e) {
      print('❌ Error getting users with most unread notifications: $e');
      return [];
    }
  }
}