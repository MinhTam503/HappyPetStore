import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../core/config/vnpay_config.dart';

/// VNPay Service để xử lý API integration
/// Đây là datasource trong Clean Architecture
class VnpayService {
  // Use config values
  static String get _vnpTmnCode => VnpayConfig.tmnCode;
  static String get _vnpHashSecret => VnpayConfig.hashSecret;
  static String get _vnpUrl => VnpayConfig.vnpUrl;
  static String get _vnpApiUrl => VnpayConfig.vnpApiUrl;
  static const String _vnpVersion = '2.1.0';
  static const String _vnpCommand = 'pay';

  /// Tạo payment URL để redirect user tới VNPay
  Future<Map<String, dynamic>> createPaymentUrl({
    required String orderId,
    required double amount,
    required String orderInfo,
    required String ipAddress,
    required String returnUrl,
  }) async {
    try {
      // Validate credentials first
      if (!VnpayConfig.isConfigured) {
        throw Exception(
          'VNPay chưa được cấu hình. Vui lòng cập nhật TMN Code và Hash Secret trong vnpay_config.dart'
        );
      }

      print('🔧 VNPay Config:');
      print('  - TMN Code: ${_vnpTmnCode.substring(0, 4)}****');
      print('  - URL: $_vnpUrl');
      print('  - Return URL: $returnUrl');
      
      // Chuyển đổi amount sang đơn vị VNPay yêu cầu (VNDx100)
      final vnpAmount = (amount * 100).toInt();
      
      print('💰 Payment Details:');
      print('  - Order ID: $orderId');
      print('  - Amount: $amount VND');
      print('  - VNP Amount: $vnpAmount');
      
  // Tạo timestamp theo GMT+7 (theo tài liệu VNPay)
  final now = DateTime.now();
  final vnpCreateDate = _formatDateTime(now);
  // Thiết lập thời gian hết hạn thanh toán (ví dụ: +15 phút)
  final vnpExpireDate = _formatDateTime(now.add(const Duration(minutes: 15)));

      // Build payment parameters
      final params = <String, String>{
        'vnp_Version': _vnpVersion,
        'vnp_Command': _vnpCommand,
        'vnp_TmnCode': _vnpTmnCode,
        'vnp_Amount': vnpAmount.toString(),
        'vnp_CurrCode': 'VND',
        'vnp_TxnRef': orderId,
        'vnp_OrderInfo': orderInfo,
        'vnp_OrderType': 'other', // Loại hàng hóa
        'vnp_Locale': 'vn', // Ngôn ngữ
        'vnp_ReturnUrl': returnUrl,
        'vnp_IpAddr': ipAddress,
  'vnp_CreateDate': vnpCreateDate,
  'vnp_ExpireDate': vnpExpireDate,
  // KHÔNG thêm vnp_SecureHashType vào params (nó không được hash)
      };

      print('📋 Payment params created: ${params.length} parameters');
      print('📋 Params: $params');

      // Sort params theo alphabet và tạo query string
      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );

      // Tạo secure hash - QUAN TRỌNG: URL encode trước khi hash (theo PHP demo của VNPay)
      final secureHash = _createSecureHash(sortedParams);
      print('🔐 Secure hash generated: ${secureHash.substring(0, 8)}...');
      print('🔐 Full hash: $secureHash');
      
      // Tạo payment URL - query string giống như hash data
    final queryString = sortedParams.entries
      .map((e) => '${_phpUrlEncode(e.key)}=${_phpUrlEncode(e.value)}')
          .join('&');
      
      // Append SecureHash ONLY (không cần vnp_SecureHashType theo PHP demo)
      final paymentUrl = '$_vnpUrl?$queryString&vnp_SecureHash=$secureHash';

      print('✅ VNPay Payment URL created successfully for order: $orderId');
      print('🌐 URL length: ${paymentUrl.length} characters');
      
      // Debug: Print full URL (cẩn thận với production!)
      if (paymentUrl.length < 1000) {
        print('🌐 Full URL:\n$paymentUrl');
      } else {
        print('🌐 URL preview: ${paymentUrl.substring(0, 500)}...[truncated]');
      }
      
      return {
        'paymentUrl': paymentUrl,
        'orderId': orderId,
        'amount': amount,
        'vnp_TxnRef': orderId,
        'vnp_Amount': vnpAmount.toString(),
        'vnp_OrderInfo': orderInfo,
        'createdAt': now.toIso8601String(),
      };
    } catch (e, stackTrace) {
      print('❌ Error creating VNPay payment URL: $e');
      print('📚 Stack trace: $stackTrace');
      throw Exception('Không thể tạo link thanh toán VNPay: $e');
    }
  }

  /// Verify callback từ VNPay sau khi user thanh toán
  Future<Map<String, dynamic>> verifyPaymentCallback(
    Map<String, dynamic> vnpayParams
  ) async {
    try {
      // Lấy secure hash từ params
      final receivedHash = vnpayParams['vnp_SecureHash'];
      
      // Loại bỏ hash và hash type khỏi params để verify
      final paramsToVerify = Map<String, String>.from(vnpayParams);
      paramsToVerify.remove('vnp_SecureHash');
      paramsToVerify.remove('vnp_SecureHashType');

      // Sort params
      final sortedParams = Map.fromEntries(
        paramsToVerify.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );

      // Tạo secure hash để so sánh
      final calculatedHash = _createSecureHash(sortedParams);

      // Verify hash
      if (calculatedHash != receivedHash) {
        throw Exception('Invalid VNPay signature');
      }

      // Parse response
      final responseCode = vnpayParams['vnp_ResponseCode'] ?? '';
      final transactionNo = vnpayParams['vnp_TransactionNo'];
      final orderId = vnpayParams['vnp_TxnRef'];
      final amount = double.tryParse(
        (vnpayParams['vnp_Amount'] ?? '0').toString()
      ) ?? 0.0;

      print('✅ VNPay payment verified: $orderId - Response: $responseCode');

      return {
        'vnp_ResponseCode': responseCode,
        'vnp_TransactionNo': transactionNo,
        'vnp_TxnRef': orderId,
        'vnp_Amount': (amount / 100).toString(), // Convert back to VND
        'vnp_OrderInfo': vnpayParams['vnp_OrderInfo'],
        'isSuccess': responseCode == '00',
        'createdAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error verifying VNPay payment: $e');
      throw Exception('Không thể xác thực thanh toán VNPay: $e');
    }
  }

  /// Query payment status từ VNPay API
  Future<Map<String, dynamic>> queryPaymentStatus({
    required String orderId,
    required String transactionDate,
  }) async {
    try {
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final params = <String, String>{
        'vnp_Version': _vnpVersion,
        'vnp_Command': 'querydr',
        'vnp_TmnCode': _vnpTmnCode,
        'vnp_TxnRef': orderId,
        'vnp_OrderInfo': 'Query for $orderId',
        'vnp_TransactionDate': transactionDate,
        'vnp_CreateDate': _formatDateTime(DateTime.now()),
        'vnp_IpAddr': '127.0.0.1',
        'vnp_RequestId': requestId,
      };

      // Sort và tạo secure hash
      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      
      final secureHash = _createSecureHash(sortedParams);
      params['vnp_SecureHash'] = secureHash;

      // Call API
      final response = await http.post(
        Uri.parse(_vnpApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(params),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ VNPay query status success: $orderId');
        return responseData;
      } else {
        throw Exception('VNPay API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error querying VNPay status: $e');
      throw Exception('Không thể truy vấn trạng thái thanh toán: $e');
    }
  }

  /// Tạo secure hash SHA512 theo CHÍNH XÁC PHP demo của VNPay
  /// Quan trọng: URL encode cả key và value trước khi hash (giống PHP: urlencode($key) . "=" . urlencode($value))
  String _createSecureHash(Map<String, String> params) {
    // Build hash data với URL encoding giống PHP demo
  final hashData = params.entries
    .map((e) => '${_phpUrlEncode(e.key)}=${_phpUrlEncode(e.value)}')
        .join('&');
    
    print('🔐 Hash data (before HMAC): $hashData');
    
    // HMAC SHA512 giống PHP: hash_hmac('sha512', $hashdata, $vnp_HashSecret)
    final hmacSha512 = Hmac(sha512, utf8.encode(_vnpHashSecret));
    final digest = hmacSha512.convert(utf8.encode(hashData));
    
    return digest.toString().toLowerCase(); // PHP trả về lowercase
  }

  /// Format datetime theo yêu cầu VNPay: yyyyMMddHHmmss (GMT+7)
  String _formatDateTime(DateTime dateTime) {
    // Chuyển sang GMT+7 theo tài liệu VNPay
    final vnTime = dateTime.toUtc().add(const Duration(hours: 7));
    final y = vnTime.year.toString().padLeft(4, '0');
    final mo = vnTime.month.toString().padLeft(2, '0');
    final d = vnTime.day.toString().padLeft(2, '0');
    final h = vnTime.hour.toString().padLeft(2, '0');
    final mi = vnTime.minute.toString().padLeft(2, '0');
    final s = vnTime.second.toString().padLeft(2, '0');
    return '$y$mo$d$h$mi$s';
  }

  /// URL encode giống PHP's urlencode (khác với rawurlencode): khoảng trắng -> '+'
  String _phpUrlEncode(String input) {
    return Uri.encodeQueryComponent(input).replaceAll('%20', '+');
  }
}
