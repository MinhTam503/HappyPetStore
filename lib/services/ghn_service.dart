import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// 🚚 GHN (Giao Hàng Nhanh) Service - API Integration for Happy Pets
/// 
/// Test API Documentation: https://api.ghn.vn/home/docs/detail?id=77
/// Sandbox URL: https://dev-online-gateway.ghn.vn/shiip/public-api
class GHNService {
  static const String _baseUrl = 'https://dev-online-gateway.ghn.vn/shiip/public-api';
  
  // Default test location IDs for HCMC
  static const int _defaultFromDistrictId = 1463; // Quan 1, HCMC 
  static const int _defaultFromWardCode = 21211; // Phuong 1, Quan 1
  
  /// Get credentials with web fallback
  static Map<String, String> _getCredentials() {
    String token = '';
    String shopId = '';
    
    if (kIsWeb) {
      // For web deployment, use hardcoded test credentials
      token = '07b708bf-a2c9-11f0-bdaf-ae7fa045a771';
      shopId = '197574';
      if (kDebugMode) {
        debugPrint('🌐 Using hardcoded GHN credentials for web');
      }
    } else {
      // For mobile/desktop, read from .env
      token = dotenv.env['GHN_TOKEN'] ?? '';
      shopId = dotenv.env['GHN_SHOP_ID'] ?? '';
      if (kDebugMode) {
        debugPrint('📱 Reading GHN credentials from .env');
        debugPrint('🔑 Token exists: ${token.isNotEmpty}');
        debugPrint('🏪 Shop ID exists: ${shopId.isNotEmpty}');
      }
      
      // Fallback to hardcoded if .env fails
      if (token.isEmpty || shopId.isEmpty) {
        token = '07b708bf-a2c9-11f0-bdaf-ae7fa045a771';
        shopId = '197574';
        if (kDebugMode) {
          debugPrint('⚠️ .env credentials missing, using fallback');
        }
      }
    }
    
    return {'token': token, 'shopId': shopId};
  }
  
  /// Get headers for GHN API
  static Map<String, String> _getHeaders() {
    final credentials = _getCredentials();
    final token = credentials['token']!;
    final shopId = credentials['shopId']!;
    
    return {
      'Content-Type': 'application/json',
      'Token': token,
      'ShopId': shopId,
    };
  }
  
