import '../entities/vnpay_payment.dart';
import '../repositories/vnpay_repository.dart';

/// Use case: Verify payment callback từ VNPay
class VerifyVnpayPayment {
  final VnpayRepository repository;

  VerifyVnpayPayment(this.repository);

  Future<VnpayPayment> call(Map<String, dynamic> vnpayResponse) async {
    // Validate response
    if (vnpayResponse.isEmpty) {
      throw Exception('VNPay response không hợp lệ');
    }
    if (!vnpayResponse.containsKey('vnp_SecureHash')) {
      throw Exception('Thiếu secure hash trong response');
    }

    return await repository.verifyPayment(vnpayResponse);
  }
}
