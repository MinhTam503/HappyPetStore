import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:pet_shop/utils/list_city.dart';
import 'package:pet_shop/view/mobile/orderSuccess.dart';
import '../../../bloc/model/cart_model.dart';
import '../../../services/apriori/apriori_algorithm.dart';
import '../../../auth/payment/keys.dart';
import '../../../utils/contants.dart';
import '../../../widgets/cart_item.dart';
import '../../../bloc/cartBloc/cart_bloc.dart';
import '../../../bloc/cartBloc/cart_event.dart';
import '../../../bloc/cartBloc/cart_state.dart';
import '../../../auth/auth_service.dart';
import '../detail_pet.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? intentPaymentData;
  String? email = FirebaseAuth.instance.currentUser?.email;

  // Thêm biến cho phương thức thanh toán và địa chỉ
  String paymentMethod = 'paypal';
  List<String> addresses = [];
  String? selectedAddress;
  Map<String, dynamic>? userInfo;

  @override
  void initState() {
    super.initState();
    if (email != null) {
      context.read<CartBloc>().add(LoadCart(email!));
      fetchAddresses();
      fetchUserInfo();
    }
  }

  Future<void> fetchAddresses() async {
    if (email == null) return;
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (userQuery.docs.isEmpty) {
      setState(() {
        addresses = [];
        selectedAddress = null;
      });
      return;
    }
    final userDoc = userQuery.docs.first.data();
    var addr = userDoc['address'];
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
    if (email == null) return;
    userInfo = await authService.value.getInfoUserFromEmail(email!);
    setState(() {});
  }

  void onOrderSuccess(String selectedBreed) async {
    final suggestions =
        await AprioriAlgorithm().getSuggestedPets(selectedBreed);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccess(suggestions: suggestions),
      ),
    );
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
                        email != null) {
                      final newAddress =
                          '$detail, $selectedDistrict, $selectedProvince';
                      final userQuery = await FirebaseFirestore.instance
                          .collection('users')
                          .where('email', isEqualTo: email)
                          .limit(1)
                          .get();
                      if (userQuery.docs.isEmpty) return;
                      final userRef = userQuery.docs.first.reference;
                      final userDoc = userQuery.docs.first.data();
                      var addr = userDoc['address'];
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
        final weight = double.tryParse(item.grocery["price"].toString()) ?? 0.0;
        return sum + (item.quantity * weight);
      },
    );
  }

  Future<void> saveOrderToFirestore(String email, List<CartModel> cartItems,
      {bool isPaid = true}) async {
    final totalAmount = _calculateTotal(cartItems);
    final orderRef = FirebaseFirestore.instance.collection('orders').doc();

    // Lấy đầy đủ thông tin thú cưng từ Firestore
    List<Map<String, dynamic>> items = [];
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
        petData['price'] = petDoc.get('weight');
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

    final orderData = {
      "orderId": orderRef.id,
      "email": email,
      "phone": userInfo != null ? userInfo!["phone"] ?? "" : "",
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

    await orderRef.set(orderData);
  }

  Future<void> showPaymentSheet(String email, List<CartModel> cartItems) async {
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

      await saveOrderToFirestore(email, cartItems, isPaid: true);
      context.read<CartBloc>().add(ClearCart(email));

      // Chuẩn bị suggestions cho OrderSuccess
      List<Map<String, dynamic>> suggestions = [];
      try {
        if (cartItems.isNotEmpty) {
          final firstPet = cartItems.first.grocery;
          print("Processing breed: ${firstPet["breed"]}");
          if (firstPet["breed"] != null) {
            suggestions =
                await AprioriAlgorithm().getSuggestedPets(firstPet["breed"]);
            print("Found ${suggestions.length} suggestions");
          }
        }
      } catch (e) {
        print("Error getting suggestions: $e");
      }

      // Chuyển đến trang thành công
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccess(suggestions: suggestions),
        ),
      );

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
        print("Stripe API Error: ${response.body}");
        return null;
      }

      return jsonDecode(response.body);
    } catch (error) {
      print("Stripe Error: $error");
      return null;
    }
  }

  void paymentInit(double amount, String currency, String email,
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

      showPaymentSheet(email, carts);
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
        print("Getting suggestions for breed from Firestore: $breed");
        if (breed != null) {
          final suggestions = await AprioriAlgorithm().getSuggestedPets(breed);
          print("Got ${suggestions.length} suggestions");
          for (var suggestion in suggestions) {
            print("Suggestion: ${suggestion['breed']} - ${suggestion['name']}");
          }
          return suggestions;
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
                  grocery: item,
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
                                builder: (context) => DetailPet(grocery: pet),
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
                              "\$${totalPrice.toStringAsFixed(2)}",
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
                              // Kiểm tra địa chỉ giao hàng
                              if (selectedAddress == null ||
                                  addresses.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Vui lòng chọn địa chỉ giao hàng trước khi đặt hàng"),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              // Kiểm tra phone
                              if (userInfo == null ||
                                  userInfo!["phone"] == null ||
                                  userInfo!["phone"]
                                      .toString()
                                      .trim()
                                      .isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Vui lòng bổ sung số điện thoại trong hồ sơ trước khi đặt hàng!"),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              final userEmail = email;
                              if (userEmail == null) return;

                              if (paymentMethod == 'paypal') {
                                print("Starting PayPal payment...");
                                paymentInit(
                                    totalPrice, "usd", userEmail, carts);
                              } else {
                                print("Starting COD payment process...");
                                await saveOrderToFirestore(userEmail, carts,
                                    isPaid: false);

                                // Xóa giỏ hàng
                                context
                                    .read<CartBloc>()
                                    .add(ClearCart(userEmail));
                                print("Cart cleared");

                                // Lấy thông tin breed từ Firestore
                                List<Map<String, dynamic>> suggestions = [];
                                if (carts.isNotEmpty) {
                                  final firstPet = carts.first.grocery;
                                  print(
                                      "First pet ID: ${firstPet["productId"]}");

                                  final petDoc = await FirebaseFirestore
                                      .instance
                                      .collection('Pets')
                                      .doc(firstPet["productId"])
                                      .get();

                                  if (petDoc.exists) {
                                    final breed = petDoc.data()?['breed'];
                                    print("Found breed from Firestore: $breed");
                                    if (breed != null) {
                                      suggestions = await AprioriAlgorithm()
                                          .getSuggestedPets(breed);
                                      print(
                                          "Got ${suggestions.length} suggestions");
                                      suggestions.forEach((pet) {
                                        print(
                                            "Suggestion: ${pet['breed']} - ${pet['name']}");
                                      });
                                    }
                                  } else {
                                    print(
                                        "Pet document does not exist for ID: ${firstPet["productId"]}");
                                  }
                                }

                                // Chuyển đến trang thành công
                                print(
                                    "Navigating to OrderSuccess with ${suggestions.length} suggestions");
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        OrderSuccess(suggestions: suggestions),
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
