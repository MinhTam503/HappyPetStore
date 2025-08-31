import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:pet_shop/services/payment_service.dart';
import 'package:pet_shop/services/stripe_checkout_service.dart';
import 'package:pet_shop/utils/contants.dart';

class StripePaymentScreen extends StatefulWidget {
  final double totalAmount;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String customerEmail;
  final List<Map<String, dynamic>> items;

  const StripePaymentScreen({
    super.key,
    required this.totalAmount,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerEmail,
    required this.items,
  });

  @override
  State<StripePaymentScreen> createState() => _StripePaymentScreenState();
}

class _StripePaymentScreenState extends State<StripePaymentScreen> {
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        // For web, we don't need to initialize anything special
        // Just mark as ready for checkout
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      } else {
        // For mobile, initialize Stripe payment sheet
        await _initializeMobilePayment();
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog("Lỗi khởi tạo thanh toán: $e");
    }
  }

  Future<void> _initializeMobilePayment() async {
    // Step 1: Check backend health
    final isHealthy = await PaymentService.isBackendHealthy();
    if (!isHealthy) {
      throw Exception("Không thể kết nối đến server thanh toán");
    }

    // Step 2: Create payment intent for mobile
    final paymentIntentData = await PaymentService.createPaymentIntent(
      amount: widget.totalAmount,
      currency: "usd",
    );

    if (paymentIntentData == null) {
      throw Exception("Không thể tạo intent thanh toán");
    }

    // Step 3: Initialize payment sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: paymentIntentData["client_secret"],
        merchantDisplayName: "Pet Shop",
        allowsDelayedPaymentMethods: true,
        style: ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            primary: primaryColor,
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_isInitialized) {
      _showErrorDialog("Thanh toán chưa được khởi tạo");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        await _processWebCheckout();
      } else {
        await _processMobilePayment();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog("Lỗi thanh toán: $e");
    }
  }

  Future<void> _processWebCheckout() async {
    try {
      // Create Stripe Checkout session and redirect
      final checkoutUrl = await StripeCheckoutService.createCheckoutSession(
        totalAmount: widget.totalAmount,
        customerName: widget.customerName,
        customerPhone: widget.customerPhone,
        customerAddress: widget.customerAddress,
        customerEmail: widget.customerEmail,
        items: widget.items,
      );

      if (checkoutUrl == null) {
        throw Exception("Không thể tạo session thanh toán");
      }

      if (kDebugMode) {
        print('🔗 Redirecting to Stripe Checkout: $checkoutUrl');
      }

      // Redirect to Stripe Checkout
      StripeCheckoutService.redirectToCheckout(checkoutUrl);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Web checkout error: $e');
      }
      rethrow;
    }
  }

  Future<void> _processMobilePayment() async {
    try {
      // Present payment sheet for mobile
      await Stripe.instance.presentPaymentSheet();

      // If we reach here, payment was successful
      if (!mounted) return;
      _showSuccessDialog();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        // User canceled, don't show error
        return;
      }
      throw Exception("Thanh toán thất bại: ${e.error.message ?? "Đã có lỗi xảy ra"}");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Lỗi thanh toán"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to cart
            },
            child: const Text("Quay lại giỏ hàng"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializePayment(); // Retry
            },
            child: const Text("Thử lại"),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Thanh toán thành công!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              "Đơn hàng của bạn đã được thanh toán thành công!\nTổng tiền: \$${widget.totalAmount.toStringAsFixed(2)}",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // Return to cart with success
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.black,
            ),
            child: const Text("Về trang chủ"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        title: const Text("Thanh toán"),
        backgroundColor: secondaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Đang xử lý thanh toán..."),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Summary
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Thông tin đơn hàng",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow("Khách hàng:", widget.customerName),
                            _buildInfoRow("Điện thoại:", widget.customerPhone),
                            _buildInfoRow("Địa chỉ:", widget.customerAddress),
                            _buildInfoRow("Email:", widget.customerEmail),
                            const Divider(),
                            _buildInfoRow(
                              "Tổng tiền:",
                              "\$${widget.totalAmount.toStringAsFixed(2)}",
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items List
                    const Text(
                      "Sản phẩm trong đơn hàng:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Card(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: widget.items.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = widget.items[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['imageUrl'] ?? '',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.pets),
                                  ),
                                ),
                              ),
                              title: Text(item['name'] ?? 'Unknown Pet'),
                              subtitle: Text(item['breed'] ?? ''),
                              trailing: Text(
                                '\$${(item['price'] ?? item['weight'] ?? 0).toString()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Thông báo cho Web về Stripe Checkout
                    if (kIsWeb) ...[
                      const SizedBox(height: 20),
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[700],
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Thanh toán an toàn với Stripe",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Bạn sẽ được chuyển đến trang thanh toán an toàn của Stripe để nhập thông tin thẻ tín dụng.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Payment Button
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isInitialized && !_isLoading
                            ? _processPayment
                            : null,
                        icon: const Icon(Icons.payment),
                        label: Text(
                          _isInitialized
                              ? (kIsWeb ? "Chuyển đến Stripe để thanh toán" : "Thanh toán ngay")
                              : "Đang khởi tạo...",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                fontSize: isTotal ? 16 : 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
                color: isTotal ? primaryColor : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}