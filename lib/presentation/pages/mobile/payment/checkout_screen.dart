import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:http/http.dart' as http;
import 'package:pet_shop/auth/payment/keys.dart';
import 'package:pet_shop/auth/stripe_helper.dart';
import 'package:pet_shop/core/config/vnpay_config.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/utils/localization_helper.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/address/address_list_page.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/vnpay_payment_result_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/vnpay_webview_screen.dart';
import 'package:pet_shop/helpers/order_notification_helper.dart';
import '../../../../data/models/cart_model.dart';
import '../../../bloc/vnpay/vnpay_bloc.dart';
import '../../../bloc/vnpay/vnpay_event.dart';
import '../../../bloc/vnpay/vnpay_state.dart';
// removed unused cart bloc imports
import '../../../widgets/cart_item.dart';

class CheckoutScreen extends StatefulWidget {
  final String userIdentifier;
  final List<CartModel> carts;
  const CheckoutScreen({super.key, required this.userIdentifier, required this.carts});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final UserManager userManager = UserManager();
  Map<String, dynamic>? userInfo;
  List<Map<String, dynamic>> deliveryInfos = [];
  Map<String, dynamic>? selectedDeliveryInfo;
  String paymentMethod = 'vnpay';
  final double shippingFee = 0.0; // Always free

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await userManager.initialize();
    await fetchAddresses();
    await fetchUserInfo();
    setState(() {});
  }

  Future<void> fetchUserInfo() async {
    userInfo = await userManager.getCurrentUserInfo();
  }

  Future<void> fetchAddresses() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) {
      deliveryInfos = [];
      selectedDeliveryInfo = null;
      return;
    }

    final userData = userDoc.data()!;
    var deliveryData = userData['deliveryInfos'];
    if (deliveryData is List && deliveryData.isNotEmpty) {
      deliveryInfos = List<Map<String, dynamic>>.from(deliveryData);
      selectedDeliveryInfo = deliveryInfos.firstWhere(
        (info) => info['isDefault'] == true,
        orElse: () => deliveryInfos.first,
      );
      return;
    }

    // Fallback old address list
    var addr = userData['address'];
    if (addr is List && addr.isNotEmpty) {
      deliveryInfos = addr
          .map<Map<String, dynamic>>((address) => {
                'name': userData['displayName'] ?? '',
                'phone': userData['phone'] ?? '',
                'address': address.toString(),
                'isDefault': deliveryInfos.isEmpty,
              })
          .toList();
      if (deliveryInfos.isNotEmpty) selectedDeliveryInfo = deliveryInfos.first;
    }
  }

  double _calculateTotal(List<CartModel> carts) {
    double total = 0.0;
    for (var item in carts) {
      final priceStr = item.grocery["price"].toString();
      final price = double.tryParse(priceStr) ?? 0.0;
      final quantity = item.quantity;
      total += quantity * price;
    }
    return total;
  }

  Future<List<String>> saveOrderToFirestore(String userIdentifier, List<CartModel> cartItems, {bool isPaid = true}) async {
    await userManager.initialize();

    final totalAmount = _calculateTotal(cartItems);
    final grandTotal = totalAmount + shippingFee;

    final orderRef = FirebaseFirestore.instance.collection('orders').doc();

    List<Map<String, dynamic>> items = [];
    List<String> breeds = [];

    for (var item in cartItems) {
      final petDoc = await FirebaseFirestore.instance
          .collection('Pets')
          .doc(item.grocery["productId"])
          .get();
      Map<String, dynamic> petData = {};
      if (petDoc.exists) {
        petData = petDoc.data()!;
        petData['productId'] = petDoc.id;
        petData['id'] = petDoc.id;
        petData['breed'] = petDoc.get('breed');
        final breed = petDoc.get('breed') as String?;
        if (breed != null && breed.isNotEmpty) breeds.add(breed);

        final petRawData = petDoc.data()!;
        double price = 0.0;
        if (petRawData.containsKey('price')) {
          price = (petRawData['price'] is num)
              ? (petRawData['price'] as num).toDouble()
              : double.tryParse(petRawData['price'].toString()) ?? 0.0;
        } else if (petRawData.containsKey('weight')) {
          price = (petRawData['weight'] is num)
              ? (petRawData['weight'] as num).toDouble()
              : double.tryParse(petRawData['weight'].toString()) ?? 0.0;
        }
        petData['price'] = price;
        petData['quantity'] = item.quantity;
      } else {
        petData = {
          'productId': item.grocery["productId"],
          'name': item.grocery["name"],
          'price': item.grocery["price"],
          'quantity': item.quantity,
        };
      }
      items.add(petData);
    }

    final userInfoForOrder = await userManager.getUserInfoForOrder();
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;

    final shippingAddress = selectedDeliveryInfo?['address'] ?? "Địa chỉ không xác định";
    final shippingName = selectedDeliveryInfo?['name'] ?? userInfoForOrder?['displayName'] ?? "";
    final shippingPhone = selectedDeliveryInfo?['phone'] ?? userInfoForOrder?['phone'] ?? "";

    final customerInfo = {
      'name': shippingName,
      'phone': shippingPhone.isNotEmpty ? shippingPhone : '0987654321',
      'email': userInfoForOrder?['email'] ?? currentUserEmail ?? userIdentifier,
    };

    final orderData = {
      "orderId": orderRef.id,
      "userIdentifier": userIdentifier,
      "userId": userInfoForOrder?['userId'] ?? userIdentifier,
      "email": customerInfo['email'],
      "phone": customerInfo['phone'],
      "displayName": customerInfo['name'],
      "shippingAddress": shippingAddress,
      "totalAmount": grandTotal,
      "subtotal": totalAmount,
      "shippingFee": shippingFee,
      "statusPayment": isPaid ? _getPaymentStatus() : "COD",
      "statusOrder": "Pending",
      "timestamp": FieldValue.serverTimestamp(),
      "paymentMethod": paymentMethod,
      "customerInfo": customerInfo,
      "deliveryInfo": selectedDeliveryInfo != null
          ? {
              "name": shippingName,
              "phone": shippingPhone,
              "address": shippingAddress,
              "isDefault": selectedDeliveryInfo!['isDefault'] ?? false,
              "latitude": selectedDeliveryInfo!['latitude'],
              "longitude": selectedDeliveryInfo!['longitude'],
            }
          : {
              "name": shippingName,
              "phone": shippingPhone,
              "address": shippingAddress,
            },
      "items": items,
    };

    await orderRef.set(orderData);

    final orderUserId = orderData['userId']?.toString();
    final orderUserName = orderData['displayName']?.toString();
    if (orderUserId != null && orderUserId.isNotEmpty) {
      await OrderNotificationHelper.sendOrderPlacedNotification(
        userId: orderUserId,
        orderId: orderRef.id,
        customerName: orderUserName,
        totalAmount: grandTotal,
      );
    }

    return breeds.toSet().toList();
  }

  String _getPaymentStatus() {
    switch (paymentMethod) {
      case 'stripe':
        return "Payment Completed (Stripe)";
      case 'vnpay':
        return "Payment Completed (VNPay)";
      case 'cod':
        return "COD";
      default:
        return "COD";
    }
  }

  Future<Map<String, dynamic>?> makeIntentForPayment(amount, currency) async {
    try {
      final paymentInfo = {
        "amount": (amount * 100).round().toString(),
        "currency": currency,
        "payment_method_types[]": "card",
      };

      var response = await http.post(
        Uri.parse("https://api.stripe.com/v1/payment_intents"),
        body: paymentInfo,
        headers: {
          "Authorization": "Bearer $SecretKey",
          "Content-Type": "application/x-www-form-urlencoded"
        },
      );

      if (response.statusCode != 200) {
        print(" Stripe API Error: ${response.body}");
        return null;
      }

      return jsonDecode(response.body);
    } catch (error) {
      print(" Stripe Error: $error");
      return null;
    }
  }

  Future<void> _payWithStripe(double totalPrice) async {
    try {
      final canUse = await StripeHelper.canUseStripe();
      if (!canUse) {
        NotificationHelper.showError(
          context,
          'Lỗi thanh toán Stripe',
          'Không thể khởi tạo thanh toán Stripe. Vui lòng thử phương thức khác.',
        );
        return;
      }

      double grandTotal = totalPrice + shippingFee;
      double amountInUSD = grandTotal;
      String currency = 'vnd';
      if (currency.toLowerCase() == 'vnd') {
        amountInUSD = grandTotal / 24000; // approx
        currency = 'usd';
      }

      if (amountInUSD < 0.5) {
        NotificationHelper.showWarning(
          context,
          'Số tiền quá nhỏ',
          'Số tiền tối thiểu là \$0.50 USD',
        );
        return;
      }

      final intent = await makeIntentForPayment(amountInUSD, currency);
      if (intent == null) {
        NotificationHelper.showError(context, 'Lỗi thanh toán', 'Không thể tạo giao dịch Stripe.');
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          allowsDelayedPaymentMethods: true,
          paymentIntentClientSecret: intent["client_secret"],
          style: ThemeMode.light,
          merchantDisplayName: "Pet Shop",
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Save order
  await saveOrderToFirestore(widget.userIdentifier, widget.carts, isPaid: true);

      // Clear all items (optional): here we keep cart intact; if desired, dispatch removal per item
      if (!mounted) return;
      NotificationHelper.showSuccess(context, 'Thanh toán thành công!', 'Đơn hàng đã được thanh toán.');

      // After success, we could navigate to success page or pop
      Navigator.pop(context); // back to Cart
    } on StripeException catch (e) {
      NotificationHelper.showError(
        context,
        'Thanh toán thất bại',
        e.error.message ?? 'Đã xảy ra lỗi trong quá trình thanh toán',
      );
    } catch (e) {
      NotificationHelper.showError(context, 'Lỗi thanh toán', 'Lỗi không mong muốn: $e');
    }
  }

  Future<void> _payWithVnPay(double totalPrice) async {
    try {
      final grandTotal = totalPrice + shippingFee;
      final orderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';
      final orderInfo = 'Thanh toan don hang HappyPetStore $orderId';
      final returnUrl = VnpayConfig.returnUrl;

      context.read<VnpayBloc>().add(CreateVnpayPayment(
            orderId: orderId,
            amount: grandTotal,
            orderInfo: orderInfo,
            returnUrl: returnUrl,
          ));
    } catch (e) {
      NotificationHelper.showError(context, 'Lỗi thanh toán VNPay', 'Đã có lỗi xảy ra: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateTotal(widget.carts);
    final total = subtotal + shippingFee;

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(LocalizationHelper.getLocalizedText(context, 'checkout')),
      ),
      body: BlocListener<VnpayBloc, VnpayState>(
        listener: (context, state) async {
          if (state is VnpayPaymentUrlCreated) {
            final paymentUrl = state.payment.paymentUrl;
            if (paymentUrl != null) {
              final result = await Navigator.push<Map<String, String>>(
                context,
                MaterialPageRoute(
                  builder: (context) => VnpayWebViewScreen(
                    paymentUrl: paymentUrl,
                    returnUrl: VnpayConfig.returnUrl,
                  ),
                ),
              );

              if (result != null && mounted) {
                context.read<VnpayBloc>().add(VerifyVnpayCallback(result));
                // Consider saving order after verifying success via a Result Screen, as in CartScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VnpayPaymentResultScreen(
                      vnpayResponse: result,
                      onPaymentResult: (isSuccess, orderId) async {
                        if (isSuccess) {
                          await saveOrderToFirestore(widget.userIdentifier, widget.carts, isPaid: true);
                          if (!mounted) return;
                          NotificationHelper.showSuccess(context, 'Thanh toán thành công!', 'Đơn hàng đã được thanh toán.');
                          Navigator.popUntil(context, (route) => route.isFirst);
                        } else {
                          NotificationHelper.showError(context, 'Thanh toán thất bại', 'Giao dịch không thành công.');
                        }
                      },
                    ),
                  ),
                );
              }
            }
          } else if (state is VnpayError) {
            NotificationHelper.showError(context, 'Lỗi thanh toán VNPay', state.message);
          }
        },
        child: Column(
          children: [
            // Address card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddressListPage(
                          selectedAddress: selectedDeliveryInfo,
                          onAddressSelected: (address) {
                            setState(() {
                              selectedDeliveryInfo = address;
                            });
                          },
                        ),
                      ),
                    );
                    if (result != null) {
                      await fetchAddresses();
                      setState(() {});
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on, color: primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationHelper.getLocalizedText(context, 'shippingAddress'),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: primaryColor),
                              ),
                              const SizedBox(height: 4),
                              if (selectedDeliveryInfo != null) ...[
                                Text(
                                  '${selectedDeliveryInfo!['name']} • ${selectedDeliveryInfo!['phone']}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selectedDeliveryInfo!['address'] ?? '',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else ...[
                                Text(
                                  LocalizationHelper.getLocalizedText(context, 'noShippingAddress'),
                                  style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  LocalizationHelper.getLocalizedText(context, 'tapToAddAddress'),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Items summary
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: widget.carts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final c = widget.carts[index];
                  return CartItem(
                    cart: c,
                    showRemoveButton: false,
                  );
                },
              ),
            ),

            // Payment + Total
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Phương thức', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<String>(
                          value: paymentMethod,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'vnpay', child: Text('Thanh toán qua VNPay')),
                            DropdownMenuItem(value: 'stripe', child: Text('Thanh toán qua Stripe')),
                            DropdownMenuItem(value: 'cod', child: Text('Thanh toán khi nhận hàng')),
                          ],
                          onChanged: (v) => setState(() => paymentMethod = v ?? 'vnpay'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tạm tính'),
                      Text(CurrencyHelper.formatVND(subtotal)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Phí vận chuyển'),
                      Text('Miễn phí', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng cộng', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        CurrencyHelper.formatVND(total),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedDeliveryInfo == null
                          ? null
                          : () async {
                              if (paymentMethod == 'vnpay') {
                                await _payWithVnPay(subtotal);
                              } else if (paymentMethod == 'stripe') {
                                await _payWithStripe(subtotal);
                              } else {
                                // COD
                                await saveOrderToFirestore(widget.userIdentifier, widget.carts, isPaid: false);
                                if (!mounted) return;
                                NotificationHelper.showSuccess(context, 'Đặt hàng thành công!', 'Đơn hàng sẽ được thanh toán khi nhận hàng.');
                                Navigator.pop(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(LocalizationHelper.getLocalizedText(context, 'payNow')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Meta rendering is handled inside CartItem
