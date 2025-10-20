import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/helpers/order_notification_helper.dart';

/// 🚚 Shipping Service - Mock shipping cho Happy Pets
/// Chỉ sử dụng Mock API cho demo và test
class ShippingService {
  
  // Local mock data cho demo
  static final Map<String, Map<String, dynamic>> _mockShipments = {};
  
  /// Tạo đơn giao hàng mới - Chỉ sử dụng Mock
  /// 
  /// [orderId] - ID đơn hàng từ Firebase
  /// [shippingAddress] - Địa chỉ giao hàng
  /// [customerInfo] - Thông tin khách hàng
  /// 
  /// Returns: Map chứa trackingNumber và thông tin giao hàng
  static Future<Map<String, dynamic>> createShipment({
    required String orderId,
    required String shippingAddress,
    required Map<String, dynamic> customerInfo,
    double? totalWeight,
    double? totalValue,
    List<Map<String, dynamic>>? items,
  }) async {
    print('🚚 Creating MOCK shipment for order: $orderId');
    print('📦 Using provider: MOCK ONLY');
    
    return await _createMockShipment(
      orderId: orderId,
      shippingAddress: shippingAddress,
      customerInfo: customerInfo,
      totalWeight: totalWeight,
      totalValue: totalValue,
    );
  }

  /// Calculate shipping fee - Always return 0 (FREE SHIPPING)
  /// Returns: Map với success, data {shippingFee: 0}, message
  static Future<Map<String, dynamic>> calculateShippingFee({
    required String shippingAddress,
    required double totalValue,
    required double totalWeight,
    required Map<String, dynamic> customerInfo,
  }) async {
    try {
      print('💰 Calculating shipping fee: FREE SHIPPING (Mock only)');
      return {
        'success': true,
        'data': {'shippingFee': 0.0}, // FREE SHIPPING
        'message': 'Miễn phí giao hàng'
      };
    } catch (e) {
      print('❌ Error calculating shipping fee: $e');
      return {
        'success': false,
        'error': e.toString(),
        'data': {'shippingFee': 0.0}, // Still free on error
        'message': 'Miễn phí giao hàng'
      };
    }
  }

