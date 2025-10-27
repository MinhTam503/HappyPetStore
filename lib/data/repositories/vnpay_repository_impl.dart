import '../../domain/entities/vnpay_payment.dart';
import '../../domain/repositories/vnpay_repository.dart';
import '../datasources/vnpay_service.dart';
import '../models/vnpay_payment_model.dart';

/// Implementation của VnpayRepository
/// Kết nối domain layer với data layer
class VnpayRepositoryImpl implements VnpayRepository {
  final VnpayService _vnpayService;

  VnpayRepositoryImpl(this._vnpayService);

  @override
  Future<VnpayPayment> createPaymentUrl({
    required String orderId,
    required double amount,
    required String orderInfo,
    required String returnUrl,
  }) async {
    try {
      // Get IP address (fallback to localhost for mobile apps)
      String ipAddress = '127.0.0.1';
      try {
        // Try to get real IP (this will work on web)
        // For mobile, we'll use default
        ipAddress = '127.0.0.1';
      } catch (e) {
        print('⚠️ Could not get IP, using default: $ipAddress');
      }

      print('🌐 Using IP address: $ipAddress');

      final result = await _vnpayService.createPaymentUrl(
        orderId: orderId,
        amount: amount,
        orderInfo: orderInfo,
        ipAddress: ipAddress,
        returnUrl: returnUrl,
      );

      final model = VnpayPaymentModel.fromJson(result);
      return model.toEntity();
    } catch (e) {
      print('❌ Repository error creating payment: $e');
      rethrow;
    }
  }

  @override
  Future<VnpayPayment> verifyPayment(Map<String, dynamic> vnpayResponse) async {
    try {
      final result = await _vnpayService.verifyPaymentCallback(vnpayResponse);
      
      final model = VnpayPaymentModel.fromJson(result);
      return model.toEntity();
    } catch (e) {
      print('❌ Repository error verifying payment: $e');
      rethrow;
    }
  }

  @override
  Future<VnpayPayment> queryPaymentStatus(String orderId) async {
    try {
      // Format transaction date (yyyyMMddHHmmss)
      final now = DateTime.now();
      final transactionDate = now.toIso8601String()
          .replaceAll(RegExp(r'[-:.]'), '')
          .substring(0, 14);

      final result = await _vnpayService.queryPaymentStatus(
        orderId: orderId,
        transactionDate: transactionDate,
      );

      final model = VnpayPaymentModel.fromJson(result);
      return model.toEntity();
    } catch (e) {
      print('❌ Repository error querying payment status: $e');
      rethrow;
    }
  }
}
