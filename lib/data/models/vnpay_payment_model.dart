import '../../domain/entities/vnpay_payment.dart';

/// Data model cho VNPay payment
/// Chuyển đổi giữa domain entity và JSON
class VnpayPaymentModel extends VnpayPayment {
  const VnpayPaymentModel({
    required super.orderId,
    required super.amount,
    required super.orderInfo,
    super.paymentUrl,
    super.transactionNo,
    super.responseCode,
    required super.createdAt,
  });

  /// Tạo model từ domain entity
  factory VnpayPaymentModel.fromEntity(VnpayPayment entity) {
    return VnpayPaymentModel(
      orderId: entity.orderId,
      amount: entity.amount,
      orderInfo: entity.orderInfo,
      paymentUrl: entity.paymentUrl,
      transactionNo: entity.transactionNo,
      responseCode: entity.responseCode,
      createdAt: entity.createdAt,
    );
  }

  /// Tạo model từ JSON (response từ VNPay)
  factory VnpayPaymentModel.fromJson(Map<String, dynamic> json) {
    return VnpayPaymentModel(
      orderId: json['vnp_TxnRef'] ?? '',
      amount: double.tryParse(json['vnp_Amount']?.toString() ?? '0') ?? 0.0,
      orderInfo: json['vnp_OrderInfo'] ?? '',
      paymentUrl: json['paymentUrl'],
      transactionNo: json['vnp_TransactionNo'],
      responseCode: json['vnp_ResponseCode'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  /// Chuyển đổi sang JSON
  Map<String, dynamic> toJson() {
    return {
      'vnp_TxnRef': orderId,
      'vnp_Amount': (amount * 100).toInt().toString(), // VNPay yêu cầu amount * 100
      'vnp_OrderInfo': orderInfo,
      'paymentUrl': paymentUrl,
      'vnp_TransactionNo': transactionNo,
      'vnp_ResponseCode': responseCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Chuyển đổi sang domain entity
  VnpayPayment toEntity() {
    return VnpayPayment(
      orderId: orderId,
      amount: amount,
      orderInfo: orderInfo,
      paymentUrl: paymentUrl,
      transactionNo: transactionNo,
      responseCode: responseCode,
      createdAt: createdAt,
    );
  }
}
