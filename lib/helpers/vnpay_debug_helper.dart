import 'dart:convert';
import 'package:crypto/crypto.dart';

/// VNPay URL Debug Helper
/// Dùng để test và verify VNPay payment URL
class VnpayDebugHelper {
  /// Test VNPay URL generation với credentials
  static void testUrlGeneration({
    required String tmnCode,
    required String hashSecret,
    required String orderId,
    required double amount,
  }) {
    print('\n========== VNPAY DEBUG TEST ==========');
    print('TMN Code: $tmnCode');
    print('Order ID: $orderId');
    print('Amount: $amount VND');
    print('Amount (x100): ${(amount * 100).toInt()}');
    
    final now = DateTime.now();
    final createDate = _formatDateTime(now);
    
    // Build params exactly like VNPay docs
    final params = <String, String>{
      'vnp_Amount': ((amount * 100).toInt()).toString(),
      'vnp_Command': 'pay',
      'vnp_CreateDate': createDate,
      'vnp_CurrCode': 'VND',
      'vnp_IpAddr': '127.0.0.1',
      'vnp_Locale': 'vn',
      'vnp_OrderInfo': 'Thanh toan don hang $orderId',
      'vnp_OrderType': 'other',
      'vnp_ReturnUrl': 'https://yourdomain.com/return',
      'vnp_TmnCode': tmnCode,
      'vnp_TxnRef': orderId,
      'vnp_Version': '2.1.0',
    };
    
    print('\n📋 Parameters (unsorted):');
    params.forEach((key, value) {
      print('  $key = $value');
    });
    
    // Sort
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    print('\n📋 Parameters (sorted):');
    sortedParams.forEach((key, value) {
      print('  $key = $value');
    });
    
    // Create hash data string
    final hashData = sortedParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    print('\n🔐 Hash data string:');
    print(hashData);
    
    // Generate secure hash
    final hmacSha256 = Hmac(sha256, utf8.encode(hashSecret));
    final digest = hmacSha256.convert(utf8.encode(hashData));
    final secureHash = digest.toString();
    
    print('\n🔐 Secure Hash (SHA256):');
    print(secureHash);
    
    // Build URL
    final queryString = sortedParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    final url = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?$queryString&vnp_SecureHash=$secureHash';
    
    print('\n🌐 Complete URL:');
    print(url);
    print('\n========== END DEBUG ==========\n');
  }
  
  /// Format datetime: yyyyMMddHHmmss
  static String _formatDateTime(DateTime dateTime) {
    return dateTime.toIso8601String()
        .replaceAll(RegExp(r'[-:.]'), '')
        .substring(0, 14);
  }
  
  /// Verify secure hash từ VNPay response
  static bool verifyHash({
    required Map<String, String> params,
    required String hashSecret,
    required String receivedHash,
  }) {
    print('\n========== VERIFY HASH ==========');
    
    final paramsToVerify = Map<String, String>.from(params);
    paramsToVerify.remove('vnp_SecureHash');
    paramsToVerify.remove('vnp_SecureHashType');
    
    final sortedParams = Map.fromEntries(
      paramsToVerify.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    final hashData = sortedParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    print('Hash data: $hashData');
    
    final hmacSha256 = Hmac(sha256, utf8.encode(hashSecret));
    final digest = hmacSha256.convert(utf8.encode(hashData));
    final calculatedHash = digest.toString();
    
    print('Received hash:   $receivedHash');
    print('Calculated hash: $calculatedHash');
    print('Match: ${receivedHash == calculatedHash}');
    print('========== END VERIFY ==========\n');
    
    return receivedHash == calculatedHash;
  }
}
