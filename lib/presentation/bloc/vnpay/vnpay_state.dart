import 'package:equatable/equatable.dart';
import '../../../domain/entities/vnpay_payment.dart';

/// States cho VNPay payment BLoC
abstract class VnpayState extends Equatable {
  const VnpayState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class VnpayInitial extends VnpayState {
  const VnpayInitial();
}

/// Loading state
class VnpayLoading extends VnpayState {
  const VnpayLoading();
}

/// Payment URL created successfully
class VnpayPaymentUrlCreated extends VnpayState {
  final VnpayPayment payment;

  const VnpayPaymentUrlCreated(this.payment);

  @override
  List<Object?> get props => [payment];
}

/// Payment verified successfully
class VnpayPaymentVerified extends VnpayState {
  final VnpayPayment payment;
  final bool isSuccess;

  const VnpayPaymentVerified({
    required this.payment,
    required this.isSuccess,
  });

  @override
  List<Object?> get props => [payment, isSuccess];
}

/// Error state
class VnpayError extends VnpayState {
  final String message;

  const VnpayError(this.message);

  @override
  List<Object?> get props => [message];
}
