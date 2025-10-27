import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/create_vnpay_payment_url.dart';
import '../../../domain/usecases/verify_vnpay_payment.dart';
import 'vnpay_event.dart';
import 'vnpay_state.dart';

/// VNPay Payment BLoC
/// Quản lý state và logic cho VNPay payment flow
class VnpayBloc extends Bloc<VnpayEvent, VnpayState> {
  final CreateVnpayPaymentUrl createPaymentUrl;
  final VerifyVnpayPayment verifyPayment;

  VnpayBloc({
    required this.createPaymentUrl,
    required this.verifyPayment,
  }) : super(const VnpayInitial()) {
    on<CreateVnpayPayment>(_onCreatePayment);
    on<VerifyVnpayCallback>(_onVerifyCallback);
    on<ResetVnpayPayment>(_onResetPayment);
  }

  /// Handle create payment event
  Future<void> _onCreatePayment(
    CreateVnpayPayment event,
    Emitter<VnpayState> emit,
  ) async {
    emit(const VnpayLoading());
    
    try {
      print('🔄 Creating VNPay payment URL for order: ${event.orderId}');
      
      final payment = await createPaymentUrl(
        orderId: event.orderId,
        amount: event.amount,
        orderInfo: event.orderInfo,
        returnUrl: event.returnUrl,
      );

      print('✅ VNPay payment URL created successfully');
      emit(VnpayPaymentUrlCreated(payment));
    } catch (e) {
      print('❌ Error creating VNPay payment: $e');
      emit(VnpayError(e.toString()));
    }
  }

  /// Handle verify callback event
  Future<void> _onVerifyCallback(
    VerifyVnpayCallback event,
    Emitter<VnpayState> emit,
  ) async {
    emit(const VnpayLoading());
    
    try {
      print('🔄 Verifying VNPay payment callback...');
      
      final payment = await verifyPayment(event.vnpayResponse);
      
      final isSuccess = payment.isSuccess;
      print(isSuccess 
        ? '✅ VNPay payment verified - SUCCESS'
        : '❌ VNPay payment verified - FAILED'
      );
      
      emit(VnpayPaymentVerified(
        payment: payment,
        isSuccess: isSuccess,
      ));
    } catch (e) {
      print('❌ Error verifying VNPay payment: $e');
      emit(VnpayError(e.toString()));
    }
  }

  /// Handle reset payment event
  void _onResetPayment(
    ResetVnpayPayment event,
    Emitter<VnpayState> emit,
  ) {
    emit(const VnpayInitial());
  }
}
