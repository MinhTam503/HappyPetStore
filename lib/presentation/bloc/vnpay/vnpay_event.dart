import 'package:equatable/equatable.dart';

/// Events cho VNPay payment BLoC
abstract class VnpayEvent extends Equatable {
  const VnpayEvent();

  @override
  List<Object?> get props => [];
}

/// Event: Tạo payment URL
class CreateVnpayPayment extends VnpayEvent {
  final String orderId;
  final double amount;
  final String orderInfo;
  final String returnUrl;

  const CreateVnpayPayment({
    required this.orderId,
    required this.amount,
    required this.orderInfo,
    required this.returnUrl,
  });

  @override
  List<Object?> get props => [orderId, amount, orderInfo, returnUrl];
}

/// Event: Verify payment từ callback
class VerifyVnpayCallback extends VnpayEvent {
  final Map<String, dynamic> vnpayResponse;

  const VerifyVnpayCallback(this.vnpayResponse);

  @override
  List<Object?> get props => [vnpayResponse];
}

/// Event: Reset về initial state
class ResetVnpayPayment extends VnpayEvent {
  const ResetVnpayPayment();
}
