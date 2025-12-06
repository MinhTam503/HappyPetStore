import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';
import 'package:pet_shop/presentation/components/shipping_tracking_widget.dart';
import 'package:pet_shop/presentation/pages/mobile/address/address_list_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class YourOrderScreen extends StatefulWidget {
  final String? initialOrderId; // If provided, auto-open that order's details
  final bool isEmbedded; // If true, hide AppBar (used in tabs)
  
  const YourOrderScreen({
    super.key,
    this.initialOrderId,
    this.isEmbedded = false,
  });

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
  bool _detailsOpened = false; // ensure we only open once when requested

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
    try {
      // Update order status to Cancelled
      await ordersCollection.doc(orderId).update({
        'statusOrder': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Get order data to find pets
      final orderDoc = await ordersCollection.doc(orderId).get();
      if (orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final orderItems = (orderData['items'] as List?) ?? [];

        // Release all pets back to available
        for (var item in orderItems) {
          final petId = item['productId']?.toString() ?? item['id']?.toString();
          if (petId != null && petId.isNotEmpty) {
            try {
              final petDoc = await FirebaseFirestore.instance
                  .collection('Pets')
                  .doc(petId)
                  .get();

              if (petDoc.exists) {
                await FirebaseFirestore.instance
                    .collection('Pets')
                    .doc(petId)
                    .update({
                  'status': 'available',
                  'isAvailable': true,
                  'reservedAt': FieldValue.delete(),
                  'orderId': FieldValue.delete(),
                  'cancelledAt': FieldValue.serverTimestamp(),
                });
                print(
                    '✅ Pet $petId released back to available (order cancelled by user)');
              }
            } catch (e) {
              print('❌ Error updating pet $petId status: $e');
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy đơn hàng thành công')),
        );
      }
    } catch (e) {
      print('❌ Error cancelling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi hủy đơn hàng: $e')),
        );
      }
    }
  }

  // Removed free-text address dialog; we now use AddressListPage to select addresses.

  Future<void> _pickAddressAndUpdateOrder(String orderId) async {
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => AddressListPage(
            selectedAddress: null,
            onAddressSelected: (addr) {
              Navigator.pop(context, addr);
            },
          ),
        ),
      );

      if (result == null) return;

      // Normalize latitude/longitude keys
      final lat = result['latitude'] ?? result['lat'];
      final lng = result['longitude'] ?? result['lng'];

      final deliveryInfo = <String, dynamic>{
        'name': result['name']?.toString() ?? '',
        'phone': result['phone']?.toString() ?? '',
        'address': result['address']?.toString() ?? '',
        'isDefault': result['isDefault'] ?? false,
      };
      if (lat != null && lng != null) {
        deliveryInfo['latitude'] = lat;
        deliveryInfo['longitude'] = lng;
      }

      await ordersCollection.doc(orderId).update({
        'shippingAddress': deliveryInfo['address'] ?? '',
        'deliveryInfo': deliveryInfo,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật địa chỉ giao hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Lỗi cập nhật địa chỉ: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return FontAwesomeIcons.clock;
      case 'Processing':
        return FontAwesomeIcons.spinner;
      case 'Shipped':
        return FontAwesomeIcons.truck;
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
      case 'Shipped':
        return Colors.purple;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    }
  }

  IconData getShippingStatusIcon(String shippingStatus) {
    switch (shippingStatus) {
      case 'pickup_pending':
        return FontAwesomeIcons.clock;
      case 'in_transit':
        return FontAwesomeIcons.truck;
      case 'out_for_delivery':
        return FontAwesomeIcons.locationDot;
      case 'delivered':
        return FontAwesomeIcons.checkCircle;
      default:
        return FontAwesomeIcons.question;
    }
  }

  Color getShippingStatusColor(String shippingStatus) {
    switch (shippingStatus) {
      case 'pickup_pending':
        return Colors.orange;
      case 'in_transit':
        return Colors.blue;
      case 'out_for_delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    }
  }

  String getShippingStatusText(String shippingStatus) {
    switch (shippingStatus) {
      case 'pickup_pending':
        return 'Chờ lấy hàng';
      case 'in_transit':
        return 'Đang vận chuyển';
      case 'out_for_delivery':
        return 'Đang giao hàng';
      case 'delivered':
        return 'Đã giao hàng';
      default:
        return 'Không xác định';
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
    final l10n = AppLocalizations.of(context);
    
    final filterBar = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: _FilterBar(
        statusFilter: statusFilter,
        orderSort: orderSort,
        onStatusChanged: (v) => setState(() => statusFilter = v),
        onSortChanged: (v) => setState(() => orderSort = v),
      ),
    );
    
    final bodyContent = RefreshIndicator(
      onRefresh: _refresh,
      child: StreamBuilder<QuerySnapshot>(
        stream: userData == null
            ? null
            : ordersCollection
                .where('email', isEqualTo: userData?['email'])
                .snapshots(),
        builder: (context, snapshot) {
          if (userData == null ||
              snapshot.connectionState == ConnectionState.waiting) {
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

            // Auto-open a specific order's details if requested
            if (widget.initialOrderId != null && !_detailsOpened) {
              QueryDocumentSnapshot? matchDoc;
              for (final doc in orders) {
                final docId = doc.id;
                final orderIdField =
                    (doc.data() as Map<String, dynamic>?)?['orderId']
                        ?.toString();
                if (docId == widget.initialOrderId ||
                    orderIdField == widget.initialOrderId) {
                  matchDoc = doc;
                  break;
                }
              }
              if (matchDoc != null) {
                _detailsOpened = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showOrderDetailsSheet(matchDoc!);
                  }
                });
              }
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                final status = order['statusOrder'] ?? '';
                final totalRaw = order['totalAmount'] ?? 0;
                final subtotal = order['subtotal'] ?? totalRaw;
                final shippingFee = order['shippingFee'] ?? 0;
                final statusPay = order['statusPayment'] ?? '';
                final id = order['orderId'] ?? order.id;

                // Safely get tracking number and shipping info
                final orderData = order.data() as Map<String, dynamic>?;
                final trackingNumber =
                    orderData?.containsKey('trackingNumber') == true
                        ? orderData!['trackingNumber']
                        : null;
                final shippingInfo =
                    orderData?.containsKey('shippingInfo') == true
                        ? orderData!['shippingInfo']
                        : null;

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
                          _StatusIcon(
                              status: status,
                              color: getStatusColor(status),
                              icon: getStatusIcon(status)),
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
                                        "Đơn hàng #$id",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatTime(order['timestamp']),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.54),
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
                                    // Show breakdown if subtotal exists (new orders), otherwise just total (old orders)
                                    if (subtotal != totalRaw &&
                                        shippingFee > 0) ...[
                                      _ChipBadge(
                                        label:
                                            "Hàng: ${CurrencyHelper.formatVND(subtotal)}",
                                        icon: Icons.shopping_cart_outlined,
                                        bg: Colors.blue.shade50,
                                        fg: Colors.blue.shade700,
                                      ),
                                      _ChipBadge(
                                        label:
                                            "Ship: ${CurrencyHelper.formatVND(shippingFee)}",
                                        icon: Icons.local_shipping_outlined,
                                        bg: Colors.orange.shade50,
                                        fg: Colors.orange.shade700,
                                      ),
                                    ],
                                    _ChipBadge(
                                      label: (subtotal != totalRaw &&
                                              shippingFee > 0)
                                          ? "Tổng: ${CurrencyHelper.formatVND(totalRaw)}"
                                          : "${CurrencyHelper.formatVND(totalRaw)}",
                                      icon: Icons.payments_outlined,
                                      bg: Colors.green.shade50,
                                      fg: Colors.green.shade700,
                                    ),
                                    _ChipBadge(
                                      label: "Thanh toán: $statusPay",
                                      icon: Icons.verified_outlined,
                                      bg: Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant,
                                      fg: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.87),
                                    ),
                                    _ChipBadge(
                                      label: status,
                                      icon: Icons.local_shipping_outlined,
                                      bg: getStatusColor(status)
                                          .withOpacity(.12),
                                      fg: getStatusColor(status),
                                    ),
                                    // Hiển thị trạng thái vận chuyển nếu có tracking number
                                    if (trackingNumber != null &&
                                        trackingNumber.toString().isNotEmpty &&
                                        shippingInfo != null)
                                      _ChipBadge(
                                        label: getShippingStatusText(
                                            shippingInfo['status'] ??
                                                'pickup_pending'),
                                        icon: getShippingStatusIcon(
                                            shippingInfo['status'] ??
                                                'pickup_pending'),
                                        bg: getShippingStatusColor(
                                                shippingInfo['status'] ??
                                                    'pickup_pending')
                                            .withOpacity(.12),
                                        fg: getShippingStatusColor(
                                            shippingInfo['status'] ??
                                                'pickup_pending'),
                                      ),
                                  ],
                                ),
                                // Hiển thị tracking number nếu có
                                if (trackingNumber != null &&
                                    trackingNumber.toString().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.local_shipping,
                                          size: 16,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6)),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Mã vận đơn: $trackingNumber",
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                // Nút hủy (nếu Pending)
                                if (status == 'Pending')
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => cancelOrder(order.id),
                                      icon: const Icon(Icons.cancel_outlined,
                                          color: Colors.red),
                                      label: const Text('Hủy đơn',
                                          style: TextStyle(color: Colors.red)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
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
      );
    
    
    // If embedded, return body with filter bar
    if (widget.isEmbedded) {
      return Column(
        children: [
          filterBar,
          Expanded(child: bodyContent),
        ],
      );
    }
    
    // Otherwise, return full Scaffold
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        elevation: 0,
        title: Text(
          l10n?.yourOrder ?? "Đơn hàng của bạn",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: .2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: filterBar,
        ),
      ),
      body: bodyContent,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final status = order['statusOrder'] ?? '';
        final totalRaw = order['totalAmount'] ?? 0;
        final subtotal = order['subtotal'] ?? totalRaw;
        final shippingFee = order['shippingFee'] ?? 0;
        final statusPay = order['statusPayment'] ?? '';
        final email = order['email'] ?? '';

        // Safely get tracking number and shipping info
        final orderData = order.data() as Map<String, dynamic>?;
        final trackingNumber = orderData?.containsKey('trackingNumber') == true
            ? orderData!['trackingNumber']
            : null;

        // Debug logging for order details
        print(
            "🐛 Order Details: totalAmount raw = $totalRaw (${totalRaw.runtimeType})");
        print(
            "🐛 Order Details: formatted = '${CurrencyHelper.formatVND(totalRaw)}'");

        // Lấy địa chỉ và số điện thoại từ cấu trúc mới (đồng bộ với cart_screen)
        String address = '';
        String customerPhone = '';
        String customerName = '';

        try {
          if (order.data() is Map<String, dynamic>) {
            final orderData = order.data() as Map<String, dynamic>;

            // 1. Ưu tiên lấy từ customerInfo (format mới)
            if (orderData.containsKey('customerInfo') &&
                orderData['customerInfo'] is Map<String, dynamic>) {
              final customerInfo =
                  orderData['customerInfo'] as Map<String, dynamic>;
              customerName = customerInfo['name']?.toString() ?? '';
              customerPhone = customerInfo['phone']?.toString() ?? '';
            }
            // 2. Fallback: Lấy từ top-level fields
            else {
              customerName = orderData['displayName']?.toString() ?? '';
              customerPhone = orderData['phone']?.toString() ?? '';
            }

            // 3. Lấy địa chỉ từ shippingAddress (single source of truth)
            if (orderData.containsKey('shippingAddress') &&
                orderData['shippingAddress'] != null &&
                orderData['shippingAddress'].toString().isNotEmpty) {
              final shippingAddr = orderData['shippingAddress'].toString();

              // Format: Name • Phone\nAddress
              if (customerName.isNotEmpty && customerPhone.isNotEmpty) {
                address = '$customerName • $customerPhone\n$shippingAddr';
              } else if (customerPhone.isNotEmpty) {
                address = '$customerPhone\n$shippingAddr';
              } else {
                address = shippingAddr;
              }
            }
            // 4. Fallback: Lấy từ deliveryInfo
            else if (orderData.containsKey('deliveryInfo') &&
                orderData['deliveryInfo'] is Map<String, dynamic>) {
              final deliveryInfo =
                  orderData['deliveryInfo'] as Map<String, dynamic>;
              final name = deliveryInfo['name']?.toString() ?? customerName;
              final phone = deliveryInfo['phone']?.toString() ?? customerPhone;
              final addr = deliveryInfo['address']?.toString() ?? '';

              if (name.isNotEmpty && phone.isNotEmpty) {
                address = '$name • $phone\n$addr';
              } else if (phone.isNotEmpty) {
                address = '$phone\n$addr';
              } else {
                address = addr;
              }
            }
            // 5. Final fallback: old address field
            else if (orderData.containsKey('address')) {
              final addr = orderData['address']?.toString() ?? '';
              if (customerName.isNotEmpty && customerPhone.isNotEmpty) {
                address = '$customerName • $customerPhone\n$addr';
              } else if (customerPhone.isNotEmpty) {
                address = '$customerPhone\n$addr';
              } else {
                address = addr;
              }
            }
          }
        } catch (e) {
          print('Error getting address: $e');
          address = 'Không có thông tin địa chỉ';
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatusIcon(
                          status: status,
                          color: getStatusColor(status),
                          icon: getStatusIcon(status)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Chi tiết đơn hàng",
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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
                        bg: Theme.of(context).colorScheme.surfaceVariant,
                        fg: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.87),
                      ),
                      _ChipBadge(
                        label: "Thanh toán: $statusPay",
                        icon: Icons.verified_outlined,
                        bg: Theme.of(context).colorScheme.surfaceVariant,
                        fg: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.87),
                      ),
                      // Show breakdown if subtotal exists and different from total (new orders), otherwise just total
                      if (subtotal != totalRaw && shippingFee > 0) ...[
                        _ChipBadge(
                          label: "Hàng: ${CurrencyHelper.formatVND(subtotal)}",
                          icon: Icons.shopping_cart_outlined,
                          bg: Colors.blue.shade50,
                          fg: Colors.blue.shade700,
                        ),
                        _ChipBadge(
                          label:
                              "Ship: ${CurrencyHelper.formatVND(shippingFee)}",
                          icon: Icons.local_shipping_outlined,
                          bg: Colors.orange.shade50,
                          fg: Colors.orange.shade700,
                        ),
                      ],
                      _ChipBadge(
                        label: (subtotal != totalRaw && shippingFee > 0)
                            ? "Tổng: ${CurrencyHelper.formatVND(totalRaw)}"
                            : "${CurrencyHelper.formatVND(totalRaw)}",
                        icon: Icons.payments_outlined,
                        bg: Colors.green.shade50,
                        fg: Colors.green.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (address.trim().isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.87)),
                          ),
                        ),
                      ],
                    ),
                  if (status == 'Pending') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _pickAddressAndUpdateOrder(order.id),
                            icon: const Icon(Icons.edit_location_alt),
                            label: const Text('Đổi địa chỉ giao hàng'),
                          ),
                          TextButton.icon(
                            onPressed: () => cancelOrder(order.id),
                            icon: const Icon(Icons.cancel_outlined,
                                color: Colors.red),
                            label: const Text('Hủy đơn',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),

                  // Hiển thị trạng thái vận chuyển nếu có tracking number
                  if (trackingNumber != null &&
                      trackingNumber.toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Thông tin vận chuyển",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping,
                                  color: Colors.blue.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Mã vận đơn: $trackingNumber",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Add ShippingTrackingWidget for real-time tracking
                    if (trackingNumber != null &&
                        trackingNumber.toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: ShippingTrackingWidget(
                          trackingNumber: trackingNumber,
                          isAdminView: false, // Customer view
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                  ],

                  const SizedBox(height: 10),
                  Text(
                    "Items",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  // Pet items list (replaced ListView with Column for better scrolling)
                  Column(
                    children: petsData.map((petData) {
                      final name = petData['name'] ?? '';
                      final price = petData['price'] ?? petData['weight'] ?? '';
                      final qty = petData['quantity'] ?? 1;
                      final image = (petData['imageUrl'] ?? '') as String;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: image.isNotEmpty
                                  ? Image.network(image,
                                      width: 56, height: 56, fit: BoxFit.cover)
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant,
                                      child: Icon(Icons.pets,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withOpacity(0.38)),
                                    ),
                            ),
                            title: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => DetailPet(pet: petData)),
                                );
                              },
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            subtitle: Text(
                                "${CurrencyHelper.formatVND(price)}  •  x$qty"),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
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
    final filterItems = {
      'All': 'Tất cả',
      'Pending': 'Chờ xử lý',
      'Processing': 'Đang xử lý',
      'Shipped': 'Đang giao hàng',
      'Completed': 'Hoàn thành',
      'Cancelled': 'Đã hủy',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(.05),
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
              items: filterItems.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              decoration: InputDecoration(
                labelText: 'Trạng thái',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            Icon(Icons.inbox_outlined,
                size: 72, color: theme.colorScheme.onSurface.withOpacity(0.26)),
            const SizedBox(height: 12),
            Text(
              "Không tìm thấy đơn hàng",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.54),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Đơn hàng của bạn sẽ hiển thị tại đây khi bạn mua sắm.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
