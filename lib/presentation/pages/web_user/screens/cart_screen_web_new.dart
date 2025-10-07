import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/bloc/cart_bloc_web/cart_bloc_web.dart';
import 'package:pet_shop/presentation/pages/web_user/screens/stripe_payment_screen.dart';
import 'package:pet_shop/services/shipping_service.dart';

import 'package:pet_shop/presentation/bloc/cart_bloc_web/cart_state_web.dart';
import 'package:pet_shop/presentation/bloc/cart_bloc_web/cart_event_web.dart';

class CartScreenWeb extends StatefulWidget {
  const CartScreenWeb({super.key});

  @override
  State<CartScreenWeb> createState() => _CartScreenWebState();
}

class _CartScreenWebState extends State<CartScreenWeb> {
  // Shipping fee calculation
  double shippingFee = 0.0;
  bool isCalculatingShipping = false;
  
  double _priceOf(Map<String, dynamic> item) {
  final raw = item['price'] ?? 0;
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  double _total(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, it) => sum + _priceOf(it));
  }
  
  double _grandTotal(List<Map<String, dynamic>> items) {
    return _total(items) + shippingFee;
  }
  
  Future<void> calculateShippingFee(List<Map<String, dynamic>> items, String address) async {
    if (items.isEmpty || address.isEmpty) {
      setState(() {
        shippingFee = 0.0;
      });
      return;
    }

    setState(() {
      isCalculatingShipping = true;
    });

    try {
      final totalValue = _total(items);
      final totalWeight = items.length * 1.5; // Estimate 1.5kg per pet
      
      final result = await ShippingService.calculateShippingFee(
        shippingAddress: address,
        totalValue: totalValue,
        totalWeight: totalWeight,
        customerInfo: {
          'name': 'Web Customer',
          'phone': '0123456789',
        },
      );
      
      if (result['success']) {
        setState(() {
          shippingFee = result['data']['shippingFee'].toDouble();
        });
      } else {
        // Fallback to default shipping fee
        setState(() {
          shippingFee = 30000.0; // Default 30k VND
        });
      }
    } catch (e) {
      print('❌ Error calculating shipping fee: $e');
      setState(() {
        shippingFee = 30000.0; // Default 30k VND
      });
    } finally {
      setState(() {
        isCalculatingShipping = false;
      });
    }
  }

    // ---------------------- SAVE ORDER ----------------------
  Future<void> _saveOrderToFirestore({
    required String customerEmail,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? sessionId,
  }) async {
    try {
      // Use 'ordersWeb' collection for web orders
      final orderRef = FirebaseFirestore.instance.collection('ordersWeb').doc();
      
      // Process items to get full pet data like mobile version
      List<Map<String, dynamic>> processedItems = [];
      for (var item in items) {
        final petDoc = await FirebaseFirestore.instance
            .collection('Pets')
            .doc(item['productId'])
            .get();
            
        Map<String, dynamic> petData = {};
        if (petDoc.exists) {
          final docData = petDoc.data()!;
          petData = {
            'productId': petDoc.id,
            'name': docData['name'] ?? 'Unknown Pet',
            'breed': docData['breed'] ?? '',
            'imageUrl': docData['imageUrl'] ?? '',
            'price': (docData['price'] ?? docData['weight'])?.toString() ?? '0',
            'quantity': item['quantity'] ?? 1,
          };
        } else {
          // Fallback if pet not found
          petData = {
            'productId': item['productId'],
            'name': item['name'] ?? 'Unknown Pet',
            'breed': item['breed'] ?? '',
            'imageUrl': item['imageUrl'] ?? '',
            'price': item['price']?.toString() ?? '0',
            'quantity': item['quantity'] ?? 1,
          };
        }
        processedItems.add(petData);
      }

      final orderData = {
        "orderId": orderRef.id,
        "email": customerEmail,
        "fullName": customerName, // Changed from customerName to fullName to match format
        "phone": customerPhone,
        "address": customerAddress, // Changed from customerAddress to address
        "totalAmount": totalAmount + shippingFee, // Include shipping fee
        "subtotal": totalAmount, // Keep subtotal separate  
        "shippingFee": shippingFee, // Store shipping fee separately
        "statusPayment": "Pending Payment", // Always pending - payment success will update
        "statusOrder": "Pending", // Always pending - payment success will update
        "timestamp": FieldValue.serverTimestamp(),
        "paymentMethod": "stripe_web", // Consistent payment method
        "tempOrderId": sessionId, // Store temp ID for payment success to find
        "stripeSessionId": null, // Will be updated by payment success screen
        "backendOrderId": "web_order_${DateTime.now().millisecondsSinceEpoch}", // Add backend order ID
        "items": processedItems,
        "source": "web_checkout", // Add source identifier
      };

      await orderRef.set(orderData);
      
      // Create shipping after saving order
      try {
        final totalWeight = items.length * 1.5; // Estimate 1.5kg per pet
        final customerInfo = {
          'name': customerName,
          'phone': customerPhone,
          'email': customerEmail,
        };

        final shippingResult = await ShippingService.createShipment(
          orderId: orderRef.id,
          shippingAddress: customerAddress,
          customerInfo: customerInfo,
          totalWeight: totalWeight,
          totalValue: totalAmount,
          items: processedItems,
        );

        if (shippingResult['success']) {
          final shipmentData = shippingResult['data'];
          final trackingNumber = shipmentData['trackingNumber'];

          // Update order with shipping info
          await orderRef.update({
            'trackingNumber': trackingNumber,
            'shippingInfo': shipmentData,
          });

          print('✅ Shipping created successfully: $trackingNumber');
        } else {
          print('⚠️ Shipping creation failed: ${shippingResult['message']}');
        }
      } catch (e) {
        print('❌ Error creating shipping: $e');
        // Continue even if shipping fails - order is already saved
      }
      
      if (kDebugMode) {
        print('🛒 Order saved to ordersWeb collection: ${orderRef.id}');
        print(' Backend Order ID: web_demo_${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (e) {
      if (kDebugMode) {
        print(' Error saving order: $e');
      }
    }
  }

  // ---------------------- PAYMENT PROCESS ----------------------
  Future<bool> _payWithStripePaymentScreen({
    required double totalAmount,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String customerEmail,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      if (kDebugMode) {
        print(' Navigating to Stripe Payment Screen...');
        print(' Total: \$${totalAmount.toStringAsFixed(2)}');
      }

      // Navigate to Stripe Payment Screen
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => StripePaymentScreen(
            totalAmount: totalAmount,
            customerName: customerName,
            customerPhone: customerPhone,
            customerAddress: customerAddress,
            customerEmail: customerEmail,
            items: items,
          ),
        ),
      );

      return result == true;
    } catch (e) {
      if (!mounted) return false;
      final errorMsg = "Lỗi thanh toán: $e";
      _showErrorDialog(errorMsg);
      if (kDebugMode) {
        print(' Payment error: $e');
      }
      return false;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Lỗi"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đóng"),
          ),
        ],
      ),
    );
  }

  // ---------------------- CHECKOUT FLOW ----------------------
  Future<void> _startCheckout(List<Map<String, dynamic>> items) async {
    if (kDebugMode) {
      print('🛒 Starting checkout process...');
    }
    
    final total = _total(items);

    // mở form nhập thông tin
    final info = await showDialog<_CheckoutInfo>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutDialog(
        total: total,
        shippingFee: shippingFee,
        onAddressChanged: (address) {
          if (address.isNotEmpty) {
            calculateShippingFee(items, address);
          }
        },
      ),
    );

    if (info == null) {
      if (kDebugMode) {
        print(' User cancelled checkout');
      }
      return; // user cancel
    }

    if (kDebugMode) {
      print(' Starting payment process...');
      print(' Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
      print(' Total: \$${total.toStringAsFixed(2)}');
    }

    // Generate temp order ID and customer email before payment
    final tempOrderId = "temp_${DateTime.now().millisecondsSinceEpoch}";
    final customerEmail = info.email.isNotEmpty ? info.email : 'guest@petshop.com';
    final grandTotal = total + shippingFee;
    
    // Save order to Firestore BEFORE payment
    await _saveOrderToFirestore(
      customerEmail: customerEmail,
      customerName: info.fullName,
      customerPhone: info.phone,
      customerAddress: info.address,
      items: items,
      totalAmount: grandTotal, // Use grand total including shipping
      sessionId: tempOrderId, // Use temp ID that payment success can search for
    );

    // Thanh toán qua Stripe Payment Screen
    final ok = await _payWithStripePaymentScreen(
      totalAmount: grandTotal, // Use grand total for payment
      customerName: info.fullName,
      customerPhone: info.phone,
      customerAddress: info.address,
      customerEmail: customerEmail,
      items: items,
    );
    
    if (!ok) {
      if (kDebugMode) {
        print(' Payment failed');
      }
      return;
    }

    if (!mounted) return;

    if (kDebugMode) {
      print(' Payment successful!');
    }

    // Update pet status to sold (like mobile version)
    for (var item in items) {
      try {
        await FirebaseFirestore.instance
            .collection('Pets')
            .doc(item['productId'])
            .update({
          "status": "sold",
          "isAvailable": false,
        });
      } catch (e) {
        if (kDebugMode) {
          print(' Failed to update pet status for ${item['productId']}: $e');
        }
      }
    }

    // Clear cart + báo thành công
    context.read<CartBlocWeb>().add(ClearCart('web'));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanh toán thành công! Đơn hàng đã được lưu.')),
    );

    // TODO: điều hướng OrderSuccess nếu bạn muốn
    // Navigator.push(context, MaterialPageRoute(builder: (_) => OrderSuccess(...)));
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
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<CartBlocWeb, CartStateWeb>(
          builder: (context, state) {
            if (state is CartLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is CartError) {
              return Center(child: Text("Lỗi: ${state.message}"));
            }
            if (state is! CartLoaded) {
              return const Center(child: Text("Unexpected state."));
            }

            final items = state.items;
            if (items.isEmpty) {
              return const Center(child: Text("Chưa có thú cưng nào trong giỏ."));
            }

            final total = _total(items);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;

                final list = Container(
                  padding: const EdgeInsets.all(8.0),
                  child: _CartList(
                    items: items,
                    onRemove: (id) => context.read<CartBlocWeb>().add(RemoveFromCart('web', id)),
                  ),
                );

                final summary = _SummaryPanel(
                  total: total,
                  shippingFee: shippingFee,
                  isCalculatingShipping: isCalculatingShipping,
                  onClear: () => context.read<CartBlocWeb>().add(ClearCart('web')),
                  onCheckout: () => _startCheckout(items),
                );

                if (!isWide) {
                  return Column(
                    children: [
                      Expanded(child: list),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [Expanded(child: summary)]),
                      ),
                    ],
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(padding: const EdgeInsets.all(12.0), child: list),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(width: 360, child: summary),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------- UI LIST ----------------------
class _CartList extends StatelessWidget {
  const _CartList({
    required this.items,
    required this.onRemove,
  });

  final List<Map<String, dynamic>> items;
  final void Function(String productId) onRemove;

  String _priceText(dynamic raw) {
    // Use shared VND formatting
    return CurrencyHelper.formatVND(raw);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final it = items[i];
        final id = (it['productId'] ?? it['id'] ?? '').toString();
        final name = (it['name'] ?? 'Unknown Pet').toString();
        final breed = (it['breed'] ?? '').toString();
        final imageUrl = (it['imageUrl'] ??
            'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT5Ubj9xSnLv0WDBYaGnpjt6CQZ8wFe9OltBQ&s')
            .toString();
  final priceStr = _priceText(it['price']);

        return _CartRowTile(
          id: id,
          name: name,
          breed: breed,
          priceText: priceStr,
          imageUrl: imageUrl,
          onRemove: () => onRemove(id),
        );
      },
    );
  }
}

