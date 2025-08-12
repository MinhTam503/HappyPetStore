import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountAdmin extends StatefulWidget {
  const AccountAdmin({super.key});

  @override
  State<AccountAdmin> createState() => _AccountAdminState();
}

class _AccountAdminState extends State<AccountAdmin> {
  final CollectionReference accountsCollection =
  FirebaseFirestore.instance.collection('users');
  final CollectionReference ordersCollection =
  FirebaseFirestore.instance.collection('orders');
  bool isLoading = false;

  void addAccount(Map<String, dynamic> account) async {
    try {
      setState(() => isLoading = true);
      await accountsCollection.add(account);
    } catch (e) {
      print('Error adding account: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void updateAccount(String id, Map<String, dynamic> account) async {
    try {
      setState(() => isLoading = true);
      await accountsCollection.doc(id).update(account);
    } catch (e) {
      print('Error updating account: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void deleteAccount(String id) async {
    try {
      setState(() => isLoading = true);
      await accountsCollection.doc(id).delete();
    } catch (e) {
      print('Error deleting account: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Accounts')),
      body: Stack(
        children: [
          StreamBuilder(
            stream: accountsCollection.snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No accounts available'));
              }

              var accounts = snapshot.data!.docs;
              return ListView.builder(
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  var account = accounts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: account.get('imageUrl') != null
                            ? NetworkImage(account.get('imageUrl'))
                            : null,
                        child: account.get('imageUrl') == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(account.get('displayName') ?? 'No Name'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.get('email') ?? 'No Email'),
                          Text(account.get('phone') ?? 'No Phone'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showAccountDialog(account.id, account),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteAccount(account.id),
                          ),
                        ],
                      ),
                      onTap: () => _showUserOrders(account.get('email'), account.get('displayName')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(null, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showUserOrders(String userId, String? userName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Orders of $userName"),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder(
              stream: ordersCollection.where('email', isEqualTo: userId).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No orders found'));
                }

                var orders = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    var order = orders[index];
                    return ListTile(
                      title: Text("Order ID: ${order.id}"),
                      subtitle: Text("Total: \$${order['totalAmount']} - Status: ${order['statusOrder']}"),
                    );
                  },
                );
              },
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

  void _showAccountDialog(String? id, QueryDocumentSnapshot? account) {
    final nameController = TextEditingController(text: account?.get('displayName') ?? '');
    final emailController = TextEditingController(text: account?.get('email') ?? '');
    final phoneController = TextEditingController(text: account?.get('phone') ?? '');
    final roleController = TextEditingController(text: account?.get('role') ?? '');
    final imageUrlController = TextEditingController(text: account?.get('imageUrl') ?? '');
    // Address is a List<String>
    List<String> addressList = [];
    final data = account?.data();
    if (account != null && data != null && data is Map && data.containsKey('address') && account.get('address') is List) {
      addressList = List<String>.from(account.get('address'));
    }
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(id == null ? 'Add Account' : 'Edit Account'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Display Name')),
                    TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                    TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                    TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Role')),
                    TextField(controller: imageUrlController, decoration: const InputDecoration(labelText: 'Image URL')),
                    const SizedBox(height: 10),
                    // const Align(
                    //   alignment: Alignment.centerLeft,
                    //   child: Text('Addresses:', style: TextStyle(fontWeight: FontWeight.bold)),
                    // ),
                    // DropdownButtonFormField<String>(
                    //   isExpanded: true,
                    //   value: addressList.isNotEmpty ? addressList.first : null,
                    //   items: addressList
                    //       .map((address) => DropdownMenuItem(
                    //             value: address,
                    //             child: Text(address, overflow: TextOverflow.ellipsis),
                    //           ))
                    //       .toList(),
                    //   onChanged: (value) {},
                    //   decoration: const InputDecoration(labelText: 'Địa chỉ đã có'),
                    // ),
                    // Container(
                    //   constraints: const BoxConstraints(maxHeight: 200),
                    //   child: addressList.isEmpty
                    //       ? Container(
                    //           padding: const EdgeInsets.all(12),
                    //           decoration: BoxDecoration(
                    //             color: Colors.grey[100],
                    //             borderRadius: BorderRadius.circular(8),
                    //           ),
                    //           child: const Center(child: Text("Chưa có địa chỉ nào")),
                    //         )
                    //       : ListView.separated(
                    //           shrinkWrap: true,
                    //           physics: const ClampingScrollPhysics(),
                    //           itemCount: addressList.length,
                    //           separatorBuilder: (_, __) => const SizedBox(height: 6),
                    //           itemBuilder: (context, idx) => Card(
                    //             elevation: 1,
                    //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    //             child: ListTile(
                    //               leading: const Icon(Icons.location_on, color: Colors.blue),
                    //               title: Text(addressList[idx]),
                    //               trailing: IconButton(
                    //                 icon: const Icon(Icons.delete, color: Colors.red),
                    //                 onPressed: () {
                    //                   setStateDialog(() {
                    //                     addressList.removeAt(idx);
                    //                   });
                    //                 },
                    //               ),
                    //             ),
                    //           ),
                    //         ),
                    // ),
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: TextButton.icon(
                    //         icon: const Icon(Icons.add_location_alt_outlined),
                    //         label: const Text('Thêm địa chỉ mới'),
                    //         onPressed: () async {
                    //           String? selectedProvince;
                    //           String? selectedDistrict;
                    //           String detail = '';
                    //           final List<String> provinces = [
                    //             'Hà Nội', 'Hồ Chí Minh', 'Đà Nẵng', 'Hải Phòng', 'Cần Thơ',
                    //             // ... thêm các tỉnh thành khác nếu muốn
                    //           ];
                    //           final Map<String, List<String>> districts = {
                    //             'Hà Nội': [
                    //               'Ba Đình', 'Hoàn Kiếm', 'Tây Hồ', 'Long Biên', 'Cầu Giấy',
                    //               'Đống Đa', 'Hai Bà Trưng', 'Hoàng Mai', 'Thanh Xuân',
                    //               'Sóc Sơn', 'Đông Anh', 'Gia Lâm', 'Thanh Trì', 'Nam Từ Liêm', 'Bắc Từ Liêm'
                    //             ],
                    //             'Hồ Chí Minh': [
                    //               'Quận 1', 'Quận 2', 'Quận 3', 'Quận 4', 'Quận 5', 'Quận 6',
                    //               'Quận 7', 'Quận 8', 'Quận 9', 'Quận 10', 'Quận 11', 'Quận 12',
                    //               'Bình Thạnh', 'Gò Vấp', 'Phú Nhuận', 'Tân Bình', 'Tân Phú',
                    //               'Thủ Đức', 'Bình Tân', 'Bình Chánh', 'Cần Giờ', 'Củ Chi', 'Hóc Môn', 'Nhà Bè'
                    //             ],
                    //             'Đà Nẵng': [
                    //               'Hải Châu', 'Thanh Khê', 'Liên Chiểu', 'Ngũ Hành Sơn', 'Sơn Trà', 'Hòa Vang', 'Cẩm Lệ'
                    //             ],
                    //             // ... thêm các tỉnh thành khác nếu muốn
                    //           };
                    //           final result = await showDialog<String>(
                    //             context: context,
                    //             builder: (context) {
                    //               return StatefulBuilder(
                    //                 builder: (context, setStateDialog2) {
                    //                   return AlertDialog(
                    //                     title: const Text('Thêm địa chỉ mới'),
                    //                     content: SingleChildScrollView(
                    //                       child: Column(
                    //                         mainAxisSize: MainAxisSize.min,
                    //                         children: [
                    //                           DropdownButtonFormField<String>(
                    //                             isExpanded: true,
                    //                             decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố'),
                    //                             value: selectedProvince,
                    //                             items: provinces
                    //                                 .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    //                                 .toList(),
                    //                             onChanged: (value) {
                    //                               setStateDialog2(() {
                    //                                 selectedProvince = value;
                    //                                 selectedDistrict = null;
                    //                               });
                    //                             },
                    //                           ),
                    //                           const SizedBox(height: 10),
                    //                           DropdownButtonFormField<String>(
                    //                             isExpanded: true,
                    //                             decoration: const InputDecoration(labelText: 'Quận/Huyện'),
                    //                             value: selectedDistrict,
                    //                             items: (selectedProvince != null && districts[selectedProvince!] != null)
                    //                                 ? districts[selectedProvince!]!
                    //                                     .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    //                                     .toList()
                    //                                 : [],
                    //                             onChanged: (value) {
                    //                               setStateDialog2(() {
                    //                                 selectedDistrict = value;
                    //                               });
                    //                             },
                    //                           ),
                    //                           const SizedBox(height: 10),
                    //                           TextField(
                    //                             decoration: const InputDecoration(
                    //                                 labelText: 'Thông tin chi tiết (số nhà, tên đường...)'),
                    //                             onChanged: (value) => detail = value,
                    //                           ),
                    //                         ],
                    //                       ),
                    //                     ),
                    //                     actions: [
                    //                       TextButton(
                    //                         onPressed: () => Navigator.pop(context),
                    //                         child: const Text('Hủy'),
                    //                       ),
                    //                       TextButton(
                    //                         onPressed: () {
                    //                           if (selectedProvince != null &&
                    //                               selectedDistrict != null &&
                    //                               detail.trim().isNotEmpty) {
                    //                             final address = '$detail, $selectedDistrict, $selectedProvince';
                    //                             Navigator.pop(context, address);
                    //                           } else {
                    //                             ScaffoldMessenger.of(context).showSnackBar(
                    //                               const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin địa chỉ!')),
                    //                             );
                    //                           }
                    //                         },
                    //                         child: const Text('Lưu'),
                    //                       ),
                    //                     ],
                    //                   );
                    //                 },
                    //               );
                    //             },
                    //           );
                    //           if (result != null && result.isNotEmpty) {
                    //             setStateDialog(() {
                    //               addressList.add(result);
                    //             });
                    //           }
                    //         },
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final data = {
                      'displayName': nameController.text,
                      'email': emailController.text,
                      'phone': phoneController.text,
                      'role': roleController.text,
                      'imageUrl': imageUrlController.text,
                      // 'address': addressList,
                    };
                    if (id == null) {
                      addAccount(data);
                    } else {
                      updateAccount(id, data);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

}