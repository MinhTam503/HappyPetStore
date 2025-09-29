import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'address_edit_page.dart';

class AddressListPage extends StatefulWidget {
  final Map<String, dynamic>? selectedAddress;
  final Function(Map<String, dynamic>)? onAddressSelected;

  const AddressListPage({
    super.key,
    this.selectedAddress,
    this.onAddressSelected,
  });

  @override
  State<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends State<AddressListPage> {
  List<Map<String, dynamic>> addresses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        // Check for new deliveryInfos format first
        var deliveryData = userData['deliveryInfos'];
        if (deliveryData is List && deliveryData.isNotEmpty) {
          setState(() {
            addresses = List<Map<String, dynamic>>.from(deliveryData);
            isLoading = false;
          });
          return;
        }
        
        // Fallback to old address format for migration
        var addr = userData['address'];
        if (addr == null || (addr is String && addr.isEmpty)) {
          setState(() {
            addresses = [];
            isLoading = false;
          });
        } else if (addr is List) {
          // Migrate old addresses to new format
          final migratedAddresses = addr
              .map<Map<String, dynamic>>((address) => {
                    'name': userData['displayName'] ?? '',
                    'phone': userData['phone'] ?? '',
                    'address': address.toString(),
                    'isDefault': addresses.isEmpty,
                  })
              .toList();
          
          setState(() {
            addresses = migratedAddresses;
            isLoading = false;
          });
          
          // Save migrated data back to Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'deliveryInfos': migratedAddresses});
        } else {
          setState(() {
            addresses = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      NotificationHelper.showError(context, 'Lỗi', 'Không thể tải danh sách địa chỉ: $e');
    }
  }

  Future<void> _setDefaultAddress(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update local state
      setState(() {
        for (int i = 0; i < addresses.length; i++) {
          addresses[i]['isDefault'] = i == index;
        }
      });

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'deliveryInfos': addresses});

      NotificationHelper.showSuccess(context, 'Thành công', 'Đã đặt làm địa chỉ mặc định');
    } catch (e) {
      NotificationHelper.showError(context, 'Lỗi', 'Không thể cập nhật địa chỉ mặc định: $e');
    }
  }

  Future<void> _deleteAddress(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa địa chỉ này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        addresses.removeAt(index);
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'deliveryInfos': addresses});

      NotificationHelper.showSuccess(context, 'Thành công', 'Đã xóa địa chỉ');
    } catch (e) {
      NotificationHelper.showError(context, 'Lỗi', 'Không thể xóa địa chỉ: $e');
    }
  }

  void _navigateToEdit([Map<String, dynamic>? address, int? index]) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddressEditPage(
          address: address,
          isEdit: address != null,
        ),
      ),
    );

    if (result != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        if (index != null) {
          // Edit existing address
          setState(() {
            addresses[index] = result;
          });
        } else {
          // Add new address
          setState(() {
            // If this is the first address, set as default
            if (addresses.isEmpty) {
              result['isDefault'] = true;
            }
            addresses.add(result);
          });
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'deliveryInfos': addresses});

        NotificationHelper.showSuccess(
          context, 
          'Thành công', 
          index != null ? 'Đã cập nhật địa chỉ' : 'Đã thêm địa chỉ mới'
        );
      } catch (e) {
        NotificationHelper.showError(context, 'Lỗi', 'Không thể lưu địa chỉ: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Địa chỉ của bạn',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: primaryColor),
            onPressed: () => _navigateToEdit(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có địa chỉ nào',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thêm địa chỉ để tiếp tục đặt hàng',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToEdit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm địa chỉ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    final isDefault = address['isDefault'] == true;
                    final isSelected = widget.selectedAddress != null &&
                        address['address'] == widget.selectedAddress!['address'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 4 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? primaryColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (widget.onAddressSelected != null) {
                            widget.onAddressSelected!(address);
                            Navigator.pop(context);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      address['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Mặc định',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                address['phone'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                address['address'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (!isDefault)
                                    TextButton(
                                      onPressed: () => _setDefaultAddress(index),
                                      child: const Text('Đặt mặc định'),
                                    ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _navigateToEdit(address, index),
                                    child: const Text('Sửa'),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteAddress(index),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Xóa'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}