import '../entities/vnpay_payment.dart';
import '../repositories/vnpay_repository.dart';

/// Use case: Tạo payment URL từ VNPay
class CreateVnpayPaymentUrl {
  final VnpayRepository repository;

  CreateVnpayPaymentUrl(this.repository);

  Future<VnpayPayment> call({
    required String orderId,
    required double amount,
    required String orderInfo,
    required String returnUrl,
  }) async {
    // Validate input
    if (orderId.isEmpty) {
      throw Exception('Order ID không được để trống');
    }
    if (amount <= 0) {
      throw Exception('Số tiền phải lớn hơn 0');
    }
    if (returnUrl.isEmpty) {
      throw Exception('Return URL không được để trống');
    }

    return await repository.createPaymentUrl(
      orderId: orderId,
      amount: amount,
      orderInfo: orderInfo,
      returnUrl: returnUrl,
    );
  }
}
