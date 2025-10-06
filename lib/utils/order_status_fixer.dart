import 'package:cloud_firestore/cloud_firestore.dart';

/// 🔧 Utility để sửa order status dựa trên shipping status
/// Chạy một lần để fix data hiện tại
class OrderStatusFixer {
  
  /// Sửa tất cả orders có shipping status = delivered nhưng order status != Completed
  static Future<void> fixDeliveredOrders() async {
    print('🔧 Starting to fix delivered orders...');
    
    try {
      // Check mobile orders
      await _fixOrdersInCollection('orders');
      
      // Check web orders
      await _fixOrdersInCollection('ordersWeb');
      
      print('✅ Finished fixing orders');
    } catch (e) {
      print('❌ Error fixing orders: $e');
    }
  }
  
  static Future<void> _fixOrdersInCollection(String collectionName) async {
    print('🔍 Checking $collectionName collection...');
    
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .get();
    
    int fixedCount = 0;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final shippingInfo = data['shippingInfo'];
      final currentOrderStatus = data['statusOrder'];
      
      if (shippingInfo != null && shippingInfo is Map<String, dynamic>) {
        final shippingStatus = shippingInfo['status'];
        
        // Fix delivered orders
        if (shippingStatus == 'delivered' && currentOrderStatus != 'Completed') {
          await doc.reference.update({
            'statusOrder': 'Completed',
            'statusPayment': 'Payment Completed',
          });
          
          print('✅ Fixed order ${doc.id}: $currentOrderStatus → Completed');
          fixedCount++;
        }
        
        // Fix failed/returned orders
        else if ((shippingStatus == 'failed' || shippingStatus == 'returned') 
                 && currentOrderStatus != 'Cancelled') {
          await doc.reference.update({
            'statusOrder': 'Cancelled',
          });
          
          print('✅ Fixed order ${doc.id}: $currentOrderStatus → Cancelled');
          fixedCount++;
        }
      }
    }
    
    print('📊 Fixed $fixedCount orders in $collectionName');
  }
  
  /// Thêm customerPhone vào shipping info nếu thiếu
  static Future<void> addCustomerPhoneToShippingInfo() async {
    print('📞 Adding customer phone to shipping info...');
    
    try {
      // Check mobile orders
      await _addPhoneToCollection('orders');
      
      // Check web orders
      await _addPhoneToCollection('ordersWeb');
      
      print('✅ Finished adding customer phone');
    } catch (e) {
      print('❌ Error adding customer phone: $e');
    }
  }
  
  static Future<void> _addPhoneToCollection(String collectionName) async {
    print('📞 Checking $collectionName collection for missing customer phone...');
    
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .get();
    
    int updatedCount = 0;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final shippingInfo = data['shippingInfo'];
      
      if (shippingInfo != null && shippingInfo is Map<String, dynamic>) {
        // Nếu chưa có customerPhone trong shipping info
        if (shippingInfo['customerPhone'] == null || 
            shippingInfo['customerPhone'].toString().isEmpty) {
          
          String customerPhone = '';
          
          // Tìm số điện thoại từ deliveryInfo
          if (data['deliveryInfo'] != null && data['deliveryInfo']['phone'] != null) {
            customerPhone = data['deliveryInfo']['phone'].toString();
          }
          // Hoặc từ phone field cũ
          else if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
            customerPhone = data['phone'].toString();
          }
          
          // Cập nhật nếu tìm thấy số điện thoại
          if (customerPhone.isNotEmpty) {
            final updatedShippingInfo = Map<String, dynamic>.from(shippingInfo);
            updatedShippingInfo['customerPhone'] = customerPhone;
            
            await doc.reference.update({
              'shippingInfo': updatedShippingInfo,
            });
            
            print('✅ Added phone $customerPhone to order ${doc.id}');
            updatedCount++;
          }
        }
      }
    }
    
    print('📊 Added customer phone to $updatedCount orders in $collectionName');
  }
  
  /// Chạy tất cả fixes
  static Future<void> runAllFixes() async {
    print('🚀 Running all order fixes...');
    
    await fixDeliveredOrders();
    await addCustomerPhoneToShippingInfo();
    
    print('🎉 All fixes completed!');
  }
}