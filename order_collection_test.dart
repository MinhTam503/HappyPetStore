// Test file to verify order collection logic
// This file demonstrates the separation between mobile and web orders

import 'package:cloud_firestore/cloud_firestore.dart';

class OrderCollectionTest {
  // Mobile orders - saved to 'orders' collection
  static Future<void> saveMobileOrder() async {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    // Mobile order logic here...
    print('Mobile order saved to: orders/${orderRef.id}');
  }
  
  // Web orders - saved to 'ordersWeb' collection  
  static Future<void> saveWebOrder() async {
    final orderRef = FirebaseFirestore.instance.collection('ordersWeb').doc();
    // Web order logic here...
    print('Web order saved to: ordersWeb/${orderRef.id}');
  }
  
  // Admin can view both collections
  static Future<void> getAllOrders() async {
    // Get mobile orders
    final mobileOrders = await FirebaseFirestore.instance
        .collection('orders')
        .get();
    
    // Get web orders
    final webOrders = await FirebaseFirestore.instance
        .collection('ordersWeb')
        .get();
        
    print('Mobile orders: ${mobileOrders.docs.length}');
    print('Web orders: ${webOrders.docs.length}');
  }
}

/* 
SUMMARY:
✅ Mobile App (lib/view/mobile/) → saves to 'orders' collection
✅ Web App (lib/view/web_user/) → saves to 'ordersWeb' collection  
✅ Admin Panel (lib/view/web/screen_admin/) → can view both collections

This separation allows:
- Better analytics and reporting by platform
- Different business logic for mobile vs web orders
- Cleaner data organization
- Platform-specific optimizations
*/
