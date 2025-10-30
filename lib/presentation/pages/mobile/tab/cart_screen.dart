import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Stripe payments moved to CheckoutScreen
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/core/utils/localization_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/order/orderSuccess.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/checkout_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/vnpay_payment_result_screen.dart';
import 'package:pet_shop/presentation/pages/mobile/payment/vnpay_webview_screen.dart';
// Address selection is handled in CheckoutScreen
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/helpers/order_notification_helper.dart';
import 'package:pet_shop/presentation/widgets/common/app_drawer.dart';
import '../../../../data/models/cart_model.dart';
import '../../../bloc/apriori/apriori_bloc.dart';
import '../../../bloc/apriori/apriori_event.dart';
import '../../../bloc/apriori/apriori_state.dart';

import '../../../widgets/cart_item.dart';
import '../../../bloc/cartBloc/cart_bloc.dart';
import '../../../bloc/cartBloc/cart_event.dart';
import '../../../bloc/cartBloc/cart_state.dart';
import '../../../bloc/vnpay/vnpay_bloc.dart';
import '../../../bloc/vnpay/vnpay_event.dart';
import '../../../bloc/vnpay/vnpay_state.dart';

import '../pet/detail_pet.dart';
import 'package:pet_shop/core/config/vnpay_config.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? intentPaymentData;
  final UserManager userManager = UserManager();
  String? userIdentifier;
  // Multi-select state for checkout
  final Set<String> _selectedProductIds = <String>{};
  bool _selectAll = true;

  // Thêm biến cho phương thức thanh toán và thông tin giao hàng
  String paymentMethod = 'cod'; // Mặc định là COD
  List<Map<String, dynamic>> deliveryInfos = [];
  Map<String, dynamic>? selectedDeliveryInfo;
  Map<String, dynamic>? userInfo;

  // NO SHIPPING FEE - Mock only
  final double shippingFee = 0.0; // Always free

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    userIdentifier = await userManager.getUserIdentifier();
    if (userIdentifier != null) {
      context.read<CartBloc>().add(LoadCart(userIdentifier!));
      fetchAddresses();
      fetchUserInfo();
    }
  }

  Future<Map<String, dynamic>?> getPetById(String petId) async {
    try {
      final docSnapshot =
          await FirebaseFirestore.instance.collection('Pets').doc(petId).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) data['id'] = docSnapshot.id;
        return data;
      } else {
        print('Không tìm thấy thú cưng với ID: $petId');
        return null;
      }
    } catch (e) {
      print('Lỗi khi lấy dữ liệu thú cưng: $e');
      return null;
    }
  }

  Future<void> fetchAddresses() async {
    if (userIdentifier == null) return;

    // Try to get user info from current user first
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Use UID to query user document
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) {
      setState(() {
        deliveryInfos = [];
        selectedDeliveryInfo = null;
      });
      return;
    }

    final userData = userDoc.data()!;

    // Check for new deliveryInfos format first
    var deliveryData = userData['deliveryInfos'];
    if (deliveryData is List && deliveryData.isNotEmpty) {
      setState(() {
        deliveryInfos = List<Map<String, dynamic>>.from(deliveryData);
        // Select default delivery info or first one
        selectedDeliveryInfo = deliveryInfos.firstWhere(
          (info) => info['isDefault'] == true,
          orElse: () => deliveryInfos.first,
        );
      });
      return;
    }

    // Fallback to old address format for migration
    var addr = userData['address'];
    if (addr == null || (addr is String && addr.isEmpty)) {
      setState(() {
        deliveryInfos = [];
        selectedDeliveryInfo = null;
      });
    } else if (addr is List) {
      // Migrate old addresses to new format
      setState(() {
        deliveryInfos = addr
            .map<Map<String, dynamic>>((address) => {
                  'name': userData['displayName'] ?? '',
                  'phone': userData['phone'] ?? '',
                  'address': address.toString(),
                  'isDefault': deliveryInfos.isEmpty,
                })
            .toList();

        if (deliveryInfos.isNotEmpty) {
          selectedDeliveryInfo = deliveryInfos.first;
        }
      });
    }
  }

  Future<void> fetchUserInfo() async {
    if (userIdentifier == null) return;

    // Đảm bảo UserManager được initialize
    await userManager.initialize();

    userInfo = await userManager.getCurrentUserInfo();
    print(
        "👤 Fetched user info: email=${userInfo?['email']}, phone=${userInfo?['phone']}");
    setState(() {});
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

  void onOrderSuccessWithBreeds(List<String> breeds) async {
    print(
        '🚀 MULTI-BREED ANALYSIS: onOrderSuccessWithBreeds called with ${breeds.length} breeds: $breeds');

    if (!mounted) {
      print('🚫 Widget unmounted, skipping Apriori analysis');
      return;
    }

    if (breeds.isEmpty) {
      print('🚫 No breeds provided, navigating with empty suggestions');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OrderSuccess(suggestions: []),
        ),
      );
      return;
    }

    // Use Apriori BLoC for breed analysis
    context.read<AprioriBloc>().add(GetSuggestionsFromMultipleBreeds(breeds));

    // Listen to BLoC state and navigate when loaded
    final aprioriBloc = context.read<AprioriBloc>();

    aprioriBloc.stream.listen((state) {
      if (state is AprioriLoaded) {
        // Convert to old format for compatibility
        final suggestions =
            state.suggestions.map((pet) => pet.toMap()).toList();

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccess(suggestions: suggestions),
          ),
        );
      } else if (state is AprioriError || state is AprioriEmpty) {
        // Fallback to empty suggestions
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const OrderSuccess(suggestions: []),
          ),
        );
      }
    });
  }

  void onOrderSuccessWithSuggestions(List<CartModel> cartItems) async {
    print(
        '🚀 MULTI-BREED ANALYSIS: onOrderSuccessWithSuggestions called with ${cartItems.length} items');

    if (!mounted) {
      print('🚫 Widget unmounted, skipping Apriori analysis');
      return;
    }

    // Extract breeds from cart items for improved suggestions
    print('🔍 DEBUG: Extracting breeds from cart items...');
    for (var i = 0; i < cartItems.length; i++) {
      print('🔍 Cart item $i: ${cartItems[i].grocery}');
      print('🔍 Cart item $i breed: ${cartItems[i].grocery["breed"]}');
    }

    List<String> breeds = cartItems
        .map((item) => item.grocery["breed"] as String?)
        .where((breed) => breed != null && breed.isNotEmpty)
        .cast<String>()
        .toSet() // Remove duplicates
        .toList();

    print(
        '🌱 Multi-breed Apriori analysis: Found ${breeds.length} unique breeds: $breeds');

    // Use Apriori BLoC for breed analysis
    context.read<AprioriBloc>().add(GetSuggestionsFromMultipleBreeds(breeds));

    // Listen to BLoC state and navigate when loaded
    final aprioriBloc = context.read<AprioriBloc>();

    aprioriBloc.stream.listen((state) {
      if (state is AprioriLoaded) {
        // Convert to old format for compatibility
        final suggestions =
            state.suggestions.map((pet) => pet.toMap()).toList();

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccess(suggestions: suggestions),
          ),
        );
      } else if (state is AprioriError || state is AprioriEmpty) {
        // Fallback to empty suggestions
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const OrderSuccess(suggestions: []),
          ),
        );
      }
    });
  }

  double _calculateTotal(List<CartModel> carts) {
    double total = 0.0;
    print("🧮 Calculating total for ${carts.length} items:");

    for (var item in carts) {
      final priceStr = item.grocery["price"].toString();
      final price = double.tryParse(priceStr) ?? 0.0;
      final quantity = item.quantity;
      final itemTotal = quantity * price;

      print(
          "  - ${item.grocery["name"]}: $priceStr (parsed: $price) x $quantity = ${CurrencyHelper.formatVND(itemTotal)}");
      total += itemTotal;
    }

    print("🧮 Subtotal: ${CurrencyHelper.formatVND(total)}");
    print("🚚 Shipping fee: ${CurrencyHelper.formatVND(shippingFee)}");
    print(
        "🧮 Total with shipping: ${CurrencyHelper.formatVND(total + shippingFee)}");
    return total;
  }

  double _calculateSelectedTotal(List<CartModel> carts) {
    final selected = carts.where((c) {
      final id = c.grocery['productId']?.toString() ?? '';
      return _selectedProductIds.contains(id);
    }).toList();
    return _calculateTotal(selected);
  }

  Future<List<String>> saveOrderToFirestore(
      String userIdentifier, List<CartModel> cartItems,
      {bool isPaid = true}) async {
    // Đảm bảo UserManager được initialize
    await userManager.initialize();

    final totalAmount = _calculateTotal(cartItems);
    final grandTotal = totalAmount + shippingFee;
    print("💰 Subtotal: ${CurrencyHelper.formatVND(totalAmount)}");
    print("🚚 Shipping fee: ${CurrencyHelper.formatVND(shippingFee)}");
    print(
        "💰 Grand total to save to Firestore: ${CurrencyHelper.formatVND(grandTotal)}");

    final orderRef = FirebaseFirestore.instance.collection('orders').doc();

    // Lấy đầy đủ thông tin thú cưng từ Firestore
    List<Map<String, dynamic>> items = [];
    List<String> breeds = []; // Collect breeds here

    for (var item in cartItems) {
      final petDoc = await FirebaseFirestore.instance
          .collection('Pets')
          .doc(item.grocery["productId"])
          .get();
      Map<String, dynamic> petData = {};
      if (petDoc.exists) {
        petData = petDoc.data()!;
        petData['productId'] = petDoc.id;
        petData['id'] = petDoc.id; // Thêm id
        petData['breed'] = petDoc.get('breed'); // Đảm bảo lưu breed

        // Collect breed for Apriori analysis
        final breed = petDoc.get('breed') as String?;
        if (breed != null && breed.isNotEmpty) {
          breeds.add(breed);
        }

        // Đảm bảo lấy đúng field price
        final petRawData = petDoc.data()!;
        double price = 0.0;

        if (petRawData.containsKey('price')) {
          price = (petRawData['price'] is num)
              ? (petRawData['price'] as num).toDouble()
              : double.tryParse(petRawData['price'].toString()) ?? 0.0;
          print("🔍 Pet ${petDoc.id}: Using 'price' field = $price");
        } else if (petRawData.containsKey('weight')) {
          price = (petRawData['weight'] is num)
              ? (petRawData['weight'] as num).toDouble()
              : double.tryParse(petRawData['weight'].toString()) ?? 0.0;
          print("⚠️ Pet ${petDoc.id}: Using 'weight' field as price = $price");
        } else {
          print("❌ Pet ${petDoc.id}: No price or weight field found!");
        }

        petData['price'] = price;
        petData['quantity'] = item.quantity;
        print("Saving pet data with breed: ${petData['breed']}");
      } else {
        // Nếu không tìm thấy, vẫn lưu thông tin cơ bản
        petData = {
          'productId': item.grocery["productId"],
          'name': item.grocery["name"],
          'price': item.grocery["price"],
          'quantity': item.quantity,
        };
      }
      items.add(petData);
    }

    // Lấy thông tin user đầy đủ từ UserManager
    final userInfoForOrder = await userManager.getUserInfoForOrder();
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;

    // Extract shipping information from selectedDeliveryInfo
    final shippingAddress =
        selectedDeliveryInfo?['address'] ?? "Địa chỉ không xác định";
    final shippingName =
        selectedDeliveryInfo?['name'] ?? userInfoForOrder?['displayName'] ?? "";
    final shippingPhone =
        selectedDeliveryInfo?['phone'] ?? userInfoForOrder?['phone'] ?? "";

    // Chuẩn bị customer info cho shipping (đồng bộ với ShippingService)
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
      "shippingAddress": shippingAddress, // Single source of truth for address
      "totalAmount": grandTotal, // Include shipping fee in total
      "subtotal": totalAmount, // Keep subtotal separate
      "shippingFee": shippingFee, // Store shipping fee separately
      "statusPayment": isPaid ? _getPaymentStatus() : "COD",
      "statusOrder": "Pending",
      "timestamp": FieldValue.serverTimestamp(),
      "paymentMethod": paymentMethod,
      // Customer và delivery info - đồng bộ với ShippingService format
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

    print("💾 Saving order with standardized fields:");
    print("  - orderId: ${orderData['orderId']}");
    print("  - userId: ${orderData['userId']}");
    print("  - email: ${orderData['email']}");
    print("  - phone: ${orderData['phone']}");
    print("  - displayName: ${orderData['displayName']}");
    print("  - shippingAddress: ${orderData['shippingAddress']}");
    print("  - customerInfo: ${orderData['customerInfo']}");
    print("  - deliveryInfo: ${orderData['deliveryInfo']}");
    print("🌱 Collected breeds for Apriori: $breeds");

    await orderRef.set(orderData);

    // NOTE: Shipment will be created by admin when order status changes to "Processing"
    // This ensures proper workflow: Order → Admin Review → Create Shipment
    print('✅ Order created successfully: ${orderRef.id}');
    print('📋 Order status: Pending (waiting for admin to process)');
    print(
        '🚫 Shipment NOT created yet - will be created when admin changes status to Processing');

    // Gửi thông báo đơn hàng đã được đặt
    final orderUserId = orderData['userId']?.toString();
    final orderUserName = orderData['displayName']?.toString();

    if (orderUserId != null && orderUserId.isNotEmpty) {
      await OrderNotificationHelper.sendOrderPlacedNotification(
        userId: orderUserId,
        orderId: orderRef.id,
        customerName: orderUserName,
        totalAmount: grandTotal, // Use grand total including shipping
      );
    }

    // Return unique breeds for Apriori analysis
    return breeds.toSet().toList();
  }

  // Future<void> showPaymentSheet(
  //     String userIdentifier, List<CartModel> cartItems) async {
  //   try {
  //     await Stripe.instance.presentPaymentSheet();

  //     for (var item in cartItems) {
  //       final petId = item.grocery["productId"] ?? item.grocery["id"];
  //       final docRef = FirebaseFirestore.instance.collection('Pets').doc(petId);
  //       final docSnap = await docRef.get();
  //       if (docSnap.exists) {
  //         await docRef.update({
  //           "status": "sold",
  //           "isAvailable": false,
  //         });
  //       } else {
  //         print("Pet with id $petId not found in Firestore.");
  //       }
  //     }

  //     // Save order and get breeds for Apriori analysis
  //     final breeds =
  //         await saveOrderToFirestore(userIdentifier, cartItems, isPaid: true);
  //     context.read<CartBloc>().add(ClearCart(userIdentifier));

  //     if (!context.mounted) return;

  //     // Show success notification
  //     NotificationHelper.showSuccess(
  //       context,
  //       'Thanh toán thành công!',
  //       'Đơn hàng của bạn đã được thanh toán và sẽ được giao sớm nhất.',
  //     );

  //     // Use new multi-breed analysis with extracted breeds
  //     if (breeds.isNotEmpty) {
  //       print("🌱 Stripe payment: Using breeds for Apriori: $breeds");
  //       onOrderSuccessWithBreeds(breeds);
  //     } else {
  //       print("⚠️ Stripe payment: No breeds found, using fallback");
  //       onOrderSuccessWithSuggestions(cartItems);
  //     }

  //     setState(() {
  //       intentPaymentData = null;
  //     });
  //   } on StripeException catch (e) {
  //     NotificationHelper.showError(
  //       context,
  //       'Thanh toán thất bại',
  //       e.error.message ?? 'Đã xảy ra lỗi trong quá trình thanh toán',
  //     );
  //   } catch (error) {
  //     NotificationHelper.showError(
  //       context,
  //       'Lỗi thanh toán',
  //       'Lỗi không mong muốn: ${error.toString()}',
  //     );
  //   }
  // }

  // Future<Map<String, dynamic>?> makeIntentForPayment(amount, currency) async {
  //   try {
  //     // Debug: Check if keys are available (safe substring)
  //     final pubKeyPreview = PublishableKey.length > 20
  //         ? "${PublishableKey.substring(0, 20)}..."
  //         : PublishableKey.isNotEmpty
  //             ? "$PublishableKey (short)"
  //             : "EMPTY!";
  //     final secKeyPreview = SecretKey.length > 20
  //         ? "${SecretKey.substring(0, 20)}..."
  //         : SecretKey.isNotEmpty
  //             ? "$SecretKey (short)"
  //             : "EMPTY!";

  //     print("🔐 PublishableKey: $pubKeyPreview");
  //     print("🔐 SecretKey: $secKeyPreview");

  //     if (SecretKey.isEmpty) {
  //       print("❌ ERROR: SecretKey is empty!");
  //       return null;
  //     }

  //     Map<String, dynamic>? paymentInfo = {
  //       "amount": (amount * 100).round().toString(),
  //       "currency": currency,
  //       "payment_method_types[]": "card",
  //     };

  //     var response = await http.post(
  //       Uri.parse("https://api.stripe.com/v1/payment_intents"),
  //       body: paymentInfo,
  //       headers: {
  //         "Authorization": "Bearer $SecretKey",
  //         "Content-Type": "application/x-www-form-urlencoded"
  //       },
  //     );

  //     if (response.statusCode != 200) {
  //       print(" Stripe API Error: ${response.body}");
  //       return null;
  //     }

  //     print(" Payment intent created successfully");
  //     return jsonDecode(response.body);
  //   } catch (error) {
  //     print(" Stripe Error: $error");
  //     return null;
  //   }
  // }

  // void paymentInit(double amount, String currency, String userIdentifier,
  //     List<CartModel> carts) async {
  //   try {
  //     // Include shipping fee in payment amount
  //     final grandTotal = amount + shippingFee;

  //     // Check if Stripe is ready for use
  //     final canUse = await StripeHelper.canUseStripe();
  //     if (!canUse) {
  //       // Show error and ask user what to do
  //       showDialog(
  //         context: context,
  //         builder: (context) => AlertDialog(
  //           title: const Text('Lỗi thanh toán Stripe'),
  //           content: const Text(
  //               'Không thể khởi tạo thanh toán Stripe. Bạn có muốn chuyển sang thanh toán khi nhận hàng không?'),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text('Hủy'),
  //             ),
  //             TextButton(
  //               onPressed: () async {
  //                 Navigator.pop(context);

  //                 try {
  //                   final breeds = await saveOrderToFirestore(
  //                       userIdentifier, carts,
  //                       isPaid: false);
  //                   context.read<CartBloc>().add(ClearCart(userIdentifier));

  //                   if (!context.mounted) return;

  //                   NotificationHelper.showSuccess(
  //                     context,
  //                     'Đặt hàng thành công!',
  //                     'Đơn hàng sẽ được thanh toán khi nhận hàng.',
  //                   );

  //                   if (breeds.isNotEmpty) {
  //                     onOrderSuccessWithBreeds(breeds);
  //                   } else {
  //                     onOrderSuccessWithSuggestions(carts);
  //                   }
  //                 } catch (fallbackError) {
  //                   NotificationHelper.showError(
  //                     context,
  //                     'Lỗi đặt hàng',
  //                     'Không thể tạo đơn hàng: $fallbackError',
  //                   );
  //                 }
  //               },
  //               child: const Text('Chuyển COD'),
  //             ),
  //           ],
  //         ),
  //       );
  //       return;
  //     }

  //     // Convert VND to USD (approximate rate: 1 USD = 24,000 VND)
  //     double amountInUSD = grandTotal;
  //     print(
  //         "💱 Payment conversion: Original amount = ${CurrencyHelper.formatVND(grandTotal)}");

  //     if (currency.toLowerCase() == 'vnd') {
  //       amountInUSD = grandTotal / 24000; // Convert VND to USD
  //       currency = 'usd';
  //       print("💱 Converted to USD: \$${amountInUSD.toStringAsFixed(2)}");
  //     } else {
  //       print("💱 Currency is already: $currency");
  //     }

  //     // Check Stripe limits (max $999,999 USD per transaction)
  //     if (amountInUSD > 999999) {
  //       NotificationHelper.showWarning(
  //         context,
  //         'Số tiền vượt quá giới hạn',
  //         'Số tiền quá lớn cho thanh toán Stripe (tối đa \$999,999 USD ≈ ${CurrencyHelper.formatVND(999999 * 24000)}). Vui lòng chọn thanh toán khi nhận hàng.',
  //       );
  //       return;
  //     }

  //     // Check minimum amount (Stripe minimum is $0.50 USD)
  //     if (amountInUSD < 0.5) {
  //       NotificationHelper.showWarning(
  //         context,
  //         'Số tiền quá nhỏ',
  //         'Số tiền quá nhỏ cho thanh toán Stripe (tối thiểu \$0.50 USD)',
  //       );
  //       return;
  //     }

  //     intentPaymentData = await makeIntentForPayment(amountInUSD, currency);
  //     if (intentPaymentData == null) {
  //       NotificationHelper.showError(
  //         context,
  //         'Lỗi thanh toán',
  //         'Không thể tạo giao dịch thanh toán. Vui lòng thử lại.',
  //       );
  //       return;
  //     }

  //     await Stripe.instance.initPaymentSheet(
  //       paymentSheetParameters: SetupPaymentSheetParameters(
  //         allowsDelayedPaymentMethods: true,
  //         paymentIntentClientSecret: intentPaymentData?["client_secret"],
  //         style: ThemeMode.light,
  //         merchantDisplayName: "Pet Shop",
  //       ),
  //     );

  //     showPaymentSheet(userIdentifier, carts);
  //   } catch (e, s) {
  //     print("Payment Init Error: $e\n$s");
  //     NotificationHelper.showError(
  //       context,
  //       'Lỗi thanh toán Stripe',
  //       'Đã có lỗi xảy ra: $e',
  //     );
  //   }
  // }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: primaryColor,
          size: 28,
        ),
        key: _scaffoldKey,
        forceMaterialTransparency: true,
        backgroundColor: secondaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          LocalizationHelper.getLocalizedText(context, 'myCart'),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: BlocListener<VnpayBloc, VnpayState>(
          listener: (context, vnpayState) async {
            if (vnpayState is VnpayPaymentUrlCreated) {
              // Payment URL created, open in WebView
              final paymentUrl = vnpayState.payment.paymentUrl;
              if (paymentUrl != null) {
                print('🌐 Opening VNPay payment in WebView: $paymentUrl');

                // Open WebView
                final result = await Navigator.push<Map<String, String>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VnpayWebViewScreen(
                      paymentUrl: paymentUrl,
                      // Must match the returnUrl sent to VNPay
                      returnUrl: VnpayConfig.returnUrl,
                      onPaymentCallback: (params) {
                        print('💰 Payment callback received: $params');
                      },
                    ),
                  ),
                );

                // Handle result from WebView
                if (result != null && mounted) {
                  print('📦 WebView returned params: $result');

                  // Verify payment with BLoC
                  context.read<VnpayBloc>().add(
                        VerifyVnpayCallback(result),
                      );

                  // Navigate to result screen
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VnpayPaymentResultScreen(
                          vnpayResponse: result,
                          onPaymentResult: (isSuccess, orderId) async {
                            if (isSuccess && userIdentifier != null) {
                              // Payment successful - save order
                              print('✅ Payment successful for order: $orderId');

                              final carts = (context.read<CartBloc>().state
                                      as CartLoaded)
                                  .items
                                  .map((item) => CartModel(
                                        grocery: {
                                          ...item,
                                          'price':
                                              item["price"]?.toString() ?? '0',
                                          'productId':
                                              item["productId"]?.toString() ??
                                                  '',
                                          'name':
                                              item["name"]?.toString() ?? '',
                                          'imageUrl':
                                              item["imageUrl"]?.toString() ??
                                                  '',
                                        },
                                        quantity: item["quantity"] ?? 1,
                                      ))
                                  .toList();

                              // Save order to Firestore
                              final breeds = await saveOrderToFirestore(
                                userIdentifier!,
                                carts,
                                isPaid: true,
                              );

                              // Clear cart
                              context
                                  .read<CartBloc>()
                                  .add(ClearCart(userIdentifier!));

                              // Show success and navigate to order success
                              if (mounted) {
                                NotificationHelper.showSuccess(
                                  context,
                                  'Thanh toán thành công!',
                                  'Đơn hàng đã được thanh toán qua VNPay.',
                                );

                                // Navigate to order success with suggestions
                                if (breeds.isNotEmpty) {
                                  onOrderSuccessWithBreeds(breeds);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const OrderSuccess(suggestions: []),
                                    ),
                                  );
                                }
                              }
                            } else {
                              print('❌ Payment failed for order: $orderId');
                            }
                          },
                        ),
                      ),
                    );
                  }
                }
              }
            } else if (vnpayState is VnpayError) {
              NotificationHelper.showError(
                context,
                'Lỗi thanh toán VNPay',
                vnpayState.message,
              );
            }
          },
          child: BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              if (state is CartLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is CartLoaded) {
                final List<Map<String, dynamic>> cartItems = state.items;
                if (cartItems.isEmpty) {
                  return const Center(child: Text("No items in your cart."));
                }
                List<CartModel> carts = cartItems.map((item) {
                  return CartModel(
                    grocery: {
                      ...item,
                      'price':
                          item["price"]?.toString() ?? '0', // Convert to String
                      'productId': item["productId"]?.toString() ?? '',
                      'name': item["name"]?.toString() ?? '',
                      'imageUrl': item["imageUrl"]?.toString() ?? '',
                    },
                    quantity: item["quantity"] ?? 1,
                  );
                }).toList();

                // Sync local selection with persisted selection from state
                final persistedSelected = state.selectedIds;
                if (_selectedProductIds.length != persistedSelected.length) {
                  _selectedProductIds
                    ..clear()
                    ..addAll(persistedSelected);
                }

                final selectedCount = _selectedProductIds.length;
                final selectedTotal = _calculateSelectedTotal(carts);

                return Column(
                  children: [
                    // Selection toolbar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selectedCount == carts.length &&
                                carts.isNotEmpty,
                            onChanged: (val) {
                              setState(() {
                                _selectAll = val ?? false;
                                _selectedProductIds.clear();
                                if (_selectAll) {
                                  for (final c in carts) {
                                    final id =
                                        c.grocery['productId']?.toString() ??
                                            '';
                                    if (id.isNotEmpty)
                                      _selectedProductIds.add(id);
                                  }
                                }
                              });
                              if (userIdentifier != null) {
                                context.read<CartBloc>().add(
                                    UpdateCartSelection(userIdentifier!,
                                        _selectedProductIds.toList()));
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LocalizationHelper.getLocalizedText(
                                  context, 'Chọn tất cả'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Chip(
                            backgroundColor: Colors.black12,
                            label: Text(
                              '${LocalizationHelper.getLocalizedText(context, 'Đã chọn')}: $selectedCount',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cart items list
                    Expanded(
                      child: ListView.separated(
                        itemCount: carts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cart = carts[index];
                          final id =
                              cart.grocery['productId']?.toString() ?? '';
                          final checked = _selectedProductIds.contains(id);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Material(
                              elevation: 1,
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final Map<String, dynamic>? pet =
                                      await getPetById(id);
                                  if (pet != null && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DetailPet(pet: pet),
                                      ),
                                    );
                                  }
                                },
                                child: SizedBox(
                                  height: 120,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 40),
                                          child: CartItem(cart: cart),
                                        ),
                                      ),
                                      Positioned(
                                        left: 8,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: Checkbox(
                                            value: checked,
                                            onChanged: (val) {
                                              setState(() {
                                                if ((val ?? false) &&
                                                    id.isNotEmpty) {
                                                  _selectedProductIds.add(id);
                                                } else {
                                                  _selectedProductIds
                                                      .remove(id);
                                                  _selectAll = false;
                                                }
                                              });
                                              if (userIdentifier != null) {
                                                context.read<CartBloc>().add(
                                                    UpdateCartSelection(
                                                        userIdentifier!,
                                                        _selectedProductIds
                                                            .toList()));
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Bottom bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, -4),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LocalizationHelper.getLocalizedText(
                                      context, 'total'),
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyHelper.formatVND(selectedTotal),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: ElevatedButton(
                              onPressed:
                                  selectedCount == 0 || userIdentifier == null
                                      ? null
                                      : () async {
                                          final selected = carts
                                              .where((c) =>
                                                  _selectedProductIds.contains(c
                                                          .grocery['productId']
                                                          ?.toString() ??
                                                      ''))
                                              .toList();
                                          if (selected.isEmpty) {
                                            return;
                                          }
                                          // Navigate to dedicated checkout screen and refresh cart when returning
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CheckoutScreen(
                                                userIdentifier: userIdentifier!,
                                                carts: selected,
                                              ),
                                            ),
                                          );
                                          if (!mounted) return;
                                          // Reload cart from Firestore to reflect purchased items removal
                                          context
                                              .read<CartBloc>()
                                              .add(LoadCart(userIdentifier!));
                                        },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                LocalizationHelper.getLocalizedText(
                                    context, 'checkout'),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                );
              } else if (state is CartError) {
                return const Center(child: Text("Error: DEL{state.message}"));
              } else {
                return const Center(child: Text("Unexpected error occurred"));
              }
            },
          ),
        ),
      ),
    );
  }
}
