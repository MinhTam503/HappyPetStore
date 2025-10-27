/// VNPay Configuration
/// IMPORTANT: Thay thế các giá trị này bằng credentials thực tế từ VNPay merchant portal
/// 
/// Để lấy credentials:
/// 1. Đăng ký tại: https://sandbox.vnpayment.vn/devreg
/// 2. Tạo merchant account
/// 3. Lấy TMN Code và Hash Secret từ merchant portal
/// 
/// Security Note: 
/// - Không commit file này vào Git nếu có credentials thật
/// - Sử dụng environment variables hoặc secure storage cho production

class VnpayConfig {
  // Sandbox credentials from VNPay email
  static const String tmnCode = 'DFAZ4N5B';
  static const String hashSecret = '0FZS7UXD47XLQYHGNQRD4ZDUGC9BERI1';
  
  // URLs
  static const String sandboxUrl = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
  static const String sandboxApiUrl = 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction';
  
  // Production URLs (uncomment when ready for production)
  // static const String productionUrl = 'https://vnpayment.vn/paymentv2/vpcpay.html';
  // static const String productionApiUrl = 'https://vnpayment.vn/merchant_webapi/api/transaction';
  
  // Version and command
  static const String version = '2.1.0';
  static const String command = 'pay';
  
  // Return URL - QUAN TRỌNG: Phải là URL mà VNPay chấp nhận
  // VNPay sandbox demo URL (luôn hoạt động cho test):
  static const String returnUrl = 'http://sdk.merchantbackapp';
  
  // Sau khi test thành công, thay bằng URL của bạn:
  // static const String returnUrl = 'https://train-pet-image.onrender.com/vnpay-return';
  
  // Hoặc dùng webhook để xem callback:
  // static const String returnUrl = 'https://webhook.site/YOUR-UNIQUE-ID';
  
  // Helper methods
  static bool get isConfigured {
    // Check if credentials are not default placeholder values
    return tmnCode != 'YOUR_TMN_CODE' && 
           hashSecret != 'YOUR_HASH_SECRET' &&
           tmnCode.isNotEmpty &&
           hashSecret.isNotEmpty;
  }
  
  static String get vnpUrl {
    // Use sandbox URL for now
    // In production, check environment and return appropriate URL
    return sandboxUrl;
  }
  
  static String get vnpApiUrl {
    return sandboxApiUrl;
  }
}