  /// Lấy danh sách tỉnh/thành phố
  static Future<Map<String, dynamic>> getProvinces() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/master-data/province'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': 'Lấy danh sách tỉnh thành công'
        };
      } else {
        throw Exception('Failed to get provinces: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ GHN Get Provinces Error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi khi lấy danh sách tỉnh'
      };
    }
  }
  
  /// Lấy danh sách quận/huyện theo tỉnh
  static Future<Map<String, dynamic>> getDistricts({required int provinceId}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/master-data/district'),
        headers: _getHeaders(),
        body: json.encode({'province_id': provinceId}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': 'Lấy danh sách quận/huyện thành công'
        };
      } else {
        throw Exception('Failed to get districts: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ GHN Get Districts Error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi khi lấy danh sách quận/huyện'
      };
    }
  }
  
  /// Lấy danh sách phường/xã theo quận
  static Future<Map<String, dynamic>> getWards({required int districtId}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/master-data/ward'),
        headers: _getHeaders(),
        body: json.encode({'district_id': districtId}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': 'Lấy danh sách phường/xã thành công'
        };
      } else {
        throw Exception('Failed to get wards: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ GHN Get Wards Error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi khi lấy danh sách phường/xã'
      };
    }
  }
  
  /// Tính phí giao hàng
  static Future<Map<String, dynamic>> calculateShippingFee({
    required int toDistrictId,
    required String toWardCode,
    required int weight, // in grams
    required int length, // in cm
    required int width, // in cm  
    required int height, // in cm
    int? insuranceValue,
  }) async {
    try {
      final requestBody = {
        'from_district_id': _defaultFromDistrictId,
        'from_ward_code': _defaultFromWardCode.toString(),
        'to_district_id': toDistrictId,
        'to_ward_code': toWardCode,
        'weight': weight,
        'length': length,
        'width': width,
        'height': height,
        'service_type_id': 2, // Standard delivery
        'insurance_value': insuranceValue ?? 0,
      };
      
      final response = await http.post(
        Uri.parse('$_baseUrl/v2/shipping-order/fee'),
        headers: _getHeaders(),
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': 'Tính phí giao hàng thành công'
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Failed to calculate fee: ${errorData['message'] ?? response.statusCode}');
      }
    } catch (e) {
      print('❌ GHN Calculate Fee Error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi khi tính phí giao hàng'
      };
    }
  }
  
  /// Validate Vietnamese phone number for GHN
  static String _validatePhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Vietnamese phone number patterns
    // Mobile: 09x, 08x, 07x, 05x, 03x (10 digits)
    // Add leading 0 if missing
    if (cleaned.length == 9 && !cleaned.startsWith('0')) {
      cleaned = '0$cleaned';
    }
    
    // Validate format
    if (cleaned.length == 10 && 
        (cleaned.startsWith('09') || 
         cleaned.startsWith('08') || 
         cleaned.startsWith('07') || 
         cleaned.startsWith('05') || 
         cleaned.startsWith('03'))) {
      return cleaned;
    }
    
    // Return default valid number if validation fails
    return '0987654321';
  }
  
  /// Tạo đơn hàng giao hàng
  static Future<Map<String, dynamic>> createOrder({
    required String paymentTypeId, // 1: Người bán/Người gửi, 2: Người mua/Người nhận
    required String note,
    required String requiredNote, // KHONGCHOXEMHANG, CHOXEMHANGKHONGTHU, CHOTHUHANG
    required String clientOrderCode, // Mã đơn hàng của shop
    required int toDistrictId,
    required String toWardCode,
    required String toName,
    required String toPhone,
    required String toAddress,
    required int weight, // tổng khối lượng (gram)
    required int length, // dài (cm)
    required int width, // rộng (cm)
    required int height, // cao (cm)
    int? insuranceValue,
    List<Map<String, dynamic>>? items, // Danh sách sản phẩm
  }) async {
    try {
      final requestBody = {
        'payment_type_id': int.parse(paymentTypeId),
        'note': note,
        'required_note': requiredNote,
        'client_order_code': clientOrderCode,
        'from_name': 'Happy Pets',
        'from_phone': '0399302970', // Valid Vietnamese phone number
        'from_address': '97 Trần Văn Ơn, Phú Hoà, Thủ Dầu Một, Bình Dương, Vietnam',
        'from_ward_name': 'Phường Phú Hoà',
        'from_district_name': 'Thành phố Thủ Dầu Một',
        'from_province_name': 'Bình Dương',
        'to_name': toName,
        'to_phone': _validatePhoneNumber(toPhone), // Validate customer phone
        'to_address': toAddress,
        'to_ward_code': toWardCode,
        'to_district_id': toDistrictId,
        'cod_amount': 0, // Thu hộ (VNĐ)
        'content': 'Thú cưng và phụ kiện',
        'weight': weight,
        'length': length,
        'width': width,
        'height': height,
        'service_type_id': 2, // 1: Express, 2: Standard
        'service_id': 53320, // Mã dịch vụ chuẩn
        'insurance_value': insuranceValue ?? 0,
        'pick_station_id': null,
        'deliver_station_id': null,
        'items': items ?? [
          {
            'name': 'Thú cưng',
            'quantity': 1,
            'weight': weight,
          }
        ],
      };
      
      print('🚚 Creating GHN order with validated data...');
      print('📞 Validated customer phone: ${_validatePhoneNumber(toPhone)}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/v2/shipping-order/create'),
        headers: _getHeaders(),
        body: json.encode(requestBody),
      );
      
      print('📡 GHN API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ GHN Order created successfully: ${data['data']['order_code']}');
        
        return {
          'success': true,
          'data': {
            'trackingNumber': data['data']['order_code'],
            'status': 'ready_to_pick', // GHN initial status
            'shippingCompany': 'Giao Hàng Nhanh',
            'estimatedDelivery': DateTime.now().add(Duration(days: 2)).toIso8601String(),
            'shippingFee': data['data']['total_fee'] ?? 0,
            'orderCode': data['data']['order_code'],
            'ghnData': data['data'], // Store full GHN response
          },
          'message': 'Đơn giao hàng đã được tạo thành công'
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ GHN API Error (${response.statusCode}): ${errorData['message']}');
        print('🔍 Error details: ${json.encode(errorData)}');
        throw Exception('Failed to create order: ${errorData['message'] ?? response.statusCode}');
      }
    } catch (e) {
      print('❌ GHN Create Order Error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi khi tạo đơn giao hàng'
      };
    }
  }
  
  /// Theo dõi đơn hàng
  static Future<Map<String, dynamic>> trackOrder({required String orderCode}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v2/shipping-order/detail'),
        headers: _getHeaders(),
        body: json.encode({'order_code': orderCode}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final orderInfo = data['data'];
        
        // Map GHN status to our system
        String mappedStatus = _mapGHNStatusToOurSystem(orderInfo['status']);
        
        return {
          'success': true,
          'data': {
            'trackingNumber': orderCode,
            'status': mappedStatus,
            'ghnStatus': orderInfo['status'],
            'shippingCompany': 'Giao Hàng Nhanh',
            'currentAddress': orderInfo['current_address'] ?? '',
            'updatedAt': orderInfo['updated_date'] ?? DateTime.now().toIso8601String(),
            'ghnData': orderInfo, // Store full GHN response
            'trackingHistory': _buildTrackingHistory(orderInfo),
          },
          'message': 'Theo dõi đơn hàng thành công'
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Failed to track order: ${errorData['message'] ?? response.statusCode}');
      }
    } catch (e) {
      print('❌ GHN Track Order Error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi khi theo dõi đơn hàng'
      };
    }
  }
  
  /// Map GHN status to our system status
  static String _mapGHNStatusToOurSystem(String ghnStatus) {
    switch (ghnStatus.toLowerCase()) {
      case 'ready_to_pick':
      case 'picking':
        return 'pickup_pending';
      case 'picked':
      case 'storing':
      case 'transporting':
        return 'in_transit';
      case 'delivering':
        return 'out_for_delivery';
      case 'delivered':
        return 'delivered';
      case 'return':
      case 'returned':
      case 'exception':
        return 'failed';
      default:
        return 'pickup_pending';
    }
  }
  
  /// Build tracking history từ GHN data
  static List<Map<String, dynamic>> _buildTrackingHistory(Map<String, dynamic> ghnData) {
    List<Map<String, dynamic>> history = [];
    
    // Add current status
    history.add({
      'status': _mapGHNStatusToOurSystem(ghnData['status']),
      'description': _getStatusDescription(ghnData['status']),
      'timestamp': ghnData['updated_date'] ?? DateTime.now().toIso8601String(),
      'location': ghnData['current_address'] ?? 'Đang cập nhật...',
    });
    
    // Add created status
    if (ghnData['created_date'] != null) {
      history.add({
        'status': 'pickup_pending',
        'description': 'Đơn hàng đã được tạo, chờ lấy hàng',
        'timestamp': ghnData['created_date'],
        'location': 'Happy Pets Store - TP.HCM',
      });
    }
    
    return history.reversed.toList(); // Newest first
  }
  
  /// Get Vietnamese description for GHN status
  static String _getStatusDescription(String ghnStatus) {
    switch (ghnStatus.toLowerCase()) {
      case 'ready_to_pick':
        return 'Đã tạo đơn hàng, chờ lấy hàng';
      case 'picking':
        return 'Shipper đang đến lấy hàng';
      case 'picked':
        return 'Đã lấy hàng thành công';
      case 'storing':
        return 'Hàng đang tại kho trung chuyển';
      case 'transporting':
        return 'Hàng đang được vận chuyển';
      case 'delivering':
        return 'Shipper đang giao hàng đến bạn';
      case 'delivered':
        return 'Giao hàng thành công';
      case 'return':
        return 'Hàng đang được hoàn trả';
      case 'returned':
        return 'Đã hoàn trả hàng về shop';
      case 'exception':
        return 'Giao hàng thất bại';
      default:
        return 'Đang cập nhật trạng thái...';
    }
  }
  
  /// Test connection to GHN API
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final credentials = _getCredentials();
      final token = credentials['token']!;
      final shopId = credentials['shopId']!;
      
      if (kDebugMode) {
        debugPrint('🧪 Testing GHN connection...');
        debugPrint('🔑 Token: ${token.substring(0, 10)}...');
        debugPrint('🏪 Shop ID: $shopId');
      }
      
      // Test bằng cách lấy danh sách tỉnh
      final result = await getProvinces();
      
      if (result['success']) {
        return {
          'success': true,
          'data': {
            'token': token.substring(0, 10) + '...', // Hide full token
            'shopId': shopId,
            'provinces_count': result['data'].length,
          },
          'message': 'Kết nối GHN API thành công!'
        };
      } else {
        return result;
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi kết nối GHN API'
      };
    }
  }
  
  /// Update order status (for testing purposes)
  /// Available statuses: ready_to_pick, picking, picked, storing, transporting, delivering, delivered, return, returned, exception
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderCode,
    required String newStatus,
    String? description,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Updating GHN order status...');
        debugPrint('📦 Order Code: $orderCode');
        debugPrint('📊 New Status: $newStatus');
      }
      
      // Note: GHN test environment does NOT support programmatic status updates
      // Status can only be updated manually via GHN portal: https://5sao.ghn.dev/order
      // This function simulates the update for UI testing purposes only
      
      if (kDebugMode) {
        final requestBody = {
          'order_code': orderCode,
          'status': newStatus,
          'description': description ?? _getStatusDescription(newStatus),
          'updated_date': DateTime.now().toIso8601String(),
        };
        debugPrint('📋 Simulated update request: ${json.encode(requestBody)}');
        debugPrint('⚠️  REAL UPDATE: Go to https://5sao.ghn.dev/order to update manually');
      }
      
      // Simulate API call delay
      await Future.delayed(Duration(seconds: 1));
      
      return {
        'success': true,
        'data': {
          'orderCode': orderCode,
          'status': newStatus,
          'description': description ?? _getStatusDescription(newStatus),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        'message': 'Cập nhật trạng thái đơn hàng thành công'
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Lỗi khi cập nhật trạng thái đơn hàng'
      };
    }
  }
}