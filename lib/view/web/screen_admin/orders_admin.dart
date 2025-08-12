import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'send_email.dart';

class OrdersAdmin extends StatefulWidget {
  const OrdersAdmin({super.key});

  @override
  State<OrdersAdmin> createState() => _OrdersAdminState();
}

class _OrdersAdminState extends State<OrdersAdmin> {
  final CollectionReference ordersCollection =
      FirebaseFirestore.instance.collection('orders');
  String selectedStatus = 'All';
  final List<String> statuses = [
    'All',
    'Pending',
    'Processing',
    'Completed',
    'Cancelled'
  ];
  bool isLoading = false;
  String orderSort = 'desc'; // 'desc' = mới nhất trước, 'asc' = cũ nhất trước

  void updateOrder(String orderId, Map<String, dynamic> newData) async {
    setState(() => isLoading = true);
    await ordersCollection.doc(orderId).update(newData);
    setState(() => isLoading = false);
  }

  void deleteOrder(String orderId) async {
    setState(() => isLoading = true);
    await ordersCollection.doc(orderId).delete();
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        actions: [
          DropdownButton<String>(
            value: selectedStatus,
            onChanged: (String? newValue) {
              setState(() {
                selectedStatus = newValue!;
              });
            },
            items: statuses.map<DropdownMenuItem<String>>((String status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(status),
              );
            }).toList(),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: orderSort,
            items: const [
              DropdownMenuItem(value: 'desc', child: Text('Mới nhất')),
              DropdownMenuItem(value: 'asc', child: Text('Cũ nhất')),
            ],
            onChanged: (value) {
              setState(() {
                orderSort = value!;
              });
            },
            underline: Container(),
            style: const TextStyle(color: Colors.black, fontSize: 16),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder(
            stream: ordersCollection.snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No orders available'));
              }

              var orders = snapshot.data!.docs.toList();
              if (selectedStatus != 'All') {
                orders = orders
                    .where((doc) => doc['statusOrder'] == selectedStatus)
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

              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  var order = orders[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      title: Text("Order ID: ${order['orderId']}",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          "Total: \$${order['totalAmount']} - Status: ${order['statusOrder']}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<String>(
                            value: order['statusOrder'],
                            onChanged: (String? newStatus) async {
                              if (newStatus != null) {
                                if(newStatus == "Completed")
                                  {
                                    updateOrder(
                                        order.id, {'statusOrder': newStatus,'statusPayment': 'Payment Completed'});
                                  }
                                else
                                  {
                                    updateOrder(
                                        order.id, {'statusOrder': newStatus});
                                  }
                                updateOrder(
                                    order.id, {'statusOrder': newStatus});
                                if (order['orderId'].isNotEmpty &&
                                    order['email'].isNotEmpty) {
                                  Map<String, dynamic>? userInfo =
                                      await authService.value
                                          .getInfoUserFromEmail(order['email']);
                                  if (userInfo != null) {
                                    sendOrderEmail(
                                      name:
                                          userInfo['displayName']?.toString() ??
                                              "",
                                      email: order['email'],
                                      orderId: order['orderId'],
                                      orderStatus: newStatus,
                                    );
                                  }
                                } else {
                                  print("Thông tin không đầy đủ để gửi email.");
                                }
                              }
                            },
                            items: statuses.sublist(1).map((String status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditOrderDialog(order),
                          ),
                          IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteOrder(order.id)),
                        ],
                      ),
                      onTap: () => _showOrderDetailsDialog(order),
                    ),
                  );
                },
              );
            },
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteOrder(String orderId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this order?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                deleteOrder(orderId);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEditOrderDialog(QueryDocumentSnapshot order) {
    TextEditingController emailController =
        TextEditingController(text: order['email']);
    TextEditingController totalAmountController =
        TextEditingController(text: order['totalAmount'].toString());
    String selectedStatus = order['statusOrder'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Order"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: totalAmountController,
                decoration: const InputDecoration(labelText: 'Total Amount'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: statuses.sublist(1).map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (newValue) => selectedStatus = newValue!,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                updateOrder(order.id, {
                  'email': emailController.text,
                  'totalAmount': double.tryParse(totalAmountController.text) ??
                      order['totalAmount'],
                  'statusOrder': selectedStatus,
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showOrderDetailsDialog(QueryDocumentSnapshot order) {
    final orderMap = order.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Order Details"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Email: ${order['email']}",
                    style: const TextStyle(fontSize: 16)),
                Text("Total Amount: \$${order['totalAmount']}",
                    style: const TextStyle(fontSize: 16)),
                Text("Status Pay: ${order['statusPayment']}",
                    style: const TextStyle(fontSize: 16)),
                Text("Payment Method: ${order['paymentMethod']}",
                    style: const TextStyle(fontSize: 16)),
                Text("Status: ${order['statusOrder']}",
                    style: const TextStyle(fontSize: 16)),
                Text("Address: ${order['shippingAddress']}",
                    style: const TextStyle(fontSize: 16)),
                orderMap['phone'] != null &&
                        orderMap['phone'] is String &&
                        orderMap['phone'].trim().isNotEmpty
                    ? Text("Phone: " + orderMap['phone'],
                        style: const TextStyle(fontSize: 16))
                    : const SizedBox(),
                const SizedBox(height: 10),
                const Text("Items:",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Column(
                  children: (order['items'] as List<dynamic>).map((item) {
                    return ListTile(
                      leading: (item is Map &&
                              item['imageUrl'] != null &&
                              (item['imageUrl'] as String).isNotEmpty)
                          ? Image.network(item['imageUrl'],
                              width: 70, height: 70, fit: BoxFit.cover)
                          : null,
                      title: Text(item['name']),
                      subtitle: Text(" \$${item['price']}"),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
