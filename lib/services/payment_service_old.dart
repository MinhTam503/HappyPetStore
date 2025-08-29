import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

class PaymentService {
  // URL của backend Python
  static const String _baseUrl = 'https://train-pet-image.onrender.com';
  
  // Configuration variables
  static bool _useProduction = true;
  static bool _useCorsProxy = false;
  
  // Timeout configuration
  static const Duration _timeout = Duration(seconds: 30);
  
  /// Switch giữa production và local URLs
  static void useProduction(bool use) {
    _useProduction = use;
    print('🔄 Switched to ${use ? 'PRODUCTION' : 'LOCAL'} backend: ${_baseUrl}');
  }
  
  /// Check URL hiện tại
  static bool get isUsingProduction => _useProduction;
  
    /// Tạo payment intent sử dụng browser fetch API
  static Future<Map<String, dynamic>?> createPaymentIntentWithFetch({
    required double amount,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('💳 Creating payment intent with fetch: $amount $currency');
      
      final body = jsonEncode({
        'amount': (amount * 100).round(), // Convert to cents
        'currency': currency,
        'metadata': metadata ?? {},
      });
      
      final response = await html.window.fetch('$_baseUrl/payment/create-intent', {
        'method': 'POST',
        'headers': {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        'body': body,
        'mode': 'cors',
      });
      
      final responseText = await response.text();
      
      if (response.ok) {
        final result = jsonDecode(responseText);
        print('✅ Payment intent created successfully with fetch');
        return result;
      } else {
        print('❌ Error creating payment intent with fetch: ${response.status}');
        print('📄 Response body: $responseText');
        return null;
      }
    } catch (e) {
      print('❌ Exception creating payment intent with fetch: $e');
      return null;
    }
  }

  /// Tạo payment intent - thử cả HTTP client và fetch
  static Future<Map<String, dynamic>?> createPaymentIntent({
    required double amount,
    String currency = 'usd',
  }) async {
    print('� Creating payment intent: $amount $currency');
    
    // Thử với HTTP client trước
    try {
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

      print('📡 Payment Intent Response (HTTP): ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('✅ Payment intent created successfully with HTTP client');
        return result;
      } else {
        print('❌ HTTP client failed: ${response.statusCode}');
        print('📄 Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP client exception: $e');
    }
    
    // Nếu HTTP client thất bại, thử với browser fetch
    print('� Fallback to browser fetch...');
    return await createPaymentIntentWithFetch(
      amount: amount,
      currency: currency,
    );
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
        final data = jsonDecode(response.body);
        return data['order'];
      } else {
        print('Error getting order: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception getting order: $e');
      return null;
    }
  }

  /// Kiểm tra trạng thái backend với retry mechanism
  static Future<bool> isBackendHealthy() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔍 Health check attempt $attempt/$maxRetries at: $_baseUrl/status');
        
        final response = await http.get(
          Uri.parse('$_baseUrl/status'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'PetShop-Flutter-App/1.0',
          },
        ).timeout(Duration(seconds: 10 + (attempt * 5))); // Increase timeout each retry

        print('📡 Response status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          print('✅ Backend health check successful!');
          try {
            final data = jsonDecode(response.body);
            print('📄 Backend info: ${data['status']} - ${data['mode']}');
          } catch (e) {
            print('📄 Response body: ${response.body}');
          }
          return true;
        } else {
          print('⚠️ Unexpected status code: ${response.statusCode}');
          print('📄 Response: ${response.body}');
        }
        
      } catch (e) {
        print('❌ Health check attempt $attempt failed: $e');
        
        if (attempt == maxRetries) {
          // Nếu thất bại lần cuối, chạy comprehensive test
          print('🔧 Running comprehensive connection test...');
          final results = await testAllConnections();
          print('📊 Connection test results:');
          results.forEach((url, result) {
            print('  $url: ${result['status']} ${result['status'] == 'success' ? '(${result['code']})' : '- ${result['error']}'}');
          });
        } else {
          print('⏳ Waiting ${retryDelay.inSeconds}s before retry...');
          await Future.delayed(retryDelay);
        }
      }
    }
    
    print('❌ All health check attempts failed');
    print('🔗 URL: $_baseUrl/status');
    return false;
  }

  /// Lấy thông tin backend
  static Future<Map<String, dynamic>?> getBackendInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/status'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('Failed to get backend info: $e');
      return null;
    }
  }

  /// Test với nhiều mode khác nhau
  static Future<Map<String, dynamic>> testMultipleModes() async {
    final results = <String, dynamic>{};
    
    // Test 1: Direct connection
    _useCorsProxy = false;
    _useProduction = true;
    results['Direct HTTPS'] = await _testSingleConnection();
    
    // Test 2: With CORS proxy
    _useCorsProxy = true;
    results['CORS Proxy'] = await _testSingleConnection();
    
    // Reset to default
    _useCorsProxy = false;
    _useProduction = true;
    
    return results;
  }
  
  static Future<Map<String, dynamic>> _testSingleConnection() async {
    try {
      print('🔍 Testing: $_baseUrl/status');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      return {
        'status': 'success',
        'code': response.statusCode,
        'body': response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body,
      };
    } catch (e) {
      return {
        'status': 'failed',
        'error': e.toString(),
      };
    }
  }

  /// Test kết nối với browser fetch API (bypass Flutter HTTP)
  static Future<Map<String, dynamic>> testWithFetch(String url) async {
    try {
      print('🌐 Testing with browser fetch: $url');
      
      final response = await html.window.fetch('$url/status', {
        'method': 'GET',
        'headers': {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        'mode': 'cors',
      });
      
      if (response.ok) {
        final text = await response.text();
        return {
          'status': 'success',
          'code': response.status,
          'body': text.length > 200 ? '${text.substring(0, 200)}...' : text,
        };
      } else {
        return {
          'status': 'failed',
          'error': 'HTTP ${response.status}: ${response.statusText}',
        };
      }
    } catch (e) {
      return {
        'status': 'failed',
        'error': e.toString(),
      };
    }
  }

  /// Test kết nối với nhiều URLs khác nhau
  static Future<Map<String, dynamic>> testAllConnections() async {
    final results = <String, dynamic>{};
    
    final testUrls = [
      'https://train-pet-image.onrender.com',
      'http://localhost:5000',
      'http://127.0.0.1:5000',
    ];
    
    for (final url in testUrls) {
      print('🔍 Testing connection to: $url');
      
      // Test với HTTP client
      try {
        final response = await http.get(
          Uri.parse('$url/status'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));
        
        results['$url (HTTP client)'] = {
          'status': 'success',
          'code': response.statusCode,
          'body': response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body,
        };
        
        print('✅ $url (HTTP): ${response.statusCode}');
        
      } catch (e) {
        results['$url (HTTP client)'] = {
          'status': 'failed',
          'error': e.toString(),
        };
        print('❌ $url (HTTP): $e');
      }
      
      // Test với browser fetch (chỉ cho HTTPS)
      if (url.startsWith('https://')) {
        final fetchResult = await testWithFetch(url);
        results['$url (Browser fetch)'] = fetchResult;
        print('${fetchResult['status'] == 'success' ? '✅' : '❌'} $url (Fetch): ${fetchResult['status']}');
      }
    }
    
    return results;
  }

  /// Lấy URL hiện tại đang sử dụng (cho debugging)
  static String getCurrentBaseUrl() => _baseUrl;
}
