import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentService {
  // URL của backend Python
  static const String _baseUrl = 'https://train-pet-image.onrender.com';
  
  // Timeout configuration
  static const Duration _timeout = Duration(seconds: 30);

  /// Tạo payment intent
  static Future<Map<String, dynamic>?> createPaymentIntent({
    required double amount,
    String currency = 'usd',
  }) async {
    try {
      print('💳 Creating payment intent: $amount $currency');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/payment/create-intent'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (amount * 100).round(), // Convert to cents
          'currency': currency,
        }),
      ).timeout(_timeout);

      print('📡 Payment Intent Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print(' Payment intent created successfully');
        return result;
      } else {
        print(' Error creating payment intent: ${response.statusCode}');
        print(' Response body: ${response.body}');
        
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error'] ?? 'Unknown error';
          print(' Detailed error: $errorMessage');
        } catch (e) {
          print(' Raw error: ${response.body}');
        }
        
        return null;
      }
    } catch (e) {
      print(' Exception creating payment intent: $e');
      return null;
    }
  }

  /// Xác nhận thanh toán và lưu đơn hàng
  static Future<Map<String, dynamic>?> confirmPayment({
    required String paymentIntentId,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment/confirm'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'payment_intent_id': paymentIntentId,
          'order_data': orderData,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error confirming payment: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception confirming payment: $e');
      return null;
    }
  }

  /// Lấy danh sách đơn hàng
  static Future<List<Map<String, dynamic>>?> getOrders({String? email}) async {
    try {
      String url = '$_baseUrl/payment/orders';
      if (email != null && email.isNotEmpty) {
        url += '?email=${Uri.encodeComponent(email)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['orders'] ?? []);
      } else {
        print('Error getting orders: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception getting orders: $e');
      return null;
    }
  }

  /// Lấy thông tin đơn hàng theo ID
  static Future<Map<String, dynamic>?> getOrder(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payment/orders/${Uri.encodeComponent(orderId)}'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error getting order: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception getting order: $e');
      return null;
    }
  }

  /// Kiểm tra trạng thái backend
  static Future<bool> isBackendHealthy() async {
    try {
      print(' Checking backend health...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print(' Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('Backend health check successful!');
        try {
          final data = jsonDecode(response.body);
          print(' Backend info: ${data['status']} - ${data['mode']}');
        } catch (e) {
          print(' Response body: ${response.body}');
        }
        return true;
      } else {
        print(' Unexpected status code: ${response.statusCode}');
        print(' Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print(' Health check failed: $e');
      return false;
    }
  }

  /// Tạo Stripe Checkout Session (cho web)
  static Future<Map<String, dynamic>?> createCheckoutSession({
    required double amount,
    String currency = 'usd',
    required Map<String, dynamic> customerInfo,
    required List<Map<String, dynamic>> items,
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      print(' Creating Stripe Checkout session: $amount $currency');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/payment/create-checkout-session'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (amount * 100).round(), // Convert to cents
          'currency': currency,
          'customer_info': customerInfo,
          'items': items,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
          'metadata': {
            'source': 'flutter_web_checkout',
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      ).timeout(_timeout);

      print('📡 Checkout Session Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print(' Checkout session created successfully');
        print(' Checkout URL: ${result['checkout_url']}');
        return result;
      } else {
        print(' Error creating checkout session: ${response.statusCode}');
        print(' Response body: ${response.body}');
        
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error'] ?? 'Unknown error';
          print(' Detailed error: $errorMessage');
        } catch (e) {
          print(' Raw error: ${response.body}');
        }
        
        return null;
      }
    } catch (e) {
      print(' Exception creating checkout session: $e');
      return null;
    }
  }

  /// Lấy URL hiện tại đang sử dụng (cho debugging)
  static String getCurrentBaseUrl() => _baseUrl;
}
