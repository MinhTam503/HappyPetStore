import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:http/http.dart' as http;
import 'package:pet_shop/auth/payment/keys.dart';
import 'package:pet_shop/auth/stripe_helper.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/core/constants/list_city.dart';
import 'package:pet_shop/presentation/pages/mobile/order/orderSuccess.dart';
import 'package:pet_shop/presentation/pages/mobile/address/address_list_page.dart';
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

import '../pet/detail_pet.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? intentPaymentData;
  final UserManager userManager = UserManager();
  String? userIdentifier;

  // Thêm biến cho phương thức thanh toán và thông tin giao hàng
  String paymentMethod = 'paypal';
  List<Map<String, dynamic>> deliveryInfos = [];
  Map<String, dynamic>? selectedDeliveryInfo;
  Map<String, dynamic>? userInfo;

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

  Future<void> addNewAddress() async {
    String? selectedProvince;
    String? selectedDistrict;
    String detail = '';
    String name = userInfo?['displayName'] ?? '';
    String phone = userInfo?['phone'] ?? '';
    List<String> provinces = ListCity().city;
    Map<String, List<String>> districts = ListCity().districts;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Thêm thông tin giao hàng'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration:
                          const InputDecoration(labelText: 'Tên người nhận'),
                      onChanged: (value) => name = value,
                      controller: TextEditingController(text: name),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration:
                          const InputDecoration(labelText: 'Số điện thoại'),
                      onChanged: (value) => phone = value,
                      controller: TextEditingController(text: phone),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Tỉnh/Thành phố'),
                      value: selectedProvince,
                      items: provinces
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedProvince = value;
                          selectedDistrict = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Quận/Huyện'),
                      value: selectedDistrict,
                      items: (selectedProvince != null &&
                              districts[selectedProvince!] != null)
                          ? districts[selectedProvince!]!
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList()
                          : [],
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedDistrict = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                          labelText: 'Địa chỉ chi tiết (số nhà, tên đường...)'),
                      onChanged: (value) => detail = value,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedProvince != null &&
                        selectedDistrict != null &&
                        detail.trim().isNotEmpty &&
                        name.trim().isNotEmpty &&
                        phone.trim().isNotEmpty &&
                        userIdentifier != null) {
                      final newAddress =
                          '$detail, $selectedDistrict, $selectedProvince';
                      final newDeliveryInfo = {
                        'name': name.trim(),
                        'phone': phone.trim(),
                        'address': newAddress,
                        'isDefault': deliveryInfos.isEmpty,
                        'latitude': null, // Will be set when user chooses location on map
                        'longitude': null,
                      };

                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) return;

                      final userRef = FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid);

                      // Update deliveryInfos in Firestore
                      await userRef.update({
                        'deliveryInfos':
                            FieldValue.arrayUnion([newDeliveryInfo])
                      });

                      setState(() {
                        deliveryInfos.add(newDeliveryInfo);
                        selectedDeliveryInfo = newDeliveryInfo;
                      });

                      Navigator.pop(context);
                    } else {
                      NotificationHelper.showWarning(
                        context,
                        'Thông tin chưa đầy đủ',
                        'Vui lòng nhập đầy đủ thông tin giao hàng',
                      );
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _navigateToAddressList() async {
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
    
    // Refresh addresses after returning from address list
    if (result != null) {
      fetchAddresses();
    }
  }

  double _calculateTotal(List<CartModel> carts) {
    double total = 0.0;
    print("🧮 Calculating total for ${carts.length} items:");
    
    for (var item in carts) {
      final priceStr = item.grocery["price"].toString();
      final price = double.tryParse(priceStr) ?? 0.0;
      final quantity = item.quantity;
      final itemTotal = quantity * price;
      
      print("  - ${item.grocery["name"]}: $priceStr (parsed: $price) x $quantity = ${CurrencyHelper.formatVND(itemTotal)}");
      total += itemTotal;
    }
    
    print("🧮 Total calculated: ${CurrencyHelper.formatVND(total)}");
    return total;
  }

  Future<List<String>> saveOrderToFirestore(
      String userIdentifier, List<CartModel> cartItems,
      {bool isPaid = true}) async {
    // Đảm bảo UserManager được initialize
    await userManager.initialize();

    final totalAmount = _calculateTotal(cartItems);
    print("💰 Total amount to save to Firestore: ${CurrencyHelper.formatVND(totalAmount)}");
    
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

    // Extract address from selectedDeliveryInfo
    final shippingAddress = selectedDeliveryInfo?['address'] ?? "Địa chỉ không xác định";
    final shippingName = selectedDeliveryInfo?['name'] ?? userInfoForOrder?['displayName'] ?? "";
    final shippingPhone = selectedDeliveryInfo?['phone'] ?? userInfoForOrder?['phone'] ?? "";
    
    final orderData = {
      "orderId": orderRef.id,
      "userIdentifier": userIdentifier,
      "userId": userInfoForOrder?['userId'] ?? userIdentifier,
      "email": userInfoForOrder?['email'] ?? currentUserEmail ?? userIdentifier,
      "phone": userInfoForOrder?['phone'] ?? (userInfo?["phone"] ?? ""),
      "displayName": userInfoForOrder?['displayName'] ?? "",
      "address": shippingAddress, // Add shipping address directly
      "totalAmount": totalAmount,
      "statusPayment": isPaid
          ? (paymentMethod == 'paypal' ? "Payment Completed" : "COD")
          : "COD",
      "statusOrder": "Pending",
      "timestamp": FieldValue.serverTimestamp(),
      "paymentMethod": paymentMethod,
      // Complete shipping information
      "shippingAddress": shippingAddress,
      "shippingInfo": selectedDeliveryInfo ?? {},
      "deliveryInfo": selectedDeliveryInfo != null ? {
        "name": shippingName,
        "phone": shippingPhone,
        "address": shippingAddress,
        "isDefault": selectedDeliveryInfo!['isDefault'] ?? false,
        "latitude": selectedDeliveryInfo!['latitude'],
        "longitude": selectedDeliveryInfo!['longitude'],
      } : {},
      "items": items,
    };

    print("💾 Saving order with user info:");
    print("  - userId: ${orderData['userId']}");
    print("  - email: ${orderData['email']}");
    print("  - phone: ${orderData['phone']}");
    print("  - displayName: ${orderData['displayName']}");
    print("  - address: ${orderData['address']}");
    print("  - shippingAddress: ${orderData['shippingAddress']}");
    print("  - shippingInfo: ${orderData['shippingInfo']}");
    print("  - deliveryInfo: ${orderData['deliveryInfo']}");
    print("🌱 Collected breeds for Apriori: $breeds");

    await orderRef.set(orderData);

    // Gửi thông báo đơn hàng đã được đặt
    final orderUserId = orderData['userId']?.toString();
    final orderUserName = orderData['displayName']?.toString();

    if (orderUserId != null && orderUserId.isNotEmpty) {
      await OrderNotificationHelper.sendOrderPlacedNotification(
        userId: orderUserId,
        orderId: orderRef.id,
        customerName: orderUserName,
        totalAmount: totalAmount,
      );
    }

    // Return unique breeds for Apriori analysis
    return breeds.toSet().toList();
  }

  Future<void> showPaymentSheet(
      String userIdentifier, List<CartModel> cartItems) async {
    try {
      await Stripe.instance.presentPaymentSheet();

      for (var item in cartItems) {
        final docRef = FirebaseFirestore.instance
            .collection('Pets')
            .doc(item.grocery["id"]);
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          await docRef.update({
            "status": "sold",
            "isAvailable": false,
          });
        } else {
          print("Pet with id ${item.grocery["id"]} not found in Firestore.");
        }
      }

      // Save order and get breeds for Apriori analysis
      final breeds =
          await saveOrderToFirestore(userIdentifier, cartItems, isPaid: true);
      context.read<CartBloc>().add(ClearCart(userIdentifier));

      if (!context.mounted) return;

      // Show success notification
      NotificationHelper.showSuccess(
        context,
        'Thanh toán thành công!',
        'Đơn hàng của bạn đã được thanh toán và sẽ được giao sớm nhất.',
      );

      // Use new multi-breed analysis with extracted breeds
      if (breeds.isNotEmpty) {
        print("🌱 Stripe payment: Using breeds for Apriori: $breeds");
        onOrderSuccessWithBreeds(breeds);
      } else {
        print("⚠️ Stripe payment: No breeds found, using fallback");
        onOrderSuccessWithSuggestions(cartItems);
      }

      setState(() {
        intentPaymentData = null;
      });
    } on StripeException catch (e) {
      NotificationHelper.showError(
        context,
        'Thanh toán thất bại',
        e.error.message ?? 'Đã xảy ra lỗi trong quá trình thanh toán',
      );
    } catch (error) {
      NotificationHelper.showError(
        context,
        'Lỗi thanh toán',
        'Lỗi không mong muốn: ${error.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>?> makeIntentForPayment(amount, currency) async {
    try {
      // Debug: Check if keys are available (safe substring)
      final pubKeyPreview = PublishableKey.length > 20
          ? "${PublishableKey.substring(0, 20)}..."
          : PublishableKey.isNotEmpty
              ? "$PublishableKey (short)"
              : "EMPTY!";
      final secKeyPreview = SecretKey.length > 20
          ? "${SecretKey.substring(0, 20)}..."
          : SecretKey.isNotEmpty
              ? "$SecretKey (short)"
              : "EMPTY!";

      print("🔐 PublishableKey: $pubKeyPreview");
      print("🔐 SecretKey: $secKeyPreview");

      if (SecretKey.isEmpty) {
        print("❌ ERROR: SecretKey is empty!");
        return null;
      }

      Map<String, dynamic>? paymentInfo = {
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

      print(" Payment intent created successfully");
      return jsonDecode(response.body);
    } catch (error) {
      print(" Stripe Error: $error");
      return null;
    }
  }

  void paymentInit(double amount, String currency, String userIdentifier,
      List<CartModel> carts) async {
    try {
      // Check if Stripe is ready for use
      final canUse = await StripeHelper.canUseStripe();
      if (!canUse) {
        // Show error and ask user what to do
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lỗi thanh toán Stripe'),
            content: const Text(
              'Không thể khởi tạo thanh toán Stripe. Bạn có muốn chuyển sang thanh toán khi nhận hàng không?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  try {
                    final breeds = await saveOrderToFirestore(userIdentifier, carts, isPaid: false);
                    context.read<CartBloc>().add(ClearCart(userIdentifier));
                    
                    if (!context.mounted) return;
                    
                    NotificationHelper.showSuccess(
                      context,
                      'Đặt hàng thành công!',
                      'Đơn hàng sẽ được thanh toán khi nhận hàng.',
                    );
                    
                    if (breeds.isNotEmpty) {
                      onOrderSuccessWithBreeds(breeds);
                    } else {
                      onOrderSuccessWithSuggestions(carts);
                    }
                  } catch (fallbackError) {
                    NotificationHelper.showError(
                      context,
                      'Lỗi đặt hàng',
                      'Không thể tạo đơn hàng: $fallbackError',
                    );
                  }
                },
                child: const Text('Chuyển COD'),
              ),
            ],
          ),
        );
        return;
      }

      // Convert VND to USD (approximate rate: 1 USD = 24,000 VND)
      double amountInUSD = amount;
      print("💱 Payment conversion: Original amount = ${CurrencyHelper.formatVND(amount)}");
      
      if (currency.toLowerCase() == 'vnd') {
        amountInUSD = amount / 24000; // Convert VND to USD
        currency = 'usd';
        print("💱 Converted to USD: \$${amountInUSD.toStringAsFixed(2)}");
      } else {
        print("💱 Currency is already: $currency");
      }

      // Check Stripe limits (max $999,999 USD per transaction)
      if (amountInUSD > 999999) {
        NotificationHelper.showWarning(
          context,
          'Số tiền vượt quá giới hạn',
          'Số tiền quá lớn cho thanh toán Stripe (tối đa \$999,999 USD ≈ ${CurrencyHelper.formatVND(999999 * 24000)}). Vui lòng chọn thanh toán khi nhận hàng.',
        );
        return;
      }

      // Check minimum amount (Stripe minimum is $0.50 USD)
      if (amountInUSD < 0.5) {
        NotificationHelper.showWarning(
          context,
          'Số tiền quá nhỏ',
          'Số tiền quá nhỏ cho thanh toán Stripe (tối thiểu \$0.50 USD)',
        );
        return;
      }

      intentPaymentData = await makeIntentForPayment(amountInUSD, currency);
      if (intentPaymentData == null) {
        NotificationHelper.showError(
          context,
          'Lỗi thanh toán',
          'Không thể tạo giao dịch thanh toán. Vui lòng thử lại.',
        );
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          allowsDelayedPaymentMethods: true,
          paymentIntentClientSecret: intentPaymentData?["client_secret"],
          style: ThemeMode.light,
          merchantDisplayName: "Pet Shop",
        ),
      );

      showPaymentSheet(userIdentifier, carts);
    } catch (e, s) {
      print("Payment Init Error: $e\n$s");
      NotificationHelper.showError(
        context,
        'Lỗi thanh toán Stripe',
        'Đã có lỗi xảy ra: $e',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getSuggestionsForCart(
      List<CartModel> carts) async {
    if (carts.isEmpty) {
      print("Cart is empty, no suggestions needed");
      return [];
    }

    try {
      final firstPet = carts.first.grocery;
      print("First pet data: ${firstPet.toString()}");

      // Lấy thông tin breed từ Firestore
      final petDoc = await FirebaseFirestore.instance
          .collection('Pets')
          .doc(firstPet["productId"])
          .get();

      if (petDoc.exists) {
        final breed = petDoc.data()?['breed'];
        print("Getting Apriori suggestions for breed from Firestore: $breed");
        if (breed != null) {
          // Use Apriori BLoC instead of FP-Growth
          context.read<AprioriBloc>().add(GetSuggestionsFromSingleBreed(breed));

          // For now, return empty list - suggestions will be handled by BLoC
          // This method should be refactored to use BLoC properly
          print("Triggered Apriori BLoC analysis for breed: $breed");
          return [];
        }
      }
      print(
          "No breed information found for pet with id: ${firstPet["productId"]}");
    } catch (e) {
      print("Error getting suggestions: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>?> getPetById(String petId) async {
    try {
      final docSnapshot =
          await FirebaseFirestore.instance.collection('Pets').doc(petId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data();
      } else {
        print('Không tìm thấy thú cưng với ID: $petId');
        return null;
      }
    } catch (e) {
      print('Lỗi khi lấy dữ liệu thú cưng: $e');
      return null;
    }
  }

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
        title: const Text(
          "My Cart",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
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

              final double totalPrice = _calculateTotal(carts);
              return Column(
                children: [
                  // Thông tin giao hàng - New Design
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _navigateToAddressList(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Địa chỉ giao hàng',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (selectedDeliveryInfo != null) ...[
                                      Text(
                                        '${selectedDeliveryInfo!['name']} • ${selectedDeliveryInfo!['phone']}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedDeliveryInfo!['address'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ] else ...[
                                      const Text(
                                        'Chưa có địa chỉ giao hàng',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Nhấn để thêm địa chỉ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Phương thức thanh toán (Dropdown)
                  Expanded(
                    child: ListView.builder(
                      itemCount: carts.length,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () async {
                          final Map<String, dynamic>? pet = await getPetById(
                              carts[index].grocery['productId']);
                          if (pet != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailPet(pet: pet),
                              ),
                            );
                          }
                        },
                        child: SizedBox(
                          height: 100,
                          child: CartItem(cart: carts[index]),
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 8),
                          child: Row(
                            children: [
                              const Text("Phương thức \n thanh toán:",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 30),
                              Expanded(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: paymentMethod,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'paypal',
                                      child: Text('Thanh toán qua PayPal'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'cod',
                                      child: Text('Thanh toán khi nhận hàng'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      paymentMethod = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total",
                                style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            Text(
                              CurrencyHelper.formatVND(totalPrice),
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 2 / 3,
                          child: ElevatedButton(
                            onPressed: () async {
                              print("Order button pressed");

                              // Show loading dialog
                              DialogHelper.showLoadingDialog(context);

                              try {
                                // Kiểm tra thông tin giao hàng
                                print("🔍 DEBUG: Checking delivery info...");
                                print("🔍 selectedDeliveryInfo: $selectedDeliveryInfo");
                                print("🔍 deliveryInfos.length: ${deliveryInfos.length}");
                                
                                if (selectedDeliveryInfo == null ||
                                    deliveryInfos.isEmpty) {
                                  DialogHelper.hideLoadingDialog(context);
                                  NotificationHelper.showWarning(
                                    context,
                                    'Thiếu thông tin giao hàng',
                                    'Vui lòng thêm thông tin giao hàng trước khi đặt hàng',
                                  );
                                  return;
                                }

                                // Kiểm tra số điện thoại từ Firestore
                                final currentUser =
                                    FirebaseAuth.instance.currentUser;
                                if (currentUser != null) {
                                  final userDoc = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(currentUser.uid)
                                      .get();

                                  if (userDoc.exists) {
                                    final userData = userDoc.data()!;
                                    final phoneFromFirestore =
                                        userData['phone'];

                                    if (phoneFromFirestore == null ||
                                        phoneFromFirestore
                                            .toString()
                                            .trim()
                                            .isEmpty) {
                                      DialogHelper.hideLoadingDialog(context);
                                      NotificationHelper.showWarning(
                                        context,
                                        'Thiếu số điện thoại',
                                        'Vui lòng cập nhật số điện thoại trong hồ sơ cá nhân trước khi đặt hàng!',
                                      );
                                      return;
                                    }
                                  }
                                }
                                final currentUserIdentifier = userIdentifier;
                                if (currentUserIdentifier == null) {
                                  DialogHelper.hideLoadingDialog(context);
                                  return;
                                }

                                if (paymentMethod == 'paypal') {
                                  DialogHelper.hideLoadingDialog(context);
                                  print("Starting PayPal payment...");
                                  paymentInit(totalPrice, "vnd",
                                      currentUserIdentifier, carts);
                                } else {
                                  print(
                                      "🛒 COD PAYMENT: Starting COD payment process...");

                                  // Save order và lấy breeds từ Firestore
                                  final breeds = await saveOrderToFirestore(
                                      currentUserIdentifier, carts,
                                      isPaid: false);

                                  // Xóa giỏ hàng
                                  context
                                      .read<CartBloc>()
                                      .add(ClearCart(currentUserIdentifier));
                                  print("🛒 COD PAYMENT: Cart cleared");

                                  // Hide loading và sử dụng multi-breed analysis
                                  DialogHelper.hideLoadingDialog(context);
                                  
                                  // Show success notification
                                  NotificationHelper.showSuccess(
                                    context,
                                    'Đặt hàng thành công!',
                                    'Đơn hàng của bạn đã được tạo và sẽ được giao sớm nhất.',
                                  );

                                  if (!context.mounted) return;
                                  print(
                                      "🚀 COD PAYMENT: About to trigger Apriori with breeds: $breeds");

                                  if (breeds.isNotEmpty) {
                                    onOrderSuccessWithBreeds(breeds);
                                  } else {
                                    print(
                                        "🚫 No breeds found, navigating with empty suggestions");
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const OrderSuccess(suggestions: []),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                DialogHelper.hideLoadingDialog(context);
                                print("Error in order process: $e");
                                NotificationHelper.showError(
                                  context,
                                  'Lỗi đặt hàng',
                                  'Có lỗi xảy ra: $e',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Đặt hàng",
                              style:
                                  TextStyle(color: Colors.black, fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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
    );
  }
}
