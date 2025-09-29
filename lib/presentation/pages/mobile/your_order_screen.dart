import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/detail_pet.dart';



class YourOrderScreen extends StatefulWidget {
  const YourOrderScreen({super.key});

  @override
  State<YourOrderScreen> createState() => _YourOrderScreenState();
}

class _YourOrderScreenState extends State<YourOrderScreen> {
  Map<String, dynamic>? userData;
  final CollectionReference ordersCollection =
  FirebaseFirestore.instance.collection('orders');
  final CollectionReference petsCollection =
  FirebaseFirestore.instance.collection('Pets'); // Lấy dữ liệu thú cưng

  String orderSort = 'desc'; // 'desc' = mới nhất trước, 'asc' = cũ nhất trước
  String statusFilter = 'All';

  @override
  void initState() {
    fetchUserData();
    super.initState();
  }

  Future<void> fetchUserData() async {
    final user = await authService.value.getUserInfo();
    if (mounted) {
      setState(() {
        userData = user;
      });
    }
  }

  Future<void> _refresh() async {
    // Stream orders tự cập nhật; refresh chỉ để refetch userData và tạo cảm giác phản hồi
    await fetchUserData();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  void cancelOrder(String orderId) async {
    await ordersCollection.doc(orderId).update({'statusOrder': 'Cancelled'});
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return FontAwesomeIcons.clock;
      case 'Processing':
        return FontAwesomeIcons.spinner;
      case 'Completed':
        return FontAwesomeIcons.checkCircle;
      case 'Cancelled':
        return FontAwesomeIcons.xmarkCircle;
      default:
        return FontAwesomeIcons.circleQuestion;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      // format ngắn gọn, không thêm package
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y • $hh:$mm';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        centerTitle: true,
        elevation: 0,
        title: Text(
          "Your Orders",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: .2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _FilterBar(
              statusFilter: statusFilter,
              orderSort: orderSort,
              onStatusChanged: (v) => setState(() => statusFilter = v),
              onSortChanged: (v) => setState(() => orderSort = v),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: userData == null
              ? null
              : ordersCollection
              .where('email', isEqualTo: userData?['email'])
              .snapshots(),
          builder: (context, snapshot) {
            if (userData == null || snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const _EmptyOrders();
            }

            // Lọc theo trạng thái
            var orders = snapshot.data!.docs.toList();
            if (statusFilter != 'All') {
              orders = orders
                  .where((doc) => (doc['statusOrder'] ?? '') == statusFilter)
                  .toList();
            }

            // Sắp xếp theo thời gian
            orders.sort((a, b) {
              final aTime = a['timestamp'] is Timestamp
                  ? (a['timestamp'] as Timestamp).millisecondsSinceEpoch
                  : 0;
              final bTime = b['timestamp'] is Timestamp
                  ? (b['timestamp'] as Timestamp).millisecondsSinceEpoch
                  : 0;
              return orderSort == 'desc'
                  ? bTime.compareTo(aTime)
                  : aTime.compareTo(bTime);
            });

            if (orders.isEmpty) {
              return const _EmptyOrders();
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                final status = order['statusOrder'] ?? '';
                final total = (order['totalAmount'] ?? 0).toString();
                final statusPay = order['statusPayment'] ?? '';
                final id = order['orderId'] ?? order.id;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showOrderDetailsSheet(order),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusIcon(status: status, color: getStatusColor(status), icon: getStatusIcon(status)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ID + thời gian
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Order #$id",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatTime(order['timestamp']),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Tổng tiền + trạng thái
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _ChipBadge(
                                      label: "\$ $total",
                                      icon: Icons.payments_outlined,
                                      bg: Colors.grey.shade100,
                                      fg: Colors.black87,
                                    ),
                                    _ChipBadge(
                                      label: "Pay: $statusPay",
                                      icon: Icons.verified_outlined,
                                      bg: Colors.grey.shade100,
                                      fg: Colors.black87,
                                    ),
                                    _ChipBadge(
                                      label: status,
                                      icon: Icons.local_shipping_outlined,
                                      bg: getStatusColor(status).withOpacity(.12),
                                      fg: getStatusColor(status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Nút hủy (nếu Pending)
                                if (status == 'Pending')
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => cancelOrder(order.id),
                                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                      label: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
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
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showOrderDetailsSheet(QueryDocumentSnapshot order) async {
    // Lấy dữ liệu thú cưng theo productId trong items
    final List<dynamic> items = (order['items'] ?? []) as List<dynamic>;
    final List<Map<String, dynamic>> petsData = [];

    for (var item in items) {
      final productId = item['productId'];
      final quantity = item['quantity'];
      final petSnapshot = await petsCollection.doc(productId).get();
      if (petSnapshot.exists) {
        final petData = petSnapshot.data() as Map<String, dynamic>;
        petsData.add({
          ...petData,
          'quantity': quantity,
        });
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final status = order['statusOrder'] ?? '';
        final total = (order['totalAmount'] ?? 0).toString();
        final statusPay = order['statusPayment'] ?? '';
        final email = order['email'] ?? '';
        final address = order['shippingAddress'] ?? '';

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatusIcon(status: status, color: getStatusColor(status), icon: getStatusIcon(status)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Order Details",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _ChipBadge(
                        label: status,
                        icon: Icons.local_shipping_outlined,
                        bg: getStatusColor(status).withOpacity(.12),
                        fg: getStatusColor(status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipBadge(
                        label: "Email: $email",
                        icon: Icons.alternate_email,
                        bg: Colors.grey.shade100,
                        fg: Colors.black87,
                      ),
                      _ChipBadge(
                        label: "Pay: $statusPay",
                        icon: Icons.verified_outlined,
                        bg: Colors.grey.shade100,
                        fg: Colors.black87,
                      ),
                      _ChipBadge(
                        label: "Total: \$ $total",
                        icon: Icons.payments_outlined,
                        bg: Colors.grey.shade100,
                        fg: Colors.black87,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if ((address as String).trim().isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, color: primaryColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text(
                    "Items",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      itemCount: petsData.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final petData = petsData[index];
                        final name = petData['name'] ?? '';
                        final price = petData['price'] ?? petData['weight'] ?? '';
                        final qty = petData['quantity'] ?? 1;
                        final image = (petData['imageUrl'] ?? '') as String;

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: image.isNotEmpty
                                  ? Image.network(image, width: 56, height: 56, fit: BoxFit.cover)
                                  : Container(
                                width: 56, height: 56,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.pets, color: Colors.black38),
                              ),
                            ),
                            title: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DetailPet(pet: petData)),
                                );
                              },
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            subtitle: Text("${CurrencyHelper.formatVND(price)}  •  x$qty"),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// =========================
// Sub-widgets & UI helpers
// =========================

class _FilterBar extends StatelessWidget {
  final String statusFilter;
  final String orderSort;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSortChanged;

  const _FilterBar({
    required this.statusFilter,
    required this.orderSort,
    required this.onStatusChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filterItems = ['All', 'Pending', 'Processing', 'Completed', 'Cancelled'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Filter trạng thái
          Expanded(
            child: DropdownButtonFormField<String>(
              value: statusFilter,
              onChanged: (v) => v != null ? onStatusChanged(v) : null,
              items: filterItems
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              decoration: InputDecoration(
                labelText: 'Trạng thái',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Sort thời gian
          Expanded(
            child: DropdownButtonFormField<String>(
              value: orderSort,
              onChanged: (v) => v != null ? onSortChanged(v) : null,
              items: const [
                DropdownMenuItem(value: 'desc', child: Text('Mới nhất')),
                DropdownMenuItem(value: 'asc', child: Text('Cũ nhất')),
              ],
              decoration: InputDecoration(
                labelText: 'Sắp xếp',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  final Color color;
  final IconData icon;
  const _StatusIcon({
    required this.status,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: FaIcon(icon, size: 20, color: color),
      ),
    );
  }
}

class _ChipBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  const _ChipBadge({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withOpacity(.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 72, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              "No orders found",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Đơn hàng của bạn sẽ hiển thị tại đây khi bạn mua sắm.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
