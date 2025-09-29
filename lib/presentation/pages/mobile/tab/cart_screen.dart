import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:pet_shop/auth/payment/keys.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/core/constants/list_city.dart';
import 'package:pet_shop/presentation/pages/mobile/orderSuccess.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import '../../../bloc/model/cart_model.dart';
import '../../../bloc/apriori/apriori_bloc.dart';
import '../../../bloc/apriori/apriori_event.dart';
import '../../../bloc/apriori/apriori_state.dart';

import '../../../widgets/cart_item.dart';
import '../../../bloc/cartBloc/cart_bloc.dart';
import '../../../bloc/cartBloc/cart_event.dart';
import '../../../bloc/cartBloc/cart_state.dart';

import '../detail_pet.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? intentPaymentData;
  final UserManager userManager = UserManager();
  String? userIdentifier;

  // Thêm biến cho phương thức thanh toán và địa chỉ
  String paymentMethod = 'paypal';
  List<String> addresses = [];
  String? selectedAddress;
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
        addresses = [];
        selectedAddress = null;
      });
      return;
    }

    final userData = userDoc.data()!;
    var addr = userData['address'];
    if (addr == null || (addr is String && addr.isEmpty)) {
      setState(() {
        addresses = [];
        selectedAddress = null;
      });
    } else if (addr is List) {
      setState(() {
        addresses = List<String>.from(addr);
        if (addresses.isNotEmpty) selectedAddress = addresses[0];
      });
    }
  }

  Future<void> fetchUserInfo() async {
    if (userIdentifier == null) return;
    
    // Đảm bảo UserManager được initialize
    await userManager.initialize();
    
    userInfo = await userManager.getCurrentUserInfo();
    print("👤 Fetched user info: email=${userInfo?['email']}, phone=${userInfo?['phone']}");
    setState(() {});
  }

  void onOrderSuccessWithBreeds(List<String> breeds) async {
    print('🚀 MULTI-BREED ANALYSIS: onOrderSuccessWithBreeds called with ${breeds.length} breeds: $breeds');
    
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
    print('🚀 MULTI-BREED ANALYSIS: onOrderSuccessWithSuggestions called with ${cartItems.length} items');
    
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
    List<String> provinces = ListCity().city;
    Map<String, List<String>> districts = ListCity().districts;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Thêm địa chỉ mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                          labelText:
                              'Thông tin chi tiết (số nhà, tên đường...)'),
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
                        userIdentifier != null) {
                      final newAddress =
                          '$detail, $selectedDistrict, $selectedProvince';

                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) return;

                      final userRef = FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid);
                      final userDoc = await userRef.get();

                      if (!userDoc.exists) return;

                      final userData = userDoc.data()!;
                      var addr = userData['address'];
                      if (addr == null || (addr is String && addr.isEmpty)) {
                        await userRef.update({
                          'address': [newAddress]
                        });
                        setState(() {
                          addresses = [newAddress];
                          selectedAddress = newAddress;
                        });
                      } else if (addr is List) {
                        await userRef.update({
                          'address': FieldValue.arrayUnion([newAddress])
                        });
                        setState(() {
                          addresses.add(newAddress);
                          selectedAddress = newAddress;
                        });
                      }
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Vui lòng nhập đầy đủ thông tin"),
                        ),
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

  double _calculateTotal(List<CartModel> carts) {
    return carts.fold(
      0.0,
      (sum, item) {
        final price = double.tryParse(item.grocery["price"].toString()) ?? 0.0;
        return sum + (item.quantity * price);
      },
    );
  }

  Future<List<String>> saveOrderToFirestore(
      String userIdentifier, List<CartModel> cartItems,
      {bool isPaid = true}) async {
    
    // Đảm bảo UserManager được initialize
    await userManager.initialize();
    
    final totalAmount = _calculateTotal(cartItems);
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
        
        petData['price'] = petDoc.data().toString().contains('price')
            ? petDoc.get('price')
            : petDoc.get('weight');
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
    
    final orderData = {
      "orderId": orderRef.id,
      "userIdentifier": userIdentifier,
      "userId": userInfoForOrder?['userId'] ?? userIdentifier,
      "email": userInfoForOrder?['email'] ?? currentUserEmail ?? userIdentifier,
      "phone": userInfoForOrder?['phone'] ?? (userInfo?["phone"] ?? ""),
      "displayName": userInfoForOrder?['displayName'] ?? "",
      "totalAmount": totalAmount,
      "statusPayment": isPaid
          ? (paymentMethod == 'paypal' ? "Payment Completed" : "COD")
          : "COD",
      "statusOrder": "Pending",
      "timestamp": FieldValue.serverTimestamp(),
      "paymentMethod": paymentMethod,
      "shippingAddress": selectedAddress ?? '',
      "items": items,
    };

    print("💾 Saving order with user info:");
    print("  - userId: ${orderData['userId']}");
    print("  - email: ${orderData['email']}");
    print("  - phone: ${orderData['phone']}");
    print("  - displayName: ${orderData['displayName']}");
    print("🌱 Collected breeds for Apriori: $breeds");

    await orderRef.set(orderData);
    
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
      final breeds = await saveOrderToFirestore(userIdentifier, cartItems, isPaid: true);
      context.read<CartBloc>().add(ClearCart(userIdentifier));

      if (!context.mounted) return;

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
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Payment Failed"),
          content: Text(e.error.message ?? "An error occurred"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Try Again"),
            ),
          ],
        ),
      );
    } catch (error) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Payment Error"),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
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
      intentPaymentData = await makeIntentForPayment(amount, currency);
      if (intentPaymentData == null) return;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          allowsDelayedPaymentMethods: true,
          paymentIntentClientSecret: intentPaymentData?["client_secret"],
          style: ThemeMode.dark,
          merchantDisplayName: "MinhTam",
        ),
      );

      showPaymentSheet(userIdentifier, carts);
    } catch (e, s) {
      print("Payment Init Error: $e\n$s");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
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
                  // Địa chỉ giao hàng
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                    child: Row(
                      children: [
                        const Text('Địa chỉ giao hàng:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedAddress,
                            hint: const Text('Chọn địa chỉ'),
                            items: addresses
                                .map((address) => DropdownMenuItem(
                                      value: address,
                                      child: Text(address,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedAddress = value;
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_location_alt_outlined),
                          onPressed: addNewAddress,
                          tooltip: 'Thêm địa chỉ mới',
                        ),
                      ],
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
                                // Kiểm tra địa chỉ giao hàng
                                if (selectedAddress == null ||
                                    addresses.isEmpty) {
                                  DialogHelper.hideLoadingDialog(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Vui lòng chọn địa chỉ giao hàng trước khi đặt hàng"),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }

                                // Kiểm tra số điện thoại
                                if (userInfo == null ||
                                    userInfo!["phone"] == null ||
                                    userInfo!["phone"].toString().trim().isEmpty) {
                                  DialogHelper.hideLoadingDialog(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Vui lòng bổ sung số điện thoại trong hồ sơ trước khi đặt hàng!"),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                final currentUserIdentifier = userIdentifier;
                                if (currentUserIdentifier == null) {
                                  DialogHelper.hideLoadingDialog(context);
                                  return;
                                }

                                if (paymentMethod == 'paypal') {
                                DialogHelper.hideLoadingDialog(context);
                                print("Starting PayPal payment...");
                                paymentInit(totalPrice, "usd",
                                    currentUserIdentifier, carts);
                              } else {
                                print("🛒 COD PAYMENT: Starting COD payment process...");
                                
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
                                
                                if (!context.mounted) return;
                                print("🚀 COD PAYMENT: About to trigger Apriori with breeds: $breeds");
                                
                                if (breeds.isNotEmpty) {
                                  onOrderSuccessWithBreeds(breeds);
                                } else {
                                  print("🚫 No breeds found, navigating with empty suggestions");
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const OrderSuccess(suggestions: []),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              DialogHelper.hideLoadingDialog(context);
                              print("Error in order process: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Có lỗi xảy ra: $e"),
                                  duration: Duration(seconds: 3),
                                ),
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