class _CartRowTile extends StatelessWidget {
  const _CartRowTile({
    required this.id,
    required this.name,
    required this.breed,
    required this.priceText,
    required this.imageUrl,
    required this.onRemove,
  });

  final String id;
  final String name;
  final String breed;
  final String priceText;
  final String imageUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72, height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFEFEFEF)),
                loadingBuilder: (ctx, child, prog) => prog == null ? child : const _ShimmerBox(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: name,
                  waitDuration: const Duration(milliseconds: 300),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (breed.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      breed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              priceText,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          IconButton(
            tooltip: 'Xoá khỏi giỏ',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

// ---------------------- SUMMARY + CHECKOUT BUTTON ----------------------
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.total,
    required this.shippingFee,
    required this.isCalculatingShipping,
    required this.onClear,
    required this.onCheckout,
  });

  final double total;
  final double shippingFee;
  final bool isCalculatingShipping;
  final VoidCallback onClear;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTight = width < 360;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shipping fee display
            if (shippingFee > 0) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Tạm tính",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  Text(
                    CurrencyHelper.formatVND(total),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          "Phí vận chuyển",
                          style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (isCalculatingShipping)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      CurrencyHelper.formatVND(shippingFee),
                      style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
            ],
            
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Tổng cộng",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  CurrencyHelper.formatVND(total + shippingFee),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.clear_all),
                    label: const Text("Xoá tất cả"),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          vertical: isTight ? 10 : 12, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCheckout,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Thanh toán"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(
                          vertical: isTight ? 10 : 12, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- CHECKOUT DIALOG (FORM) ----------------------
