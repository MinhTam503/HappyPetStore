import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/presentation/bloc/vnpay/vnpay_bloc.dart';
import 'package:pet_shop/presentation/bloc/vnpay/vnpay_event.dart';
import 'package:pet_shop/presentation/bloc/vnpay/vnpay_state.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

/// Screen để xử lý callback từ VNPay sau khi thanh toán
class VnpayPaymentResultScreen extends StatefulWidget {
  final Map<String, dynamic> vnpayResponse;
  final Function(bool isSuccess, String orderId)? onPaymentResult;

  const VnpayPaymentResultScreen({
    Key? key,
    required this.vnpayResponse,
    this.onPaymentResult,
  }) : super(key: key);

  @override
  State<VnpayPaymentResultScreen> createState() =>
      _VnpayPaymentResultScreenState();
}

class _VnpayPaymentResultScreenState extends State<VnpayPaymentResultScreen> {
  @override
  void initState() {
    super.initState();
    // Verify payment ngay khi vào màn hình
    context.read<VnpayBloc>().add(VerifyVnpayCallback(widget.vnpayResponse));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        title: const Text(
          'Kết quả thanh toán',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<VnpayBloc, VnpayState>(
        listener: (context, state) {
          if (state is VnpayPaymentVerified) {
            // Gọi callback nếu có
            if (widget.onPaymentResult != null) {
              widget.onPaymentResult!(
                state.isSuccess,
                state.payment.orderId,
              );
            }
          }
        },
        builder: (context, state) {
          if (state is VnpayLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Đang xác thực giao dịch...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is VnpayPaymentVerified) {
            return _buildResultContent(
              isSuccess: state.isSuccess,
              orderId: state.payment.orderId,
              amount: state.payment.amount,
              transactionNo: state.payment.transactionNo,
            );
          }

          if (state is VnpayError) {
            return _buildErrorContent(state.message);
          }

          return const Center(child: Text('Đang xử lý...'));
        },
      ),
    );
  }

  Widget _buildResultContent({
    required bool isSuccess,
    required String orderId,
    required double amount,
    String? transactionNo,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isSuccess
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check_circle : Icons.cancel,
                color: isSuccess ? Colors.green : Colors.red,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              isSuccess ? 'Thanh toán thành công!' : 'Thanh toán thất bại',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              isSuccess
                  ? 'Giao dịch của bạn đã được xử lý thành công'
                  : 'Giao dịch không thành công. Vui lòng thử lại',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Transaction details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow('Mã đơn hàng', orderId),
                  const Divider(),
                  _buildDetailRow(
                    'Số tiền',
                    '${amount.toStringAsFixed(0)} VNĐ',
                  ),
                  if (transactionNo != null) ...[
                    const Divider(),
                    _buildDetailRow('Mã giao dịch', transactionNo),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Pop back to cart or order list
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isSuccess ? 'Về trang chủ' : 'Thử lại',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContent(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.orange,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Có lỗi xảy ra',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Quay lại',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
