import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/auth/auth_service.dart';
import '../../components/empty_state.dart';
import '../send_email.dart';
import 'components/order_card.dart';

class OrdersAdmin extends StatefulWidget {
  const OrdersAdmin({super.key});

  @override
  State<OrdersAdmin> createState() => _OrdersAdminState();
}

class _OrdersAdminState extends State<OrdersAdmin> {
  final CollectionReference ordersCollection =
      FirebaseFirestore.instance.collection('orders');

  final List<String> statuses = const [
    'All',
    'Pending',
    'Processing',
    'Completed',
    'Cancelled'
  ];
  String selectedStatus = 'All';

  String orderSort = 'desc'; // 'desc' = mới nhất trước, 'asc' = cũ nhất trước
  bool isLoading = false;

  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

  InputDecoration _searchInput(String hint) => InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: secondaryColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(8),
        ),
      );

  Color _statusColor(String s) {
    switch (s) {
      case 'Pending':
        return Colors.amber;
      case 'Processing':
        return Colors.blue;
      case 'Completed':
        return primaryColor;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> newData) async {
    setState(() => isLoading = true);
    await ordersCollection.doc(orderId).update(newData);
    setState(() => isLoading = false);
  }

  Future<void> deleteOrder(String orderId) async {
    setState(() => isLoading = true);
    await ordersCollection.doc(orderId).delete();
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title:
            const Text('Manage Orders', style: TextStyle(color: Colors.black)),
        actions: [
          // Filter status
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in statuses)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(s),
                          selected: selectedStatus == s,
                          selectedColor: primaryColor.withOpacity(.15),
                          labelStyle: TextStyle(
                            color: selectedStatus == s
                                ? primaryColor
                                : Colors.black87,
                          ),
                          onSelected: (_) => setState(() => selectedStatus = s),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Sort
                    DropdownButton<String>(
                      value: orderSort,
                      items: const [
                        DropdownMenuItem(
                            value: 'desc', child: Text('Mới nhất')),
                        DropdownMenuItem(value: 'asc', child: Text('Cũ nhất')),
                      ],
                      onChanged: (v) => setState(() => orderSort = v ?? 'desc'),
                      underline: Container(),
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchCtl,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: _searchInput(
                    'Tìm theo Order ID, email, địa chỉ hoặc trạng thái...'),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot>(
              stream: ordersCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyState(
                      label: 'No orders available',
                      icon: Icons.receipt_long_outlined);
                }

                var orders = snapshot.data!.docs.toList();

                // Filter by status
                if (selectedStatus != 'All') {
                  orders = orders
                      .where((d) =>
                          (d['statusOrder'] ?? '').toString() == selectedStatus)
                      .toList();
                }

                // Search locally (orderId/email/address/status)
                if (_query.isNotEmpty) {
                  orders = orders.where((d) {
                    final m = d.data() as Map<String, dynamic>;
                    final orderId =
                        (m['orderId'] ?? d.id).toString().toLowerCase();
                    final email = (m['email'] ?? '').toString().toLowerCase();
                    final addr =
                        (m['shippingAddress'] ?? '').toString().toLowerCase();
                    final st =
                        (m['statusOrder'] ?? '').toString().toLowerCase();
                    return orderId.contains(_query) ||
                        email.contains(_query) ||
                        addr.contains(_query) ||
                        st.contains(_query);
                  }).toList();
                }

                if (orders.isEmpty) {
                  return const EmptyState(
                      label: 'Không có đơn hàng phù hợp',
                      icon: Icons.search_off);
                }

                // Sort by timestamp/createdAt
                orders.sort((a, b) {
                  int getMs(QueryDocumentSnapshot d) {
                    final m = d.data() as Map<String, dynamic>;
                    final ts = m['timestamp'] ?? m['createdAt'];
                    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
                    return 0;
                  }

                  final aTime = getMs(a);
                  final bTime = getMs(b);
                  return orderSort == 'desc'
                      ? bTime.compareTo(aTime)
                      : aTime.compareTo(bTime);
                });

                return LayoutBuilder(
                  builder: (context, c) {
                    final crossAxisCount =
                        (c.maxWidth ~/ 420).clamp(1, 3); // ~420px mỗi card
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 160, // Chiều cao item
                      ),
                      itemCount: orders.length,
                      itemBuilder: (context, i) {
                        final d = orders[i];
                        final m = d.data() as Map<String, dynamic>;
                        final orderId = (m['orderId'] ?? d.id).toString();
                        final email = (m['email'] ?? '').toString();
                        final total = m['totalAmount']?.toString() ?? '0';
                        final status = (m['statusOrder'] ?? '').toString();
                        final address = (m['shippingAddress'] ?? '').toString();
                        final createdAt = m['timestamp'] ?? m['createdAt'];

                        return OrderCard(
                          orderId: orderId,
                          email: email,
                          total: total,
                          status: status,
                          address: address,
                          createdAt: createdAt,
                          statusColor: _statusColor(status),
                          onTap: () => _showOrderDetailsDialog(d),
                          onEdit: () => _showEditOrderDialog(d),
                          onDelete: () => _confirmDeleteOrder(d.id),
                          // Inline status changer
                          onChangeStatus: (newStatus) async {
                            if (newStatus == null) return;
                            final payload = {
                              'statusOrder': newStatus,
                              if (newStatus == 'Completed')
                                'statusPayment': 'Payment Completed',
                            };
                            await updateOrder(d.id, payload);

                            // Gửi email
                            if ((m['orderId'] ?? '').toString().isNotEmpty &&
                                email.isNotEmpty) {
                              final userInfo = await authService.value
                                  .getInfoUserFromEmail(email);
                              if (userInfo != null) {
                                sendOrderEmail(
                                  name: (userInfo['displayName'] ?? '')
                                      .toString(),
                                  email: email,
                                  orderId: orderId,
                                  orderStatus: newStatus,
                                );
                              }
                            }
                          },
                          allStatuses: statuses.sublist(1),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black38,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 8),
                  Text('Đang xử lý...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteOrder(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this order?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await deleteOrder(orderId);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditOrderDialog(QueryDocumentSnapshot order) {
    final m = order.data() as Map<String, dynamic>;
    final emailController = TextEditingController(text: m['email'] ?? '');
    final totalAmountController =
        TextEditingController(text: (m['totalAmount'] ?? '').toString());
    String selected = (m['statusOrder'] ?? 'Pending').toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: const Text("Edit Order"),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: totalAmountController,
                decoration: const InputDecoration(
                    labelText: 'Total Amount', border: OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selected,
                items: statuses
                    .sublist(1)
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => selected = v ?? selected,
                decoration: const InputDecoration(
                    labelText: 'Status', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () async {
              await updateOrder(order.id, {
                'email': emailController.text.trim(),
                'totalAmount':
                    double.tryParse(totalAmountController.text.trim()) ??
                        (m['totalAmount'] ?? 0),
                'statusOrder': selected,
                if (selected == 'Completed')
                  'statusPayment': 'Payment Completed',
              });
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderDetailsDialog(QueryDocumentSnapshot order) async {
    if (!mounted) return;

    final m = (order.data() as Map).cast<String, dynamic>();
    final String orderId = (m['orderId'] ?? order.id).toString();
    final String email = (m['email'] ?? '').toString();
    final String total = (m['totalAmount'] ?? '0').toString();
    final String statusPay = (m['statusPayment'] ?? '').toString();
    final String method = (m['paymentMethod'] ?? '').toString();
    final String status = (m['statusOrder'] ?? '').toString();
    final String address = (m['shippingAddress'] ?? '').toString();
    final String phone = (m['phone'] ?? '').toString();
    final dynamic ts = m['timestamp'] ?? m['createdAt'];
    final List<Map<String, dynamic>> items = (m['items'] is List)
        ? (m['items'] as List)
            .where((e) => e is Map)
            .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : const [];

    Color _statusColor(String s) {
      switch (s) {
        case 'Pending':
          return Colors.amber;
        case 'Processing':
          return Colors.blue;
        case 'Completed':
          return primaryColor;
        case 'Cancelled':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    String _fmtDate(dynamic t) {
      if (t is Timestamp) {
        final d = t.toDate();
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
      return '';
    }

    Widget _kv(String k, String v) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 160,
                child: Text('$k:',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Expanded(child: Text(v.isEmpty ? '-' : v)),
          ],
        );

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Order Details · $orderId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 10, color: _statusColor(status)),
                    const SizedBox(width: 6),
                    Text(status, style: TextStyle(color: _statusColor(status))),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 760,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Khối info 2 cột
                    Container(
                      decoration: BoxDecoration(
                        color: secondaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final isNarrow = c.maxWidth < 560;
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _kv('Email', email)),
                                  if (!isNarrow) const SizedBox(width: 24),
                                  if (!isNarrow)
                                    Expanded(
                                        child: _kv('Total Amount', '\$$total')),
                                ],
                              ),
                              if (isNarrow) const SizedBox(height: 8),
                              if (isNarrow)
                                Row(children: [
                                  Expanded(
                                      child: _kv('Total Amount', '\$$total'))
                                ]),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _kv('Status Pay', statusPay)),
                                  if (!isNarrow) const SizedBox(width: 24),
                                  if (!isNarrow)
                                    Expanded(
                                        child: _kv('Payment Method', method)),
                                ],
                              ),
                              if (isNarrow) const SizedBox(height: 8),
                              if (isNarrow)
                                Row(children: [
                                  Expanded(child: _kv('Payment Method', method))
                                ]),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _kv('Address', address)),
                                  if (!isNarrow) const SizedBox(width: 24),
                                  if (!isNarrow)
                                    Expanded(child: _kv('Phone', phone)),
                                ],
                              ),
                              if (isNarrow) const SizedBox(height: 8),
                              if (isNarrow)
                                Row(children: [
                                  Expanded(child: _kv('Phone', phone))
                                ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: _kv('Created At', _fmtDate(ts)))
                              ]),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Items',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 8),

                    // List items (khung chiều cao hữu hạn)
                    SizedBox(
                      height: 300,
                      child: items.isEmpty
                          ? const Center(child: Text('No items'))
                          : ListView.separated(
                              primary: false,
                              shrinkWrap: true,
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final it = items[i];
                                final name = (it['name'] ?? '').toString();
                                final price = (it['price'] ?? '').toString();
                                final imageUrl =
                                    (it['imageUrl'] ?? '').toString();
                                final qty = (it['quantity'] ?? 1).toString();

                                return ListTile(
                                  leading: AspectRatio(
                                    aspectRatio: 1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: secondaryColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: imageUrl.isNotEmpty
                                          ? FittedBox(
                                              fit:
                                                  BoxFit.contain, // nguyên hình
                                              child: Image.network(
                                                imageUrl,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                        Icons.broken_image),
                                              ),
                                            )
                                          : const Icon(Icons.pets_outlined),
                                    ),
                                  ),
                                  title: Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text('Qty: $qty • Price: \$$price'),
                                  trailing: Text(
                                    '\$${_safeMul(price, qty)}',
                                    style: const TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Nhân price * qty an toàn (chuỗi -> số), fallback '0'
  String _safeMul(String price, String qty) {
    final p = double.tryParse(price) ?? 0;
    final q = double.tryParse(qty) ?? 0;
    final total = p * q;
    // Hiển thị gọn (bỏ .0 nếu không cần)
    return total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2);
  }
}
