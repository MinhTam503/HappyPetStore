import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDebugHelper {
  static Future<void> debugFirebaseData() async {
    print('🔍 === FIREBASE DEBUG ANALYSIS ===');
    
    try {
      // Check orders collection
      final orders = await FirebaseFirestore.instance.collection('orders').limit(3).get();
      print('📱 MOBILE ORDERS (${orders.docs.length}):');
      for (var doc in orders.docs) {
        final data = doc.data();
        print('  ID: ${doc.id}');
        print('  Customer: ${data['fullName'] ?? data['name'] ?? 'Unknown'}');
        print('  Amount: ${data['totalAmount']}');
        print('  Status: ${data['statusOrder']}');
        print('  Timestamp type: ${data['timestamp'].runtimeType}');
        print('  Timestamp value: ${data['timestamp']}');
        print('  ---');
      }
      
      // Check ordersWeb collection
      final ordersWeb = await FirebaseFirestore.instance.collection('ordersWeb').limit(3).get();
      print('🌐 WEB ORDERS (${ordersWeb.docs.length}):');
      for (var doc in ordersWeb.docs) {
        final data = doc.data();
        print('  ID: ${doc.id}');
        print('  Customer: ${data['fullName'] ?? data['name'] ?? 'Unknown'}');
        print('  Amount: ${data['totalAmount']}');
        print('  Status: ${data['statusOrder']}');
        print('  Timestamp type: ${data['timestamp'].runtimeType}');
        print('  Timestamp value: ${data['timestamp']}');
        print('  ---');
      }
      
      // Check users collection
      final users = await FirebaseFirestore.instance.collection('users').count().get();
      print('👥 USERS COUNT: ${users.count}');
      
      // Check pets collection
      final pets = await FirebaseFirestore.instance.collection('Pets').count().get();
      print('🐾 PETS COUNT: ${pets.count}');
      
    } catch (e) {
      print('❌ Debug error: $e');
    }
    
    print('🔍 === END DEBUG ===');
  }
}