  /// Tạo shipment với Mock API
  static Future<Map<String, dynamic>> _createMockShipment({
    required String orderId,
    required String shippingAddress,
    required Map<String, dynamic> customerInfo,
    double? totalWeight,
    double? totalValue,
  }) async {
    try {
      print('🚚 Creating mock shipment for order: $orderId');
      
      // Generate tracking number
      final trackingNumber = _generateTrackingNumber();
      
      // Mock shipping companies cho realistic feeling
      final shippingCompanies = ['Giao Hàng Nhanh', 'Viettel Post', 'J&T Express', 'Ninja Van'];
      final selectedCompany = shippingCompanies[Random().nextInt(shippingCompanies.length)];
      
      // Estimate delivery time (1-3 days for pets)
      final estimatedDelivery = DateTime.now().add(Duration(days: 1 + Random().nextInt(3)));
      
      // Calculate shipping fee based on address
      final shippingFee = _calculateShippingFee(shippingAddress, totalValue ?? 0);
      
      final shipmentData = {
        'trackingNumber': trackingNumber,
        'orderId': orderId,
        'shippingCompany': selectedCompany,
        'status': 'pickup_pending', // pickup_pending → in_transit → delivered
        'estimatedDelivery': estimatedDelivery.toIso8601String(),
        'actualDeliveryTime': null, // Thời gian giao thực tế (null until delivered)
        'shippingFee': shippingFee,
        'shippingAddress': shippingAddress,
        'customerInfo': customerInfo,
        'customerPhone': customerInfo['phone'] ?? '', // Số điện thoại customer để hiển thị
        'createdAt': DateTime.now().toIso8601String(),
        'trackingHistory': [
          {
            'status': 'pickup_pending',
            'description': 'Đơn hàng đã được tạo, chờ lấy hàng',
            'timestamp': DateTime.now().toIso8601String(),
            'location': 'Happy Pets Store - TP.HCM'
          }
        ]
      };
      
      // Store locally for mock tracking (temporary until saved to Firebase)
      _mockShipments[trackingNumber] = shipmentData;
      print('🎭 Stored mock shipment temporarily: $trackingNumber');
      
      // Simulate API call
      await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1000)));
      
      print('✅ Shipment created successfully: $trackingNumber');
      return {
        'success': true,
        'data': shipmentData,
        'message': 'Đơn hàng đã được tạo thành công'
      };
      
    } catch (e) {
      print('❌ Error creating shipment: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Không thể tạo đơn giao hàng'
      };
    }
  }
  
  /// Theo dõi trạng thái đơn hàng - Chỉ Mock
  /// 
  /// [trackingNumber] - Mã vận đơn
  /// Returns: Thông tin chi tiết về trạng thái giao hàng
  static Future<Map<String, dynamic>> trackShipment(String trackingNumber) async {
    print('📱 Tracking MOCK shipment: $trackingNumber');
    return await _trackMockShipment(trackingNumber);
  }

  /// Track shipment với Mock API và Firebase fallback
  static Future<Map<String, dynamic>> _trackMockShipment(String trackingNumber) async {
    try {
      print('📱 Tracking mock shipment: $trackingNumber');
      print('🔍 Searching Firebase for tracking number...');
      
      // First check Firebase for this tracking number
      try {
        // Strategy: Get ALL orders and filter manually to avoid index issues
        print('🔍 Fetching all orders from Firebase...');
        
        final mobileSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .get();
        
        final webSnapshot = await FirebaseFirestore.instance
            .collection('ordersWeb')
            .get();
        
        print('📱 Total mobile orders: ${mobileSnapshot.docs.length}');
        print('🌐 Total web orders: ${webSnapshot.docs.length}');
        
        // Search in mobile orders
        for (final doc in mobileSnapshot.docs) {
          final data = doc.data();
          final docTrackingNumber = data['trackingNumber']?.toString() ?? '';
          
          if (docTrackingNumber == trackingNumber) {
            print('✅ Found matching tracking number in mobile orders: ${doc.id}');
            print('   📦 Has shippingInfo: ${data['shippingInfo'] != null}');
            
            if (data['shippingInfo'] != null) {
              final shippingInfo = Map<String, dynamic>.from(data['shippingInfo']);
              
              // Ensure trackingHistory exists
              if (shippingInfo['trackingHistory'] == null || (shippingInfo['trackingHistory'] as List).isEmpty) {
                print('⚠️ Missing trackingHistory, creating default...');
                shippingInfo['trackingHistory'] = [
                  {
                    'status': shippingInfo['status'] ?? 'pickup_pending',
                    'description': 'Đơn hàng đã được tạo',
                    'timestamp': shippingInfo['createdAt'] ?? DateTime.now().toIso8601String(),
                    'location': 'Happy Pets Store - TP.HCM'
                  }
                ];
              }
              
              print('✅ Returning shippingInfo from mobile orders');
              return {
                'success': true,
                'data': shippingInfo,
                'message': 'Thông tin vận chuyển từ Firebase (Mobile)'
              };
            } else {
              print('⚠️ Tracking number found but shippingInfo is NULL');
              print('   This should not happen - order has tracking but no shipping data');
              // Create minimal shippingInfo from available data
              final minimalShippingInfo = {
                'trackingNumber': trackingNumber,
                'orderId': doc.id,
                'status': 'pickup_pending',
                'shippingCompany': 'Unknown',
                'createdAt': DateTime.now().toIso8601String(),
                'estimatedDelivery': DateTime.now().add(Duration(days: 2)).toIso8601String(),
                'trackingHistory': [
                  {
                    'status': 'pickup_pending',
                    'description': 'Đơn hàng đã được tạo (Dữ liệu khôi phục)',
                    'timestamp': DateTime.now().toIso8601String(),
                    'location': 'Happy Pets Store - TP.HCM'
                  }
                ]
              };
              return {
                'success': true,
                'data': minimalShippingInfo,
                'message': 'Thông tin vận chuyển (Dữ liệu khôi phục)'
              };
            }
          }
        }
        
        // Search in web orders
        for (final doc in webSnapshot.docs) {
          final data = doc.data();
          final docTrackingNumber = data['trackingNumber']?.toString() ?? '';
          
          if (docTrackingNumber == trackingNumber) {
            print('✅ Found matching tracking number in web orders: ${doc.id}');
            print('   📦 Has shippingInfo: ${data['shippingInfo'] != null}');
            
            if (data['shippingInfo'] != null) {
              final shippingInfo = Map<String, dynamic>.from(data['shippingInfo']);
              
              // Ensure trackingHistory exists
              if (shippingInfo['trackingHistory'] == null || (shippingInfo['trackingHistory'] as List).isEmpty) {
                print('⚠️ Missing trackingHistory, creating default...');
                shippingInfo['trackingHistory'] = [
                  {
                    'status': shippingInfo['status'] ?? 'pickup_pending',
                    'description': 'Đơn hàng đã được tạo',
                    'timestamp': shippingInfo['createdAt'] ?? DateTime.now().toIso8601String(),
                    'location': 'Happy Pets Store - TP.HCM'
                  }
                ];
              }
              
              print('✅ Returning shippingInfo from web orders');
              return {
                'success': true,
                'data': shippingInfo,
                'message': 'Thông tin vận chuyển từ Firebase (Web)'
              };
            } else {
              print('⚠️ Tracking number found but shippingInfo is NULL');
              print('   This should not happen - order has tracking but no shipping data');
              // Create minimal shippingInfo from available data
              final minimalShippingInfo = {
                'trackingNumber': trackingNumber,
                'orderId': doc.id,
                'status': 'pickup_pending',
                'shippingCompany': 'Unknown',
                'createdAt': DateTime.now().toIso8601String(),
                'estimatedDelivery': DateTime.now().add(Duration(days: 2)).toIso8601String(),
                'trackingHistory': [
                  {
                    'status': 'pickup_pending',
                    'description': 'Đơn hàng đã được tạo (Dữ liệu khôi phục)',
                    'timestamp': DateTime.now().toIso8601String(),
                    'location': 'Happy Pets Store - TP.HCM'
                  }
                ]
              };
              return {
                'success': true,
                'data': minimalShippingInfo,
                'message': 'Thông tin vận chuyển (Dữ liệu khôi phục)'
              };
            }
          }
        }
        
        print('❌ Tracking number not found in any Firebase orders');
      } catch (e) {
        print('⚠️ Firebase tracking failed, trying local mock: $e');
      }
      
      // Fallback to local mock data
      if (_mockShipments.containsKey(trackingNumber)) {
        final shipment = Map<String, dynamic>.from(_mockShipments[trackingNumber]!);
        
        // Simulate status progression
        _updateShipmentStatus(shipment);
        
        print('🎭 Found tracking in local mock data');
        return {
          'success': true,
          'data': shipment,
          'message': 'Thông tin vận chuyển (Mock API)'
        };
      }
      
      // If not found anywhere
      print('❌ Tracking number not found in Firebase or Mock');
      return {
        'success': false,
        'error': 'Tracking number not found',
        'message': 'Không tìm thấy mã vận đơn'
      };
      
    } catch (e) {
      print('❌ Error tracking shipment: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Không thể tra cứu thông tin giao hàng'
      };
    }
  }
  
  /// Cập nhật trạng thái đơn giao hàng (dành cho admin)
  /// 
  /// [trackingNumber] - Mã vận đơn
  /// [newStatus] - Trạng thái mới
  /// [description] - Mô tả chi tiết
  /// [location] - Vị trí hiện tại
  static Future<Map<String, dynamic>> updateShipmentStatus({
    required String trackingNumber,
    required String newStatus,
    required String description,
    String? location,
  }) async {
    try {
      print('🔄 Updating shipment status: $trackingNumber -> $newStatus');
      
      // First try to update in Firebase
      bool updatedInFirebase = false;
      String? orderId;
      String? userEmail;
      
      try {
        // Check mobile orders
        final mobileQuery = await FirebaseFirestore.instance
            .collection('orders')
            .where('trackingNumber', isEqualTo: trackingNumber)
            .limit(1)
            .get();
            
        if (mobileQuery.docs.isNotEmpty) {
          final doc = mobileQuery.docs.first;
          final data = doc.data();
          orderId = data['orderId'] ?? data['id'];
          userEmail = data['email'];
          
          if (data['shippingInfo'] != null) {
            final shippingInfo = Map<String, dynamic>.from(data['shippingInfo']);
            final oldStatus = shippingInfo['status'];
            shippingInfo['status'] = newStatus;
            
            // Add to tracking history
            final trackingHistory = List<Map<String, dynamic>>.from(shippingInfo['trackingHistory'] ?? []);
            trackingHistory.add({
              'status': newStatus,
              'description': description,
              'timestamp': DateTime.now().toIso8601String(),
              'location': location ?? 'Đang cập nhật...'
            });
            shippingInfo['trackingHistory'] = trackingHistory;
            
            // Cập nhật thời gian thực tế khi giao hàng
            if (newStatus == 'delivered') {
              shippingInfo['actualDeliveryTime'] = DateTime.now().toIso8601String();
            }
            
            // Tự động cập nhật trạng thái order dựa trên shipping status
            Map<String, dynamic> orderUpdate = {'shippingInfo': shippingInfo};
            
            if (newStatus == 'delivered') {
              orderUpdate['statusOrder'] = 'Completed';
              orderUpdate['statusPayment'] = 'Payment Completed';
            } else if (newStatus == 'failed' || newStatus == 'returned') {
              orderUpdate['statusOrder'] = 'Cancelled';
            }
            
            await doc.reference.update(orderUpdate);
            updatedInFirebase = true;
            
              // Gửi thông báo khi có thay đổi shipping status
              if (userEmail != null && orderId != null) {
                await _sendShippingStatusNotification(
                  email: userEmail,
                  orderId: orderId,
                  oldStatus: oldStatus,
                  newStatus: newStatus,
                  description: description,
                );
              }            print('✅ Updated shipment status in Firebase mobile orders');
          }
        }
        
        // Check web orders if not found in mobile
        if (!updatedInFirebase) {
          final webQuery = await FirebaseFirestore.instance
              .collection('ordersWeb')
              .where('trackingNumber', isEqualTo: trackingNumber)
              .limit(1)
              .get();
              
          if (webQuery.docs.isNotEmpty) {
            final doc = webQuery.docs.first;
            final data = doc.data();
            orderId = data['orderId'] ?? data['id'];
            userEmail = data['email'];
            
            if (data['shippingInfo'] != null) {
              final shippingInfo = Map<String, dynamic>.from(data['shippingInfo']);
              final oldStatus = shippingInfo['status'];
              shippingInfo['status'] = newStatus;
              
              // Add to tracking history
              final trackingHistory = List<Map<String, dynamic>>.from(shippingInfo['trackingHistory'] ?? []);
              trackingHistory.add({
                'status': newStatus,
                'description': description,
                'timestamp': DateTime.now().toIso8601String(),
                'location': location ?? 'Đang cập nhật...'
              });
              shippingInfo['trackingHistory'] = trackingHistory;
              
              // Cập nhật thời gian thực tế khi giao hàng
              if (newStatus == 'delivered') {
                shippingInfo['actualDeliveryTime'] = DateTime.now().toIso8601String();
              }
              
              // Tự động cập nhật trạng thái order dựa trên shipping status
              Map<String, dynamic> orderUpdate = {'shippingInfo': shippingInfo};
              
              if (newStatus == 'delivered') {
                orderUpdate['statusOrder'] = 'Completed';
                orderUpdate['statusPayment'] = 'Payment Completed';
              } else if (newStatus == 'failed' || newStatus == 'returned') {
                orderUpdate['statusOrder'] = 'Cancelled';
              }
              
              await doc.reference.update(orderUpdate);
              updatedInFirebase = true;
              
              // Gửi thông báo khi có thay đổi shipping status
              if (userEmail != null && orderId != null) {
                await _sendShippingStatusNotification(
                  email: userEmail,
                  orderId: orderId,
                  oldStatus: oldStatus,
                  newStatus: newStatus,
                  description: description,
                );
              }
              
              print('✅ Updated shipment status in Firebase web orders');
            }
          }
        }
      } catch (e) {
        print('⚠️ Firebase update failed, trying local mock: $e');
      }
      
      // Fallback to mock data if not found in Firebase
      if (!updatedInFirebase && _mockShipments.containsKey(trackingNumber)) {
        final shipment = _mockShipments[trackingNumber]!;
        shipment['status'] = newStatus;
        
        // Add to tracking history
        final trackingHistory = List<Map<String, dynamic>>.from(shipment['trackingHistory']);
        trackingHistory.add({
          'status': newStatus,
          'description': description,
          'timestamp': DateTime.now().toIso8601String(),
          'location': location ?? 'Đang cập nhật...'
        });
        shipment['trackingHistory'] = trackingHistory;
        
        // Update estimated delivery if delivered
        if (newStatus == 'delivered') {
          shipment['deliveredAt'] = DateTime.now().toIso8601String();
        }
        
        updatedInFirebase = true; // Mark as updated for response
        print('✅ Updated shipment status in local mock');
      }
      
      if (updatedInFirebase) {
        return {
          'success': true,
          'data': {'status': newStatus, 'trackingNumber': trackingNumber},
          'message': 'Cập nhật trạng thái thành công'
        };
      } else {
        return {
          'success': false,
          'error': 'Tracking number not found',
          'message': 'Không tìm thấy mã vận đơn'
        };
      }
      
    } catch (e) {
      print('❌ Error updating shipment status: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Không thể cập nhật trạng thái'
      };
    }
  }
  
  /// Lấy danh sách tất cả đơn giao hàng từ Firebase
  static Future<Map<String, dynamic>> getAllShipments() async {
    try {
      print('📋 Loading shipments from Firebase...');
      
      final shipments = <Map<String, dynamic>>[];
      
      // Get from mobile orders
      final mobileSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('trackingNumber', isNull: false)
          .get();
      
      // Get from web orders (matching orders_admin.dart naming)
      final webSnapshot = await FirebaseFirestore.instance
          .collection('ordersWeb')
          .where('trackingNumber', isNull: false)
          .get();
      
      print('📱 Mobile orders with tracking: ${mobileSnapshot.docs.length}');
      print('🌐 Web orders with tracking: ${webSnapshot.docs.length}');
      
      // Clean up mock shipments that now exist in Firebase
      final firebaseTrackingNumbers = <String>{};
      
      // Process mobile orders
      for (final doc in mobileSnapshot.docs) {
        final data = doc.data();
        if (data['trackingNumber'] != null && data['shippingInfo'] != null) {
          final trackingNumber = data['trackingNumber'];
          firebaseTrackingNumbers.add(trackingNumber);
          print('📱 Mobile order: ${doc.id} - tracking: $trackingNumber');
          
          // Get customer phone from multiple possible locations
          String customerPhone = '';
          try {
            customerPhone = data['phone']?.toString() ?? 
                          data['shippingInfo']?['customerPhone']?.toString() ?? 
                          data['shippingInfo']?['customerInfo']?['phone']?.toString() ?? 
                          data['deliveryInfo']?['phone']?.toString() ?? '';
          } catch (e) {
            customerPhone = '';
          }
          
          shipments.add({
            'trackingNumber': trackingNumber,
            'orderId': doc.id,
            'status': data['shippingInfo']['status'] ?? 'pickup_pending',
            'shippingCompany': data['shippingInfo']['shippingCompany'] ?? 'Unknown',
            'customerEmail': data['email'] ?? 'Unknown',
            'customerPhone': customerPhone, // ✅ Add customer phone
            'shippingAddress': data['address'] ?? data['shippingInfo']['shippingAddress'] ?? 'Unknown',
            'estimatedDelivery': data['shippingInfo']['estimatedDelivery'] ?? DateTime.now().add(Duration(days: 2)).toIso8601String(),
            'createdAt': data['shippingInfo']['createdAt'] ?? data['createdAt'] ?? DateTime.now().toIso8601String(),
            'orderValue': data['total'] ?? data['shippingInfo']['orderValue'] ?? 0,
            'collection': 'orders',
            // Keep full data for reference
            'customerInfo': data['shippingInfo']?['customerInfo'] ?? data['deliveryInfo'],
          });
        }
      }
      
      // Process web orders
      for (final doc in webSnapshot.docs) {
        final data = doc.data();
        if (data['trackingNumber'] != null && data['shippingInfo'] != null) {
          final trackingNumber = data['trackingNumber'];
          firebaseTrackingNumbers.add(trackingNumber);
          print('🌐 Web order: ${doc.id} - tracking: $trackingNumber');
          
          // Get customer phone from multiple possible locations
          String customerPhone = '';
          try {
            customerPhone = data['phone']?.toString() ?? 
                          data['shippingInfo']?['customerPhone']?.toString() ?? 
                          data['shippingInfo']?['customerInfo']?['phone']?.toString() ?? 
                          data['deliveryInfo']?['phone']?.toString() ?? '';
          } catch (e) {
            customerPhone = '';
          }
          
          shipments.add({
            'trackingNumber': trackingNumber,
            'orderId': doc.id,
            'status': data['shippingInfo']['status'] ?? 'pickup_pending',
            'shippingCompany': data['shippingInfo']['shippingCompany'] ?? 'Unknown',
            'customerEmail': data['email'] ?? 'Unknown',
            'customerPhone': customerPhone, // ✅ Add customer phone
            'shippingAddress': data['address'] ?? data['shippingInfo']['shippingAddress'] ?? 'Unknown',
            'estimatedDelivery': data['shippingInfo']['estimatedDelivery'] ?? DateTime.now().add(Duration(days: 2)).toIso8601String(),
            'createdAt': data['shippingInfo']['createdAt'] ?? data['createdAt'] ?? DateTime.now().toIso8601String(),
            'orderValue': data['total'] ?? data['shippingInfo']['orderValue'] ?? 0,
            'collection': 'ordersWeb',
            // Keep full data for reference
            'customerInfo': data['shippingInfo']?['customerInfo'] ?? data['deliveryInfo'],
          });
        }
      }
      
      // Clean up mock shipments that are now in Firebase
      final mockKeysToRemove = <String>[];
      for (final trackingNumber in firebaseTrackingNumbers) {
        if (_mockShipments.containsKey(trackingNumber)) {
          mockKeysToRemove.add(trackingNumber);
          print('🧹 Cleaning up mock shipment (now in Firebase): $trackingNumber');
        }
      }
      for (final key in mockKeysToRemove) {
        _mockShipments.remove(key);
      }
      
      // Sort by creation date (newest first)
      shipments.sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
      
      // Deduplicate by tracking number (keep the first occurrence)
      final uniqueShipments = <String, Map<String, dynamic>>{};
      for (final shipment in shipments) {
        final trackingNumber = shipment['trackingNumber'];
        if (!uniqueShipments.containsKey(trackingNumber)) {
          uniqueShipments[trackingNumber] = shipment;
        } else {
          print('⚠️ Duplicate shipment found for tracking: $trackingNumber, skipping...');
        }
      }
      final deduplicatedShipments = uniqueShipments.values.toList();
      
      print('📋 Found ${shipments.length} total shipments, ${deduplicatedShipments.length} unique shipments from Firebase');
      
      // Also include mock shipments for demo, but avoid duplicates
      final mockData = _mockShipments.values.toList();
      for (final mockShipment in mockData) {
        final trackingNumber = mockShipment['trackingNumber'];
        if (!uniqueShipments.containsKey(trackingNumber)) {
          uniqueShipments[trackingNumber] = mockShipment;
          deduplicatedShipments.add(mockShipment);
          print('🎭 Added mock shipment: $trackingNumber');
        } else {
          print('⚠️ Mock shipment $trackingNumber already exists in Firebase, skipping...');
        }
      }
      
      print('📋 Final shipment count: ${deduplicatedShipments.length} (Firebase + Mock)');
      
      return {
        'success': true,
        'data': deduplicatedShipments,
        'message': 'Danh sách đơn giao hàng từ Firebase và Mock (đã loại bỏ duplicate)'
      };
    } catch (e) {
      print('❌ Error loading shipments: $e');
      
      // Fallback to mock data only
      return {
        'success': true,
        'data': _mockShipments.values.toList(),
        'message': 'Fallback to mock data: ${e.toString()}'
      };
    }
  }
  
  // ==================== PRIVATE METHODS ====================
  
  /// Generate realistic tracking number
  static String _generateTrackingNumber() {
    final prefixes = ['HPS', 'PET', 'GHN', 'VTP'];
    final prefix = prefixes[Random().nextInt(prefixes.length)];
    final number = Random().nextInt(999999999).toString().padLeft(9, '0');
    return '$prefix$number';
  }
  
  /// Calculate shipping fee based on address and value
  static double _calculateShippingFee(String address, double orderValue) {
    // Base fee
    double fee = 30000; // 30k VND base
    
    // Distance based pricing
    if (address.toLowerCase().contains('hà nội')) {
      fee += 20000; // +20k for Hanoi
    } else if (address.toLowerCase().contains('đà nẵng')) {
      fee += 15000; // +15k for Da Nang
    } else if (address.toLowerCase().contains('cần thơ')) {
      fee += 25000; // +25k for Can Tho
    }
    
    // Free shipping for orders > 500k
    if (orderValue > 500000) {
      fee = 0;
    }
    
    return fee;
  }
  
  /// Simulate realistic status progression over time
  static void _updateShipmentStatus(Map<String, dynamic> shipment) {
    final createdAt = DateTime.parse(shipment['createdAt']);
    final now = DateTime.now();
    final hoursSinceCreated = now.difference(createdAt).inHours;
    
    final currentStatus = shipment['status'] as String;
    final trackingHistory = List<Map<String, dynamic>>.from(shipment['trackingHistory']);
    
    // Status progression simulation
    if (currentStatus == 'pickup_pending' && hoursSinceCreated > 2) {
      shipment['status'] = 'in_transit';
      trackingHistory.add({
        'status': 'in_transit',
        'description': 'Đơn hàng đã được lấy và đang trên đường giao',
        'timestamp': createdAt.add(Duration(hours: 2)).toIso8601String(),
        'location': 'Bưu cục trung chuyển TP.HCM'
      });
    }
    
    if (currentStatus == 'in_transit' && hoursSinceCreated > 24) {
      shipment['status'] = 'out_for_delivery';
      trackingHistory.add({
        'status': 'out_for_delivery',
        'description': 'Đơn hàng đang được giao đến địa chỉ',
        'timestamp': createdAt.add(Duration(hours: 24)).toIso8601String(),
        'location': 'Đang giao hàng'
      });
    }
    
    if (currentStatus == 'out_for_delivery' && hoursSinceCreated > 48) {
      shipment['status'] = 'delivered';
      shipment['deliveredAt'] = createdAt.add(Duration(hours: 48)).toIso8601String();
      trackingHistory.add({
        'status': 'delivered',
        'description': 'Đơn hàng đã được giao thành công',
        'timestamp': createdAt.add(Duration(hours: 48)).toIso8601String(),
        'location': shipment['shippingAddress']
      });
    }
    
    shipment['trackingHistory'] = trackingHistory;
  }
  
  /// Get localized status text
  static String getStatusText(String status) {
    switch (status) {
      case 'pickup_pending':
        return 'Chờ lấy hàng';
      case 'in_transit':
        return 'Đang vận chuyển';
      case 'out_for_delivery':
        return 'Đang giao hàng';
      case 'delivered':
        return 'Đã giao hàng';
      case 'failed':
        return 'Giao hàng thất bại';
      case 'returned':
        return 'Đã trả về';
      default:
        return 'Không xác định';
    }
  }
  
  /// Get status color for UI
  static String getStatusColor(String status) {
    switch (status) {
      case 'pickup_pending':
        return '#FF9800'; // Orange
      case 'in_transit':
        return '#2196F3'; // Blue
      case 'out_for_delivery':
        return '#9C27B0'; // Purple
      case 'delivered':
        return '#4CAF50'; // Green
      case 'failed':
      case 'returned':
        return '#F44336'; // Red
      default:
        return '#757575'; // Grey
    }
  }
  
  /// Gửi thông báo khi shipping status thay đổi
  static Future<void> _sendShippingStatusNotification({
    required String email,
    required String orderId,
    required String oldStatus,
    required String newStatus,
    required String description,
  }) async {
    try {
      // Lấy userId từ email
      final userId = await OrderNotificationHelper.getUserIdFromEmail(email);
      if (userId == null) {
        print('⚠️ User not found for email: $email');
        return;
      }
      
      // Lấy thông tin customer
      final customerInfo = await OrderNotificationHelper.getCustomerInfoFromEmail(email);
      final customerName = customerInfo?['displayName'] ?? customerInfo?['name'] ?? 'Customer';
      
      // Gửi thông báo dựa trên trạng thái mới
      switch (newStatus) {
        case 'in_transit':
          await OrderNotificationHelper.sendOrderShippedNotification(
            userId: userId,
            orderId: orderId,
            customerName: customerName,
            trackingNumber: '',
            shippingCompany: description,
          );
          break;
          
        case 'out_for_delivery':
          await OrderNotificationHelper.sendShippingStatusNotification(
            userId: userId,
            orderId: orderId,
            customerName: customerName,
            status: 'Đang giao hàng',
            message: description,
          );
          break;
          
        case 'delivered':
          await OrderNotificationHelper.sendOrderDeliveredNotification(
            userId: userId,
            orderId: orderId,
            customerName: customerName,
            deliveredAt: DateTime.now(),
          );
          break;
          
        case 'failed':
        case 'returned':
          await OrderNotificationHelper.sendShippingStatusNotification(
            userId: userId,
            orderId: orderId,
            customerName: customerName,
            status: 'Giao hàng thất bại',
            message: description,
          );
          break;
          
        default:
          // Gửi thông báo chung cho các trạng thái khác
          await OrderNotificationHelper.sendShippingStatusNotification(
            userId: userId,
            orderId: orderId,
            customerName: customerName,
            status: getStatusText(newStatus),
            message: description,
          );
      }
      
      print('✅ Shipping status notification sent for $newStatus');
    } catch (e) {
      print('❌ Error sending shipping status notification: $e');
    }
  }
}