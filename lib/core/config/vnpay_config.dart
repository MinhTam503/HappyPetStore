class VnpayConfig {
  static const String tmnCode = 'UN6RX8AX';
  static const String hashSecret = 'LAXB1JHRK66SJ4TWWTW2Q06AQZC5E5U8';
  
  // URLs
  static const String sandboxUrl = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
  static const String sandboxApiUrl = 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction';
  
  // Version and command
  static const String version = '2.1.0';
  static const String command = 'pay';
  

  static const String returnUrl = 'https://adopt-pet-d1c88.web.app/';

  
  // Helper methods
  static bool get isConfigured {
    // Check if credentials are not default placeholder values
    return tmnCode != 'YOUR_TMN_CODE' && 
           hashSecret != 'YOUR_HASH_SECRET' &&
           tmnCode.isNotEmpty &&
           hashSecret.isNotEmpty;
  }
  
  static String get vnpUrl {
    return sandboxUrl;
  }
  
  static String get vnpApiUrl {
    return sandboxApiUrl;
  }
}
