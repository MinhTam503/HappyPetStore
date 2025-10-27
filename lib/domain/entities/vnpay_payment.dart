import 'package:equatable/equatable.dart';

/// Domain entity cho VNPay payment
/// Đại diện cho thông tin thanh toán VNPay trong domain layer
class VnpayPayment extends Equatable {
  final String orderId;
  final double amount;
  final String orderInfo;
  final String? paymentUrl;
  final String? transactionNo;
  final String? responseCode;
  final DateTime createdAt;

  const VnpayPayment({
    required this.orderId,
    required this.amount,
    required this.orderInfo,
    this.paymentUrl,
    this.transactionNo,
    this.responseCode,
    required this.createdAt,
  });

  bool get isSuccess => responseCode == '00';

  @override
  List<Object?> get props => [
        orderId,
        amount,
        orderInfo,
        paymentUrl,
        transactionNo,
        responseCode,
        createdAt,
      ];
}
