import 'package:flutter/material.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/helpers/order_notification_helper.dart';
import 'package:pet_shop/services/shipping_service.dart';
import 'package:pet_shop/presentation/components/shipping_tracking_widget.dart';
import '../../components/empty_state.dart';
import '../send_email.dart';
import 'components/order_card.dart';

class OrdersAdmin extends StatefulWidget {
  const OrdersAdmin({super.key});

  @override
  State<OrdersAdmin> createState() => _OrdersAdminState();
}

class _OrdersAdminState extends State<OrdersAdmin> {
  // Raw status values for database operations
  static const List<String> rawStatusValues = [
    'Pending',
    'Processing', 
    'Completed',
    'Cancelled'
  ];
  
  // Platform filter options
  List<String> get platforms => [
    AppLocalizations.of(context)!.all,
    AppLocalizations.of(context)!.mobileApp,
    AppLocalizations.of(context)!.webApp
  ];
  int selectedPlatformIndex = 0; // 0=All, 1=Mobile, 2=Web

  List<String> get statuses => [
    AppLocalizations.of(context)!.all,
    AppLocalizations.of(context)!.pending,
    AppLocalizations.of(context)!.processing,
    AppLocalizations.of(context)!.completed,
    AppLocalizations.of(context)!.cancelled
  ];
  int selectedStatusIndex = 0; // 0=All, 1=Pending, 2=Processing, 3=Completed, 4=Cancelled

  String orderSort = 'desc'; // 'desc' = mới nhất trước, 'asc' = cũ nhất trước
  bool isLoading = false;

  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