class _CheckoutInfo {
  final String fullName;
  final String email;
  final String phone;
  final String address;
  const _CheckoutInfo({required this.fullName, required this.email, required this.phone, required this.address});
}

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({
    required this.total,
    this.shippingFee = 0.0,
    this.onAddressChanged,
  });
  final double total;
  final double shippingFee;
  final Function(String)? onAddressChanged;

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill email if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email != null) {
      _emailCtl.text = currentUser!.email!;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập thông tin' : null;
  
  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(v.trim())) return 'Email không hợp lệ';
    return null;
  }
  
  String? _phoneVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return 'Số điện thoại không hợp lệ';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      child: Container(
        width: isWide ? 600 : screenWidth * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông tin giao hàng',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.shippingFee > 0)
                        Text(
                          'Phí ship: ${CurrencyHelper.formatVND(widget.shippingFee)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        'Tổng: ${CurrencyHelper.formatVND(widget.total + widget.shippingFee)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Personal Information Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline, color: theme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Thông tin cá nhân',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.primaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Name and Email row for wide screens
                            if (isWide) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nameCtl,
                                      decoration: InputDecoration(
                                        labelText: 'Họ và tên *',
                                        prefixIcon: const Icon(Icons.person),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      validator: _req,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _emailCtl,
                                      decoration: InputDecoration(
                                        labelText: 'Email *',
                                        prefixIcon: const Icon(Icons.email),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      validator: _emailVal,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneCtl,
                                decoration: InputDecoration(
                                  labelText: 'Số điện thoại *',
                                  prefixIcon: const Icon(Icons.phone),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: '+84 xxx xxx xxx',
                                ),
                                validator: _phoneVal,
                                keyboardType: TextInputType.phone,
                              ),
                            ] else ...[
                              // Stack vertically for narrow screens
                              TextFormField(
                                controller: _nameCtl,
                                decoration: InputDecoration(
                                  labelText: 'Họ và tên *',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: _req,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailCtl,
                                decoration: InputDecoration(
                                  labelText: 'Email *',
                                  prefixIcon: const Icon(Icons.email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: _emailVal,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneCtl,
                                decoration: InputDecoration(
                                  labelText: 'Số điện thoại *',
                                  prefixIcon: const Icon(Icons.phone),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: '+84 xxx xxx xxx',
                                ),
                                validator: _phoneVal,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Delivery Address Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, color: theme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Địa chỉ giao hàng',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.primaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressCtl,
                              decoration: InputDecoration(
                                labelText: 'Địa chỉ chi tiết *',
                                prefixIcon: const Icon(Icons.home),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Số nhà, tên đường, phường/xã, quận/huyện, tỉnh/thành phố',
                              ),
                              validator: _req,
                              maxLines: 3,
                              onChanged: (value) {
                                // Calculate shipping fee when address changes
                                if (widget.onAddressChanged != null && value.trim().isNotEmpty) {
                                  widget.onAddressChanged!(value.trim());
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Hủy'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.pop(
                          context,
                          _CheckoutInfo(
                            fullName: _nameCtl.text.trim(),
                            email: _emailCtl.text.trim(),
                            phone: _phoneCtl.text.trim(),
                            address: _addressCtl.text.trim(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment),
                      label: Text('Thanh toán ${CurrencyHelper.formatVND(widget.total)}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF3F4F6),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
