import 'package:flutter/foundation.dart';
import 'package:pet_shop/data/datasources/remote/payment_service.dart';

// Conditional imports cho web/mobile compatibility
import 'stripe_checkout_stub.dart'
    if (dart.library.html) 'stripe_checkout_web.dart'
    if (dart.library.io) 'stripe_checkout_mobile.dart';

class StripeCheckoutService {
  
  static Future<String?> createCheckoutSession({
    required double totalAmount,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String customerEmail,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      if (kDebugMode) {
        print('🔗 Creating Stripe Checkout session...');
      }

      // Step 1: Check backend health
      final isHealthy = await PaymentService.isBackendHealthy();
      if (!isHealthy) {
        throw Exception("Không thể kết nối đến server thanh toán");
      }

      // Step 2: Create checkout session via backend
      final checkoutData = await PaymentService.createCheckoutSession(
        amount: totalAmount,
        currency: "usd",
        customerInfo: {
          'name': customerName,
          'phone': customerPhone,
          'address': customerAddress,
          'email': customerEmail,
        },
        items: items.map((item) => {
          'productId': (item['productId'] ?? item['id'])?.toString(),
          'name': item['name'],
          'breed': item['breed'],
          'price': item['price'],
          'imageUrl': item['imageUrl'],
          'quantity': item['quantity'] ?? 1,
        }).toList(),
        successUrl: '${StripeWebUtils.getOrigin()}/payment-success',
        cancelUrl: '${StripeWebUtils.getOrigin()}/payment-cancel',
      );

      if (checkoutData == null || checkoutData['checkout_url'] == null) {
        throw Exception("Không thể tạo checkout session");
      }

      if (kDebugMode) {
        print('Checkout session created: ${checkoutData['checkout_url']}');
      }

      return checkoutData['checkout_url'];
    } catch (e) {
      if (kDebugMode) {
        print(' Failed to create checkout session: $e');
      }
      rethrow;
    }
  }

  static void redirectToCheckout(String checkoutUrl) {
    StripeWebUtils.redirectToUrl(checkoutUrl);
  }

  static bool isPaymentSuccessUrl() {
    if (!kIsWeb) return false;
    final pathname = StripeWebUtils.getCurrentPathname();
    return pathname.contains('/payment-success');
  }

  static bool isPaymentCancelUrl() {
    if (!kIsWeb) return false;
    final pathname = StripeWebUtils.getCurrentPathname();
    return pathname.contains('/payment-cancel');
  }

  static Map<String, String> getUrlParameters() {
    if (!kIsWeb) return {};
    
    final uri = Uri.parse(StripeWebUtils.getCurrentHref());
    return uri.queryParameters;
  }
}
