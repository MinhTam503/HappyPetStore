import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_shop/utils/contants.dart';

import '../../utils/list_city.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  Map<String, dynamic>? user;
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  String? email = FirebaseAuth.instance.currentUser?.email;
  String imageUrl = "";
  List<String> addresses = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(authUser.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        user = userDoc.data() as Map<String, dynamic>;
        displayNameController.text = user?['displayName'] ?? "";
        phoneController.text = user?['phone'] ?? "";
        addresses =
            user?['address'] is List ? List<String>.from(user?['address']) : [];
        imageUrl = user?['imageUrl'] ?? "";
      });
    }
  }

  Future<void> addAddressDialog() async {
    List<String> provinces = ListCity().city;
    Map<String, List<String>> districts = ListCity().districts;
    String? selectedProvince;
    String? selectedDistrict;
    String detail = '';
    await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Thêm địa chỉ mới'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Tỉnh/Thành phố'),
                          value: selectedProvince,
                          items: provinces
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedProvince = value;
                              selectedDistrict = null;
                            });
                          }),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Quận/Huyện',
                        ),
                        value: selectedDistrict,
                        items: (selectedProvince != null &&
                                districts[selectedProvince] != null)
                            ? districts[selectedProvince]!
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ))
                                .toList()
                            : [],
                        onChanged: (value) {
                          setState(() {
                            selectedDistrict = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          labelText:
                              'Thông tin chi tiết (số nhà, tên đường...)',
                        ),
                        onChanged: (value) => detail = value,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                      )
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Hủy"),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (selectedDistrict != null &&
                          selectedProvince != null &&
                          detail.trim().isNotEmpty &&
                          email != null) {
                        final newAddress =
                            '$detail,$selectedDistrict,$selectedProvince';
                        final userQuery = await FirebaseFirestore.instance
                            .collection('users')
                            .where('email', isEqualTo: email)
                            .limit(1)
                            .get();
                        if (userQuery.docs.isEmpty) return;
                        final userRef = userQuery.docs.first.reference;
                        final userDoc = userQuery.docs.first.data();
                        var addr = userDoc['address'];
                        if (addr == null || (addr is String && addr.isEmpty)) {
                          userRef.update({
                            'address': [newAddress]
                          });
                          setState(() {
                            addresses = [newAddress];
                          });
                        } else if (addr is List) {
                          userRef.update({
                            'address': FieldValue.arrayUnion([newAddress]),
                          });
                          Navigator.pop(context);

                          await fetchUserData();
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Vui lòng nhập đầy đủ thông tin"),
                          ),
                        );
                      }
                    },
                    child: const Text('Lưu'),
                  )
                ],
              );
            },
          );
        });
  }

  void removeAddress(int index) {
    setState(() {
      addresses.removeAt(index);
    });
  }

  Future<void> updateUserData() async {
    User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;
    await FirebaseFirestore.instance
        .collection("users")
        .doc(authUser.uid)
        .update({
      'displayName': displayNameController.text,
      'phone': phoneController.text,
      'address': addresses,
      'imageUrl': imageUrl,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
    fetchUserData(); // Reload dữ liệu sau khi cập nhật
  }

  Future<void> pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    File imageFile = File(pickedFile.path);
    User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    // Tải ảnh lên Firebase Storage
    String fileName = "profile_${authUser.uid}.jpg";
    Reference storageRef =
        FirebaseStorage.instance.ref().child("profile_images/$fileName");
    await storageRef.putFile(imageFile);

    // Lấy URL ảnh sau khi tải lên
    String newImageUrl = await storageRef.getDownloadURL();

    // Cập nhật Firestore
    await FirebaseFirestore.instance
        .collection("users")
        .doc(authUser.uid)
        .update({
      'imageUrl': newImageUrl,
    });

    setState(() {
      imageUrl = newImageUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture updated!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        title: Text("${user?['email']}",
            style: const TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: primaryColor, width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 55,
                            backgroundImage: imageUrl.isNotEmpty
                                ? NetworkImage(imageUrl)
                                : null,
                            backgroundColor: Colors.white,
                            child: imageUrl.isEmpty
                                ? const Icon(Icons.camera_alt,
                                    size: 40, color: Colors.grey)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text("Chạm vào để thay đổi ảnh đại diện",
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: displayNameController,
                              decoration: const InputDecoration(
                                labelText: "Tên hiển thị",
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: phoneController,
                              decoration: const InputDecoration(
                                labelText: "Số điện thoại",
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Địa chỉ nhận hàng",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        ElevatedButton.icon(
                          onPressed: addAddressDialog,
                          icon: const Icon(Icons.add_location_alt_outlined,
                              size: 20),
                          label: const Text("Thêm địa chỉ"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    addresses.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                                child: Text("Chưa có địa chỉ nào")),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: addresses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) => Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.location_on,
                                    color: primaryColor),
                                title: Text(addresses[index]),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => removeAddress(index),
                                  tooltip: 'Xóa địa chỉ',
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: updateUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        child: const Text("Lưu thay đổi"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
