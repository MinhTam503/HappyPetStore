import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pet_shop/view/mobile/detail_pet.dart';

import '../../utils/contants.dart';

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
    if (user != null) {
      setState(() {
        userData = user;
      });
    }
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
        return FontAwesomeIcons.timesCircle;
      default:
        return FontAwesomeIcons.questionCircle;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        title: const Text(
          "Your Orders",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          DropdownButton<String>(
            value: statusFilter,
            items: ['All', 'Pending', 'Processing', 'Completed', 'Cancelled']
                .map((status) => DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                statusFilter = value!;
              });
            },
            underline: Container(),
            style: const TextStyle(color: Colors.black, fontSize: 16),
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
      body: StreamBuilder(
        stream: ordersCollection
            .where('email', isEqualTo: userData?['email'])
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No orders found"));
          }
          // Lọc theo trạng thái
          var orders = snapshot.data!.docs.toList();
          if (statusFilter != 'All') {
            orders = orders.where((doc) => doc['statusOrder'] == statusFilter).toList();
          }
          // Sắp xếp theo thời gian
          orders.sort((a, b) {
            final aTime = a['timestamp'] is Timestamp ? (a['timestamp'] as Timestamp).millisecondsSinceEpoch : 0;
            final bTime = b['timestamp'] is Timestamp ? (b['timestamp'] as Timestamp).millisecondsSinceEpoch : 0;
            return orderSort == 'desc' ? bTime.compareTo(aTime) : aTime.compareTo(bTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              var order = orders[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  leading: Icon(
                    getStatusIcon(order['statusOrder']),
                    color: getStatusColor(order['statusOrder']),
                  ),
                  title: Text("Order ID: ${order['orderId']}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total: \$${order['totalAmount']}",
                          style: const TextStyle(fontSize: 16)),
                      Text("Status Pay: ${order['statusPayment']}",
                          style: const TextStyle(fontSize: 16)),
                      Text("Status: ${order['statusOrder']}",
                          style: TextStyle(
                              color: getStatusColor(order['statusOrder']),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: order['statusOrder'] == 'Pending'
                      ? IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => cancelOrder(order.id),
                        )
                      : null,
                  onTap: () => _showOrderDetailsDialog(order),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showOrderDetailsDialog(QueryDocumentSnapshot order) async {
    List<dynamic> items = order['items'];
    List<Map<String, dynamic>> petsData = [];

    for (var item in items) {
      String productId = item['productId'];
      var petSnapshot = await FirebaseFirestore.instance
          .collection('Pets')
          .doc(productId)
          .get();

      if (petSnapshot.exists) {
        Map<String, dynamic> petData = petSnapshot.data()!;
        petsData.add({...petData, 'quantity': item['quantity']});
      }
    }

    if (!mounted) return;

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
                Text("Status: ${order['statusOrder']}",
                    style: TextStyle(
                        color: getStatusColor(order['statusOrder']),
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                  "Items:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Column(
                  children: petsData.map((petData) {
                    return ListTile(
                      leading: Image.network(petData['imageUrl'],
                          width: 50, height: 50, fit: BoxFit.cover),
                      title: GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        DetailPet(grocery: petData)));
                          },
                          child: Text(
                            petData['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )),
                      subtitle: Text("\$ ${petData['weight']}"),
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