  // Get the appropriate collection based on selected platform
  Stream<List<Map<String, dynamic>>> _getOrdersStream() {
    if (selectedPlatformIndex == 1) { // Mobile App
      return FirebaseFirestore.instance
          .collection('orders')
          .snapshots()
          .map(_processSnapshot);
    } else if (selectedPlatformIndex == 2) { // Web App
      return FirebaseFirestore.instance
          .collection('ordersWeb')
          .snapshots()
          .map(_processSnapshot);
    } else { // All
      // All - combine both collections
      return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
        final ordersSnapshot = await FirebaseFirestore.instance.collection('orders').get();
        final ordersWebSnapshot = await FirebaseFirestore.instance.collection('ordersWeb').get();
        
        List<Map<String, dynamic>> allOrders = [];
        allOrders.addAll(_processSnapshot(ordersSnapshot));
        allOrders.addAll(_processSnapshot(ordersWebSnapshot));
        return allOrders;
      });
    }
  }

  List<Map<String, dynamic>> _processSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      // Extract collection name from document reference path
      data['collection'] = doc.reference.parent.id;
      return data;
    }).toList();
  }

  Future<void> _updateOrder(String orderId, String collection, Map<String, dynamic> newData) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(orderId)
        .update(newData);
  }

  Future<void> _deleteOrder(String orderId, String collection) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(orderId)
        .delete();
  }

  InputDecoration _searchInput(String hint) => InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
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

  Future<void> updateOrder(String orderId, String collection, Map<String, dynamic> newData) async {
    setState(() => isLoading = true);
    await _updateOrder(orderId, collection, newData);
    setState(() => isLoading = false);
  }

  Future<void> deleteOrder(String orderId, String collection) async {
    setState(() => isLoading = true);
    await _deleteOrder(orderId, collection);
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          AppLocalizations.of(context)!.manageOrders, 
          style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor)
        ),
        actions: [
          // Flexible container for filters
          Flexible(
            child: Container(
              // constraints: const BoxConstraints(maxWidth: 1200),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Platform filter - smaller chips
                    for (int i = 0; i < platforms.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text(platforms[i]),
                          selected: selectedPlatformIndex == i,
                          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(.15),
                          backgroundColor: Theme.of(context).chipTheme.backgroundColor,
                          labelStyle: TextStyle(
                            color: selectedPlatformIndex == i
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 12,
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onSelected: (_) => setState(() => selectedPlatformIndex = i),
                        ),
                      ),
                    const SizedBox(width: 4),
                    // Status filter - smaller chips
                    for (int i = 0; i < statuses.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text(statuses[i]),
                          selected: selectedStatusIndex == i,
                          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(.15),
                          backgroundColor: Theme.of(context).chipTheme.backgroundColor,
                          labelStyle: TextStyle(
                            color: selectedStatusIndex == i
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 12,
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onSelected: (_) => setState(() => selectedStatusIndex = i),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Sort dropdown - compact
                    SizedBox(
                      height: 32,
                      child: DropdownButton<String>(
                        value: orderSort,
                        items: [
                          DropdownMenuItem(
                              value: 'desc', child: Text(AppLocalizations.of(context)!.newest)),
                          DropdownMenuItem(value: 'asc', child: Text(AppLocalizations.of(context)!.oldest)),
                        ],
                        onChanged: (v) => setState(() => orderSort = v ?? 'desc'),
                        underline: Container(),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color, 
                          fontSize: 14
                        ),
                      ),
                    ),
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
                    AppLocalizations.of(context)!.searchOrders),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16), // Tăng padding từ 12 lên 16
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return EmptyState(
                      label: AppLocalizations.of(context)!.noOrdersAvailable,
                      icon: Icons.receipt_long_outlined);
                }

                var orders = snapshot.data!;

                // Filter by status
                if (selectedStatusIndex != 0) { // 0 = All
                  String statusToFilter = rawStatusValues[selectedStatusIndex - 1];
                  orders = orders
                      .where((d) =>
                          (d['statusOrder'] ?? '').toString() == statusToFilter)
                      .toList();
                }

                // Search locally (orderId/email/address/status)
                if (_query.isNotEmpty) {
                  orders = orders.where((order) {
                    final orderId = (order['orderId'] ?? order['id'] ?? '').toString().toLowerCase();
                    final email = (order['email'] ?? '').toString().toLowerCase();
                    
                    // Logic để lấy địa chỉ: shippingAddress (mới) hoặc deliveryInfo (cũ)
                    String addr = '';
                    try {
                      if (order['shippingAddress'] != null) {
                        addr = order['shippingAddress'].toString();
                      } else if (order['address'] != null) {
                        addr = order['address'].toString();
                      } else if (order['deliveryInfo'] != null) {
                        final deliveryInfo = order['deliveryInfo'];
                        if (deliveryInfo is Map<String, dynamic>) {
                          final name = deliveryInfo['name'] ?? '';
                          final phone = deliveryInfo['phone'] ?? '';
                          final address = deliveryInfo['address'] ?? '';
                          addr = '$name $phone $address';
                        } else if (deliveryInfo is String) {
                          addr = deliveryInfo;
                        }
                      }
                    } catch (e) {
                      addr = '';
                    }
                    addr = addr.toLowerCase();
                    
                    final st = (order['statusOrder'] ?? '').toString().toLowerCase();
                    return orderId.contains(_query) ||
                        email.contains(_query) ||
                        addr.contains(_query) ||
                        st.contains(_query);
                  }).toList();
                }

                if (orders.isEmpty) {
                  return EmptyState(
                      label: AppLocalizations.of(context)!.noMatchingOrders,
                      icon: Icons.search_off);
                }

                // Sort by timestamp/createdAt
                orders.sort((a, b) {
                  int getMs(Map<String, dynamic> order) {
                    final ts = order['timestamp'] ?? order['createdAt'];
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
                        (c.maxWidth ~/ 420).clamp(1, 3); // Quay lại 420px như cũ
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 160, // Tăng từ 160 lên 200 để phù hợp với text lớn hơn
                      ),
                      itemCount: orders.length,
                      itemBuilder: (context, i) {
                        final order = orders[i];
                        final orderId = (order['orderId'] ?? order['id'] ?? '').toString();
                        final email = (order['email'] ?? '').toString();
                        final total = order['totalAmount']?.toString() ?? '0';
                        final subtotal = (order['subtotal'] ?? total).toString();
                        final shippingFee = order['shippingFee']?.toString() ?? '0';
                        final status = (order['statusOrder'] ?? '').toString();
                        
                        // Logic để lấy địa chỉ: shippingAddress (mới) hoặc deliveryInfo (cũ)
                        String address = '';
                        try {
                          if (order['shippingAddress'] != null) {
                            address = order['shippingAddress'].toString();
                          } else if (order['address'] != null) {
                            address = order['address'].toString();
                          } else if (order['deliveryInfo'] != null) {
                            final deliveryInfo = order['deliveryInfo'];
                            if (deliveryInfo is Map<String, dynamic>) {
                              final name = deliveryInfo['name'] ?? '';
                              final phone = deliveryInfo['phone'] ?? '';
                              final addr = deliveryInfo['address'] ?? '';
                              address = '$name • $phone\n$addr';
                            } else if (deliveryInfo is String) {
                              address = deliveryInfo;
                            }
                          }
                        } catch (e) {
                          address = '';
                        }
                        
                        final createdAt = order['timestamp'] ?? order['createdAt'];
                        final collection = order['collection'] ?? 'orders';

                        return OrderCard(
                          orderId: orderId,
                          email: email,
                          total: total,
                          subtotal: subtotal,
                          shippingFee: shippingFee,
                          status: status,
                          address: address,
                          createdAt: createdAt,
                          statusColor: _statusColor(status),
                          allStatuses: rawStatusValues,
                          onTap: () => _showOrderDetailsDialog(order),
                          onEdit: () => _showEditOrderDialog(order),
                          onDelete: () => _confirmDeleteOrder(orderId, collection),
                          // Inline status changer
                          onChangeStatus: (newStatus) async {
                            if (newStatus == null || !mounted) return;
                            
                            // Store ScaffoldMessenger reference early to avoid widget disposal issues
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            
                            try {
                              // Store old status for notification
                              final oldStatus = status;

                              final payload = {
                                'statusOrder': newStatus,
                                if (newStatus == 'Completed')
                                  'statusPayment': 'Payment Completed',
                              };
                              await updateOrder(orderId, collection, payload);
                              
                              // Check if widget is still mounted after async operation
                              if (!mounted) return;

                              // Debug order data
                              print('🔍 Order Debug Info:');
                              print('🔍 Order ID: $orderId');
                              print('🔍 New Status: $newStatus');
                              print('🔍 Address: "$address"');
                              print('🔍 Address isEmpty: ${address.isEmpty}');
                              print('🔍 Total: $total');
                              print('🔍 Email: $email');
                              print('🔍 Current tracking number: ${order['trackingNumber']}');

                              // Tạo shipment khi chuyển sang Processing (chỉ nếu chưa có tracking number)
                              if (newStatus == 'Processing' && (order['trackingNumber'] == null || order['trackingNumber'].toString().isEmpty)) {
                                print('🚚 Status is Processing and no tracking number, creating shipment...');
                                
                                if (address.isEmpty) {
                                  print('⚠️ Address is empty! Using fallback address');
                                  address = 'Địa chỉ không xác định, TP.HCM'; // Fallback address
                                }
                                
                                try {
                                  print('🚚 Creating shipment for order: $orderId');
                                  
                                  // Get customer phone from order data
                                  final customerPhone = order['phone']?.toString() ?? 
                                                       order['deliveryInfo']?['phone']?.toString() ?? 
                                                       '0987654321'; // Fallback phone
                                  
                                  // Calculate total weight (estimate 1.5kg per item)
                                  final orderItems = (order['items'] as List?) ?? [];
                                  final totalWeight = orderItems.isNotEmpty ? orderItems.length * 1.5 : 2.0;
                                  
                                  print('📞 Customer phone: "$customerPhone"');
                                  print('📱 Order phone field: ${order['phone']}');
                                  print('📱 DeliveryInfo phone: ${order['deliveryInfo']?['phone']}');
                                  print('⚖️ Total weight: ${totalWeight}kg');
                                  print('📦 Order items count: ${orderItems.length}');
                                  
                                  final result = await ShippingService.createShipment(
                                    orderId: orderId,
                                    shippingAddress: address,
                                    customerInfo: {
                                      'name': order['deliveryInfo']?['name']?.toString() ?? 
                                             order['displayName']?.toString() ?? 
                                             'Khách hàng',
                                      'phone': customerPhone, // ✅ Required by GHN
                                      'email': email,
                                    },
                                    totalValue: _limitInsuranceValue(double.tryParse(total.replaceAll('\$', '')) ?? 0),
                                    totalWeight: totalWeight, // ✅ Required parameter
                                    items: orderItems.isNotEmpty ? orderItems.map((item) => {
                                      'name': item['name']?.toString() ?? 'Pet Store Item',
                                      'quantity': item['quantity'] ?? 1,
                                      'price': item['price'] ?? 0,
                                      'weight': _safeWeight(item['weight']) ?? 1500, // Safe weight conversion
                                    }).toList() : [
                                      {
                                        'name': 'Pet Store Order',
                                        'quantity': 1,
                                        'price': double.tryParse(total.replaceAll('\$', '')) ?? 0,
                                        'weight': 2000, // 2kg in grams (like GHNTestPage)
                                      }
                                    ],
                                  );
                                  
                                  print('🚚 Shipment creation result: ${result['success']}');
                                  
                                  if (result['success']) {
                                    final trackingNumber = result['data']['trackingNumber'];
                                    print('🚚 Tracking number: $trackingNumber');
                                    print('📦 Shipping data keys: ${result['data'].keys.toList()}');
                                    print('📦 Has trackingHistory: ${result['data']['trackingHistory'] != null}');
                                    
                                    // Lưu tracking number vào order
                                    await updateOrder(orderId, collection, {
                                      'trackingNumber': trackingNumber,
                                      'shippingInfo': result['data'],
                                    });
                                    
                                    print('✅ Saved to Firebase - orderId: $orderId, collection: $collection');
                                    
                                    // Verify data was saved by reading it back
                                    final verifyDoc = await FirebaseFirestore.instance
                                        .collection(collection)
                                        .doc(orderId)
                                        .get();
                                    final verifyData = verifyDoc.data();
                                    print('🔍 Verify - trackingNumber in Firebase: ${verifyData?['trackingNumber']}');
                                    print('🔍 Verify - shippingInfo exists: ${verifyData?['shippingInfo'] != null}');
                                    
                                    if (mounted) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text('✅ Đã tạo đơn giao hàng: $trackingNumber'),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  } else {
                                    print('🚚 Shipment creation failed: ${result['message']}');
                                    if (mounted) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Lỗi tạo đơn giao hàng: ${result['message']}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  print('Error creating shipment: $e');
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Lỗi tạo đơn giao hàng: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  // Return early to avoid further processing
                                  return;
                                }
                              } else if (newStatus == 'Processing' && order['trackingNumber'] != null && order['trackingNumber'].toString().isNotEmpty) {
                                print('🚚 Order already has tracking number: ${order['trackingNumber']} - skipping shipment creation');
                                if (mounted) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Đơn hàng đã có mã vận chuyển: ${order['trackingNumber']}'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }

                              // Gửi notification và email
                              if (!mounted) return;
                              if (orderId.isNotEmpty && email.isNotEmpty) {
                                final userInfo = await authService.value
                                    .getInfoUserFromEmail(email);
                                if (userInfo != null && mounted) {
                                  // Send email
                                  sendOrderEmail(
                                    name: (userInfo['displayName'] ?? '')
                                        .toString(),
                                    email: email,
                                    orderId: orderId,
                                    orderStatus: newStatus,
                                  );
                                  
                                  // Send in-app notification
                                  final customerInfo = await OrderNotificationHelper.getCustomerInfoFromEmail(email);
                                  if (customerInfo != null && mounted) {
                                    await OrderNotificationHelper.sendOrderStatusChangeNotification(
                                      userId: customerInfo['userId'],
                                      orderId: orderId,
                                      newStatus: newStatus,
                                      oldStatus: oldStatus,
                                      customerName: customerInfo['displayName'],
                                      email: email,
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              print('❌ Error in onChangeStatus: $e');
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi cập nhật trạng thái: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              return; // Early return to prevent further execution
                            }
                          },
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  SizedBox(height: 8),
                  Text('Đang xử lý...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteOrder(String orderId, String collection) {
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
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              await deleteOrder(orderId, collection);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showEditOrderDialog(Map<String, dynamic> order) {
    final emailController = TextEditingController(text: order['email'] ?? '');
    final totalAmountController =
        TextEditingController(text: (order['totalAmount'] ?? '').toString());
    String selected = (order['statusOrder'] ?? 'Pending').toString();
    final orderId = (order['orderId'] ?? order['id'] ?? '').toString();
    final collection = order['collection'] ?? 'orders';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text(AppLocalizations.of(context)!.editOrder),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.email, border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: totalAmountController,
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.totalAmountLabel, border: OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selected,
                items: rawStatusValues
                    .map((rawStatus) {
                      // Find index to get localized text
                      int index = rawStatusValues.indexOf(rawStatus);
                      String localizedText = statuses[index + 1]; // +1 because statuses includes "All"
                      return DropdownMenuItem(
                        value: rawStatus, 
                        child: Text(localizedText)
                      );
                    })
                    .toList(),
                onChanged: (v) => selected = v ?? selected,
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.statusLabel, border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () async {
              await updateOrder(orderId, collection, {
                'email': emailController.text.trim(),
                'totalAmount':
                    double.tryParse(totalAmountController.text.trim()) ??
                        (order['totalAmount'] ?? 0),
                'statusOrder': selected,
                if (selected == 'Completed')
                  'statusPayment': 'Payment Completed',
              });
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.save, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderDetailsDialog(Map<String, dynamic> order) async {
    if (!mounted) return;

    final String orderId = (order['orderId'] ?? order['id'] ?? '').toString();
    final String email = (order['email'] ?? '').toString();
    final String total = (order['totalAmount'] ?? '0').toString();
    final String statusPay = (order['statusPayment'] ?? '').toString();
    final String method = (order['paymentMethod'] ?? '').toString();
    final String status = (order['statusOrder'] ?? '').toString();
    
    // Logic để lấy địa chỉ: shippingAddress (mới) hoặc deliveryInfo (cũ)
    String address = '';
    try {
      if (order['shippingAddress'] != null) {
        address = order['shippingAddress'].toString();
      } else if (order['address'] != null) {
        address = order['address'].toString();
      } else if (order['deliveryInfo'] != null) {
        final deliveryInfo = order['deliveryInfo'];
        if (deliveryInfo is Map<String, dynamic>) {
          final name = deliveryInfo['name'] ?? '';
          final phone = deliveryInfo['phone'] ?? '';
          final addr = deliveryInfo['address'] ?? '';
          address = '$name • $phone\n$addr';
        } else if (deliveryInfo is String) {
          address = deliveryInfo;
        }
      }
    } catch (e) {
      address = '';
    }
    
    final String phone = (order['phone'] ?? '').toString();
    final dynamic ts = order['timestamp'] ?? order['createdAt'];
    final List<Map<String, dynamic>> items = (order['items'] is List)
        ? (order['items'] as List)
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

    String _getLocalizedStatus(String rawStatus) {
      switch (rawStatus) {
        case 'Pending':
          return AppLocalizations.of(context)!.pending;
        case 'Processing':
          return AppLocalizations.of(context)!.processing;
        case 'Completed':
          return AppLocalizations.of(context)!.completed;
        case 'Cancelled':
          return AppLocalizations.of(context)!.cancelled;
        default:
          return rawStatus;
      }
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
                  '${AppLocalizations.of(context)!.orderDetails} · $orderId',
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
                    Text(_getLocalizedStatus(status), style: TextStyle(color: _statusColor(status))),
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
                                  Expanded(child: _kv(AppLocalizations.of(context)!.email, email)),
                                  if (!isNarrow) const SizedBox(width: 24),
                                  if (!isNarrow)
                                    Expanded(
                                        child: _kv(AppLocalizations.of(context)!.totalAmountLabel, CurrencyHelper.formatVND(total))),
                                ],
                              ),
                              if (isNarrow) const SizedBox(height: 8),
                              if (isNarrow)
                                Row(children: [
                                  Expanded(
                                      child: _kv(AppLocalizations.of(context)!.totalAmountLabel, CurrencyHelper.formatVND(total)))
                                ]),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _kv(AppLocalizations.of(context)!.statusPay, statusPay)),
                                  if (!isNarrow) const SizedBox(width: 24),
                                  if (!isNarrow)
                                    Expanded(
                                        child: _kv(AppLocalizations.of(context)!.paymentMethod, method)),
                                ],
                              ),
                              if (isNarrow) const SizedBox(height: 8),
                              if (isNarrow)
                                Row(children: [
                                  Expanded(child: _kv(AppLocalizations.of(context)!.paymentMethod, method))
                                ]),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _kv(AppLocalizations.of(context)!.address, address)),
                                  if (!isNarrow) const SizedBox(width: 24),
                                  if (!isNarrow)
                                    Expanded(child: _kv(AppLocalizations.of(context)!.phone, phone)),
                                ],
                              ),
                              if (isNarrow) const SizedBox(height: 8),
                              if (isNarrow)
                                Row(children: [
                                  Expanded(child: _kv(AppLocalizations.of(context)!.phone, phone))
                                ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: _kv(AppLocalizations.of(context)!.createdAt, _fmtDate(ts)))
                              ]),
                            ],
                          );
                        },
                      ),
                    ),

                    // Thêm tracking widget nếu có trackingNumber
                    if (order['trackingNumber'] != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Thông tin giao hàng',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          TextButton.icon(
                            icon: Icon(Icons.refresh, size: 18),
                            label: Text('Làm mới'),
                            onPressed: () async {
                              // Force refresh tracking data
                              Navigator.pop(ctx);
                              await Future.delayed(Duration(milliseconds: 100));
                              _showOrderDetailsDialog(order);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ShippingTrackingWidget(
                        trackingNumber: order['trackingNumber'].toString(),
                        // Chỉ trang quản lý vận chuyển mới được chỉnh trạng thái
                        isAdminView: false,
                      ),
                    ] else if (status == 'Processing') ...[
                      // Nếu đơn đang xử lý nhưng chưa có tracking number
                      const SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Chưa tạo đơn giao hàng',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(height: 4),
                                  Text('Đơn hàng đang xử lý nhưng chưa có mã vận chuyển. '
                                       'Hãy kiểm tra lại hoặc tạo đơn giao hàng thủ công.',
                                       style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: Icon(Icons.local_shipping, size: 16),
                              label: Text('Tạo đơn'),
                              onPressed: () async {
                                // Tạo shipment thủ công
                                await _createShipmentManually(order);
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(AppLocalizations.of(context)!.items,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 8),

                    // List items (khung chiều cao hữu hạn)
                    SizedBox(
                      height: 300,
                      child: items.isEmpty
                          ? Center(child: Text(AppLocalizations.of(context)!.noItems))
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
                                  subtitle: Text('Giá: ${CurrencyHelper.formatVND(price)}'),
                                  trailing: Text(
                                    CurrencyHelper.formatVND(_safeMul(price, qty)),
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
              child: Text(AppLocalizations.of(context)!.close),
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

  /// Limit insurance value to GHN maximum (5M VND)
  double _limitInsuranceValue(double value) {
    const maxInsuranceValue = 5000000.0; // 5M VND limit
    return value > maxInsuranceValue ? maxInsuranceValue : value;
  }

  /// Convert weight safely to int (grams)
  int? _safeWeight(dynamic weight) {
    try {
      if (weight == null) return null;
      
      if (weight is int) return weight;
      if (weight is double) return weight.toInt();
      
      if (weight is String) {
        final parsed = double.tryParse(weight);
        if (parsed != null) return parsed.toInt();
      }
      
      return null;
    } catch (e) {
      print('❌ Error converting weight: $weight ($e)');
      return null;
    }
  }

  /// Tạo shipment thủ công cho đơn hàng
  Future<void> _createShipmentManually(Map<String, dynamic> order) async {
    final orderId = (order['orderId'] ?? order['id'] ?? '').toString();
    final collection = order['collection'] ?? 'orders';
    
    // Get address
    String address = '';
    try {
      if (order['shippingAddress'] != null) {
        address = order['shippingAddress'].toString();
      } else if (order['address'] != null) {
        address = order['address'].toString();
      } else if (order['deliveryInfo'] != null) {
        final deliveryInfo = order['deliveryInfo'];
        if (deliveryInfo is Map<String, dynamic>) {
          final addr = deliveryInfo['address'] ?? '';
          address = addr.toString();
        } else if (deliveryInfo is String) {
          address = deliveryInfo;
        }
      }
    } catch (e) {
      address = '';
    }
    
    if (address.isEmpty) {
      address = 'Địa chỉ không xác định, TP.HCM';
    }
    
    final email = (order['email'] ?? '').toString();
    final total = (order['totalAmount'] ?? '0').toString();
    
    try {
      setState(() => isLoading = true);
      
      // Get customer phone
      final customerPhone = order['phone']?.toString() ?? 
                           order['deliveryInfo']?['phone']?.toString() ?? 
                           '0987654321';
      
      // Calculate weight
      final orderItems = (order['items'] as List?) ?? [];
      final totalWeight = orderItems.isNotEmpty ? orderItems.length * 1.5 : 2.0;
      
      // Prefer precise coordinates from deliveryInfo if available
      double? destLat;
      double? destLng;
      try {
        final di = order['deliveryInfo'];
        if (di is Map<String, dynamic>) {
          final nlat = (di['lat'] ?? di['latitude']);
          final nlng = (di['lng'] ?? di['longitude']);
          if (nlat is num && nlng is num) {
            destLat = nlat.toDouble();
            destLng = nlng.toDouble();
          }
        }
      } catch (_) {}

      final result = await ShippingService.createShipment(
        orderId: orderId,
        shippingAddress: address,
        customerInfo: {
          'name': order['deliveryInfo']?['name']?.toString() ?? 
                 order['displayName']?.toString() ?? 
                 'Khách hàng',
          'phone': customerPhone,
          'email': email,
        },
        totalValue: _limitInsuranceValue(double.tryParse(total.replaceAll('\$', '')) ?? 0),
        totalWeight: totalWeight,
        items: orderItems.isNotEmpty ? orderItems.map((item) => {
          'name': item['name']?.toString() ?? 'Pet Store Item',
          'quantity': item['quantity'] ?? 1,
          'price': item['price'] ?? 0,
          'weight': _safeWeight(item['weight']) ?? 1500,
        }).toList() : [
          {
            'name': 'Pet Store Order',
            'quantity': 1,
            'price': double.tryParse(total.replaceAll('\$', '')) ?? 0,
            'weight': 2000,
          }
        ],
        destinationLat: destLat,
        destinationLng: destLng,
      );
      
      if (result['success']) {
        final shipmentData = Map<String, dynamic>.from(result['data']);
        final trackingNumber = shipmentData['trackingNumber'];

        // Force destination to use precise coords if present
        if (destLat != null && destLng != null) {
          shipmentData['destination'] = {
            'name': address,
            'lat': destLat,
            'lng': destLng,
          };
        }
        
        await updateOrder(orderId, collection, {
          'trackingNumber': trackingNumber,
          'shippingInfo': shipmentData,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Đã tạo đơn giao hàng: $trackingNumber'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Reload dialog
          await Future.delayed(Duration(milliseconds: 500));
          _showOrderDetailsDialog(order);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Lỗi: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error creating shipment manually: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi tạo đơn: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
}
