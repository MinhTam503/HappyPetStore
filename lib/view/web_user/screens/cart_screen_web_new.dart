import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart'hide Card;
import 'package:http/http.dart' as http;

import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/bloc/cart_bloc_web/cart_bloc_web.dart';
import 'package:pet_shop/services/payment_service.dart';

import 'package:pet_shop/bloc/cart_bloc_web/cart_state_web.dart';
import 'package:pet_shop/bloc/cart_bloc_web/cart_event_web.dart';

class CartScreenWeb extends StatefulWidget {
  const CartScreenWeb({super.key});

  @override
  State<CartScreenWeb> createState() => _CartScreenWebState();
}

class _CartScreenWebState extends State<CartScreenWeb> {
  Map<String, dynamic>? _intentPaymentData;

  double _priceOf(Map<String, dynamic> item) {
    final raw = item['price'] ?? item['weight'] ?? 0;
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  double _total(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, it) => sum + _priceOf(it));
  }

  // ---------------------- PAYMENT WITH BACKEND API ----------------------
  Future<bool> _payWithBackendAPI({
    required double totalAmount,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String customerEmail,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      // Step 1: Check backend health
      final isHealthy = await PaymentService.isBackendHealthy();
      if (!isHealthy) {
        if (!mounted) return false;
        _showErrorDialog("Không thể kết nối đến server thanh toán");
        return false;
      }

      // Step 2: Create payment intent via backend
      final paymentIntentData = await PaymentService.createPaymentIntent(
        amount: totalAmount,
        currency: "usd",
      );
      
      if (paymentIntentData == null) {
        if (!mounted) return false;
        _showErrorDialog("Không thể tạo intent thanh toán");
        return false;
      }

      _intentPaymentData = paymentIntentData;

      // Step 3: Initialize Stripe payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData["client_secret"],
          merchantDisplayName: "Pet Shop",
          allowsDelayedPaymentMethods: true,
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(),
        ),
      );

      // Step 4: Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Step 5: Confirm payment with backend
      final orderData = {
        'customer_info': {
          'name': customerName,
          'phone': customerPhone,
          'address': customerAddress,
          'email': customerEmail,
        },
        'items': items.map((item) => {
          'productId': (item['productId'] ?? item['id'])?.toString(),
          'name': item['name'],
          'breed': item['breed'],
          'price': item['price'] ?? item['weight'],
          'imageUrl': item['imageUrl'],
          'quantity': item['quantity'] ?? 1,
        }).toList(),
        'total_amount': totalAmount,
        'metadata': {
          'source': 'flutter_web',
          'timestamp': DateTime.now().toIso8601String(),
        }
      };

      final confirmResult = await PaymentService.confirmPayment(
        paymentIntentId: paymentIntentData["payment_intent_id"],
        orderData: orderData,
      );

      if (confirmResult == null || confirmResult['success'] != true) {
        if (!mounted) return false;
        _showErrorDialog("Không thể xác nhận thanh toán");
        return false;
      }

      // Step 6: Save to Firestore as backup
      await _saveOrderToFirestore(
        fullName: customerName,
        phone: customerPhone,
        address: customerAddress,
        items: items,
        totalAmount: totalAmount,
        isPaid: true,
        paymentMethod: 'stripe_backend',
        backendOrderId: confirmResult['order_id'],
      );

      return true;
    } on StripeException catch (e) {
      if (!mounted) return false;
      _showErrorDialog("Thanh toán thất bại: ${e.error.message ?? "Đã có lỗi xảy ra"}");
      return false;
    } catch (e) {
      if (!mounted) return false;
      _showErrorDialog("Lỗi thanh toán: $e");
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

  // ---------------------- FIRESTORE SAVE ----------------------
  Future<void> _saveOrderToFirestore({
    required String fullName,
    required String phone,
    required String address,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required bool isPaid,
    String paymentMethod = 'stripe_backend',
    String? backendOrderId,
  }) async {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final orderRef = FirebaseFirestore.instance.collection('orderWeb').doc();

    // (Tuỳ bạn) cập nhật tình trạng pet sau khi thanh toán:
    // for (final it in items) {
    //   final petId = (it['productId'] ?? it['id'])?.toString();
    //   if (petId != null && petId.isNotEmpty) {
    //     await FirebaseFirestore.instance.collection('Pets').doc(petId).update({
    //       "status": "sold",
    //       "isAvailable": false,
    //     }).catchError((_) {});
    //   }
    // }

    final data = {
      "orderId": orderRef.id,
      "email": email,
      "fullName": fullName,
      "phone": phone,
      "address": address,
      "paymentMethod": paymentMethod,
      "statusPayment": isPaid ? "Payment Completed" : "Unpaid",
      "statusOrder": "Pending",
      "totalAmount": totalAmount,
      "timestamp": FieldValue.serverTimestamp(),
      "items": items.map((e) {
        return {
          "productId": (e['productId'] ?? e['id'])?.toString(),
          "name": e['name'],
          "breed": e['breed'],
          "price": e['price'] ?? e['weight'],
          "imageUrl": e['imageUrl'],
          "quantity": e['quantity'] ?? 1,
        };
      }).toList(),
      // Store backend order ID and payment intent ID
      if (backendOrderId != null) "backendOrderId": backendOrderId,
      if (_intentPaymentData?['payment_intent_id'] != null) 
        "paymentIntentId": _intentPaymentData!['payment_intent_id'],
    };

    await orderRef.set(data);
  }

  // ---------------------- CHECKOUT FLOW ----------------------
  Future<void> _startCheckout(List<Map<String, dynamic>> items) async {
    final total = _total(items);

    // mở form nhập thông tin
    final info = await showDialog<_CheckoutInfo>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutDialog(total: total),
    );

    if (info == null) return; // user cancel

    // Thanh toán qua Backend API
    final customerEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final ok = await _payWithBackendAPI(
      totalAmount: total,
      customerName: info.fullName,
      customerPhone: info.phone,
      customerAddress: info.address,
      customerEmail: customerEmail,
      items: items,
    );
    
    if (!ok) return;

    if (!mounted) return;

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
    if (raw == null) return '--';
    final n = double.tryParse(raw.toString());
    if (n == null) return raw.toString();
    return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
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
        final priceStr = _priceText(it['price'] ?? it['weight']);

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
              "\$$priceText",
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
    required this.onClear,
    required this.onCheckout,
  });

  final double total;
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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Tổng cộng",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  "\$${total.toStringAsFixed(2)}",
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
  final String phone;
  final String address;
  const _CheckoutInfo({required this.fullName, required this.phone, required this.address});
}

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({required this.total});
  final double total;

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập thông tin' : null;
  String? _phoneVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return 'Số điện thoại không hợp lệ';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return AlertDialog(
      title: const Text('Thông tin người nhận'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: isWide
                ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtl,
                        decoration: const InputDecoration(labelText: 'Họ và tên'),
                        validator: _req,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtl,
                        decoration: const InputDecoration(labelText: 'Số điện thoại'),
                        validator: _phoneVal,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _addressCtl,
                    decoration: const InputDecoration(labelText: 'Địa chỉ giao hàng'),
                    validator: _req,
                    maxLines: 5,
                  ),
                ),
              ],
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtl,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtl,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  validator: _phoneVal,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtl,
                  decoration: const InputDecoration(labelText: 'Địa chỉ giao hàng'),
                  validator: _req,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _CheckoutInfo(
                fullName: _nameCtl.text.trim(),
                phone: _phoneCtl.text.trim(),
                address: _addressCtl.text.trim(),
              ),
            );
          },
          icon: const Icon(Icons.payment),
          label: Text('Thanh toán \$${widget.total.toStringAsFixed(2)}'),
        ),
      ],
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
