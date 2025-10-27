import '../entities/vnpay_payment.dart';

/// Abstract repository cho VNPay payment
/// Định nghĩa contract cho payment operations
abstract class VnpayRepository {
  /// Tạo payment URL từ VNPay
  Future<VnpayPayment> createPaymentUrl({
    required String orderId,
    required double amount,
    required String orderInfo,
    required String returnUrl,
  });

  /// Verify payment callback từ VNPay
  Future<VnpayPayment> verifyPayment(Map<String, dynamic> vnpayResponse);

  /// Query payment status từ VNPay
  Future<VnpayPayment> queryPaymentStatus(String orderId);
}
