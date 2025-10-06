import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 🚚 GoSHIP API Service - Tích hợp GoSHIP API thật cho Happy Pets
/// API Documentation: https://docs.goship.io
class GoShipService {
  // GoSHIP API Configuration
  static String get _baseUrl => dotenv.env['GOSHIP_BASE_URL'] ?? 'https://api-staging.goship.io';
  static String get _apiKey => dotenv.env['GOSHIP_API_KEY'] ?? '';
  
  // Headers for API requests
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
    'Accept': 'application/json',
  };

  /// Tính phí ship từ GoSHIP
  /// 
  /// [fromAddress] - Địa chỉ gửi hàng (Happy Pets Store)
  /// [toAddress] - Địa chỉ nhận hàng
  /// [weight] - Cân nặng (gram)
  /// [value] - Giá trị hàng hóa (VND)
  /// 
  /// Returns: Danh sách các options vận chuyển với giá
  static Future<Map<String, dynamic>> calculateShippingFee({
    required String fromAddress,
    required String toAddress,
    required int weight,
    required double value,
    String? fromDistrict,
    String? toDistrict,
    String? fromCity,
    String? toCity,
  }) async {
    try {
      print('📊 Calculating shipping fee with GoSHIP...');
      
      final requestBody = {
        'from': {
          'address': fromAddress,
          'district': fromDistrict ?? 'Thủ Đức',
          'city': fromCity ?? 'Hồ Chí Minh',
        },
        'to': {
          'address': toAddress,
          'district': toDistrict ?? _extractDistrict(toAddress),
          'city': toCity ?? _extractCity(toAddress),
        },
        'weight': weight,
        'value': value.toInt(),
        'cod_amount': 0, // COD amount if any
        'insurance_value': value.toInt(),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/rates'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      print('GoSHIP Rate Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return {
          'success': true,
          'data': data['data'] ?? [],
          'message': 'Tính phí thành công'
        };
      } else {
        print('GoSHIP Rate Error: ${response.body}');
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
          'message': 'Không thể tính phí ship'
        };
      }
    } catch (e) {
      print('❌ Error calculating shipping fee: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi kết nối API'
      };
    }
  }

  /// Tạo đơn hàng giao hàng trên GoSHIP
  /// 
  /// [orderData] - Thông tin đơn hàng
  /// 
  /// Returns: Thông tin đơn hàng được tạo (tracking number, etc.)
  static Future<Map<String, dynamic>> createShipment({
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String shippingAddress,
    required List<Map<String, dynamic>> items,
    required double totalValue,
    required int totalWeight,
    String? shippingService,
    bool enableCOD = false,
    double codAmount = 0,
  }) async {
    try {
      print('🚚 Creating GoSHIP shipment for order: $orderId');
      
      // Extract address components
      final addressParts = _parseAddress(shippingAddress);
      
      final requestBody = {
        'order_id': orderId,
        'shipping_service': shippingService ?? 'standard',
        'from': {
          'name': 'Happy Pets Store',
          'phone': '0123456789',
          'email': 'store@happypets.com',
          'address': '123 Đường ABC, Phường XYZ',
          'district': 'Thủ Đức',
          'city': 'Hồ Chí Minh',
          'postal_code': '70000',
        },
        'to': {
          'name': customerName,
          'phone': customerPhone,
          'email': customerEmail,
          'address': addressParts['address'],
          'district': addressParts['district'],
          'city': addressParts['city'],
          'postal_code': addressParts['postalCode'],
        },
        'package': {
          'weight': totalWeight,
          'length': 30, // cm
          'width': 20,  // cm
          'height': 15, // cm
          'value': totalValue.toInt(),
          'description': 'Sản phẩm thú cưng từ Happy Pets',
        },
        'items': items.map((item) => {
          'name': item['name'] ?? 'Sản phẩm',
          'quantity': item['quantity'] ?? 1,
          'price': item['price'] ?? 0,
          'weight': (item['weight'] ?? 500), // Default 500g per item
        }).toList(),
        'payment': {
          'method': enableCOD ? 'cod' : 'prepaid',
          'cod_amount': codAmount.toInt(),
        },
        'delivery_options': {
          'delivery_time': 'standard', // standard, express, same_day
          'insurance': true,
          'signature_required': false,
        },
        'notes': 'Đơn hàng từ Happy Pets Store - Xin nhẹ nhàng vì có thú cưng',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/orders'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      print('GoSHIP Create Response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orderData = data['data'] ?? data;
        
        return {
          'success': true,
          'data': {
            'trackingNumber': orderData['tracking_number'] ?? orderData['order_code'],
            'orderId': orderId,
            'shippingCompany': 'GoSHIP',
            'status': _mapGoShipStatus(orderData['status'] ?? 'pending'),
            'estimatedDelivery': orderData['estimated_delivery_date'],
            'shippingFee': orderData['shipping_fee'] ?? 0,
            'shippingAddress': shippingAddress,
            'customerInfo': {
              'name': customerName,
              'phone': customerPhone,
              'email': customerEmail,
            },
            'createdAt': DateTime.now().toIso8601String(),
            'goshipData': orderData, // Store full GoSHIP response
            'trackingHistory': [
              {
                'status': 'pickup_pending',
                'description': 'Đơn hàng đã được tạo trên GoSHIP',
                'timestamp': DateTime.now().toIso8601String(),
                'location': 'Happy Pets Store - TP.HCM'
              }
            ]
          },
          'message': 'Tạo đơn giao hàng thành công'
        };
      } else {
        print('GoSHIP Create Error: ${response.body}');
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'API Error',
          'message': 'Không thể tạo đơn giao hàng: ${errorData['message'] ?? 'Lỗi không xác định'}'
        };
      }
    } catch (e) {
      print('❌ Error creating GoSHIP shipment: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi kết nối API GoSHIP'
      };
    }
  }

  /// Theo dõi đơn hàng trên GoSHIP
  /// 
  /// [trackingNumber] - Mã vận đơn GoSHIP
  /// 
  /// Returns: Thông tin tracking chi tiết
  static Future<Map<String, dynamic>> trackShipment(String trackingNumber) async {
    try {
      print('📱 Tracking GoSHIP shipment: $trackingNumber');

      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/orders/$trackingNumber'),
        headers: _headers,
      );

      print('GoSHIP Track Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orderData = data['data'] ?? data;
        
        return {
          'success': true,
          'data': {
            'trackingNumber': trackingNumber,
            'orderId': orderData['order_id'],
            'status': _mapGoShipStatus(orderData['status']),
            'shippingCompany': 'GoSHIP',
            'estimatedDelivery': orderData['estimated_delivery_date'],
            'currentLocation': orderData['current_location'],
            'shippingFee': orderData['shipping_fee'],
            'trackingHistory': _buildTrackingHistory(orderData['tracking_events'] ?? []),
            'goshipData': orderData,
          },
          'message': 'Tracking thành công'
        };
      } else {
        print('GoSHIP Track Error: ${response.body}');
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
          'message': 'Không tìm thấy thông tin vận đơn'
        };
      }
    } catch (e) {
      print('❌ Error tracking GoSHIP shipment: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi kết nối API GoSHIP'
      };
    }
  }

  /// Hủy đơn hàng trên GoSHIP
  /// 
  /// [trackingNumber] - Mã vận đơn
  /// [reason] - Lý do hủy
  static Future<Map<String, dynamic>> cancelShipment({
    required String trackingNumber,
    required String reason,
  }) async {
    try {
      print('❌ Canceling GoSHIP shipment: $trackingNumber');

      final requestBody = {
        'reason': reason,
        'note': 'Hủy từ Happy Pets Admin Panel',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/orders/$trackingNumber/cancel'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Hủy đơn hàng thành công'
        };
      } else {
        print('GoSHIP Cancel Error: ${response.body}');
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
          'message': 'Không thể hủy đơn hàng'
        };
      }
    } catch (e) {
      print('❌ Error canceling GoSHIP shipment: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi kết nối API GoSHIP'
      };
    }
  }

  /// Lấy danh sách tất cả đơn hàng
  static Future<Map<String, dynamic>> getAllShipments({
    int page = 1,
    int limit = 50,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      print('📦 Getting all GoSHIP shipments...');

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (fromDate != null) 'from_date': fromDate.toIso8601String().split('T')[0],
        if (toDate != null) 'to_date': toDate.toIso8601String().split('T')[0],
      };

      final uri = Uri.parse('$_baseUrl/api/v1/orders').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orders = (data['data'] ?? []) as List;
        
        return {
          'success': true,
          'data': orders.map((order) => {
            'trackingNumber': order['tracking_number'] ?? order['order_code'],
            'orderId': order['order_id'],
            'status': _mapGoShipStatus(order['status']),
            'shippingCompany': 'GoSHIP',
            'estimatedDelivery': order['estimated_delivery_date'],
            'shippingFee': order['shipping_fee'],
            'customerInfo': order['to'] ?? {},
            'createdAt': order['created_at'],
            'goshipData': order,
          }).toList(),
          'pagination': data['pagination'] ?? {},
          'message': 'Lấy danh sách thành công'
        };
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
          'message': 'Không thể lấy danh sách đơn hàng'
        };
      }
    } catch (e) {
      print('❌ Error getting GoSHIP shipments: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi kết nối API GoSHIP'
      };
    }
  }

  // ==================== HELPER METHODS ====================

  /// Map GoSHIP status to internal status
  static String _mapGoShipStatus(String goshipStatus) {
    switch (goshipStatus.toLowerCase()) {
      case 'pending':
      case 'confirmed':
        return 'pickup_pending';
      case 'picked_up':
      case 'in_transit':
      case 'sorting':
        return 'in_transit';
      case 'out_for_delivery':
      case 'delivering':
        return 'out_for_delivery';
      case 'delivered':
      case 'completed':
        return 'delivered';
      case 'failed':
      case 'exception':
        return 'failed';
      case 'returned':
      case 'return_to_sender':
        return 'returned';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'pickup_pending';
    }
  }

  /// Build tracking history from GoSHIP events
  static List<Map<String, dynamic>> _buildTrackingHistory(List<dynamic> events) {
    return events.map<Map<String, dynamic>>((event) => {
      'status': _mapGoShipStatus(event['status'] ?? ''),
      'description': event['description'] ?? event['message'] ?? 'Cập nhật trạng thái',
      'timestamp': event['created_at'] ?? event['timestamp'] ?? DateTime.now().toIso8601String(),
      'location': event['location'] ?? event['hub_name'] ?? 'Đang cập nhật...',
    }).toList();
  }

  /// Parse address to extract components
  static Map<String, String> _parseAddress(String fullAddress) {
    // Simple parsing - can be enhanced with more sophisticated logic
    final parts = fullAddress.split(',').map((s) => s.trim()).toList();
    
    return {
      'address': parts.isNotEmpty ? parts[0] : fullAddress,
      'district': parts.length > 1 ? parts[1] : 'Thủ Đức',
      'city': parts.length > 2 ? parts[2] : 'Hồ Chí Minh',
      'postalCode': '70000', // Default postal code
    };
  }

  /// Extract district from address string
  static String _extractDistrict(String address) {
    final districts = ['Thủ Đức', 'Quận 1', 'Quận 2', 'Quận 3', 'Quận 4', 'Quận 5', 
                      'Quận 6', 'Quận 7', 'Quận 8', 'Quận 9', 'Quận 10', 'Quận 11', 'Quận 12',
                      'Tân Bình', 'Tân Phú', 'Bình Thạnh', 'Phú Nhuận', 'Gò Vấp'];
    
    for (final district in districts) {
      if (address.toLowerCase().contains(district.toLowerCase())) {
        return district;
      }
    }
    return 'Thủ Đức'; // Default
  }

  /// Extract city from address string
  static String _extractCity(String address) {
    final cities = ['Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Cần Thơ', 'Hải Phòng'];
    
    for (final city in cities) {
      if (address.toLowerCase().contains(city.toLowerCase())) {
        return city;
      }
    }
    return 'Hồ Chí Minh'; // Default
  }

  /// Test API connection
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/health'),
        headers: _headers,
      );

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'message': response.statusCode == 200 
            ? 'Kết nối GoSHIP API thành công' 
            : 'Lỗi kết nối GoSHIP API',
        'apiUrl': _baseUrl,
        'hasApiKey': _apiKey.isNotEmpty,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Không thể kết nối GoSHIP API',
        'apiUrl': _baseUrl,
        'hasApiKey': _apiKey.isNotEmpty,
      };
    }
  }
}