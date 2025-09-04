import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/constants/list_city.dart';



class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  Map<String, dynamic>? user;
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String? email = FirebaseAuth.instance.currentUser?.email;
  String imageUrl = "";
  List<String> addresses = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // =========================
  // Data
  // =========================
  Future<void> fetchUserData() async {
    User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection("users").doc(authUser.uid).get();

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

  Future<void> updateUserData() async {
    User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection("users").doc(authUser.uid).update({
        'displayName': displayNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addresses,
        'imageUrl': imageUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        await fetchUserData(); // Reload dữ liệu sau khi cập nhật
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
    await FirebaseFirestore.instance.collection("users").doc(authUser.uid).update({
      'imageUrl': newImageUrl,
    });

    setState(() {
      imageUrl = newImageUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture updated!')),
    );
  }

  // =========================
  // Address
  // =========================
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
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Thêm địa chỉ mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: _inputDecoration("Tỉnh/Thành phố"),
                      value: selectedProvince,
                      items: provinces
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedProvince = value;
                          selectedDistrict = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: _inputDecoration("Quận/Huyện"),
                      value: selectedDistrict,
                      items: (selectedProvince != null &&
                          districts[selectedProvince] != null)
                          ? districts[selectedProvince]!
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList()
                          : [],
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedDistrict = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: _inputDecoration(
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
                          '$detail, $selectedDistrict, $selectedProvince';

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
                        await userRef.update({'address': [newAddress]});
                        setState(() {
                          addresses = [newAddress];
                        });
                      } else if (addr is List) {
                        await userRef.update({
                          'address': FieldValue.arrayUnion([newAddress]),
                        });
                        // Cập nhật local ngay để UI phản hồi
                        setState(() {
                          addresses = [...addresses, newAddress];
                        });
                      }

                      if (mounted) Navigator.pop(context);
                      await fetchUserData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Vui lòng nhập đầy đủ thông tin"),
                        ),
                      );
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void removeAddress(int index) {
    setState(() {
      addresses.removeAt(index);
    });
    // Chỉ đổi UI local như code gốc. Nếu muốn lưu lên Firestore ngay, có thể
    // gọi updateUserData() tại đây. (Không thay đổi logic theo yêu cầu.)
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;
    final horizontal = isWide ? size.width * 0.15 : 16.0;

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          user?['email'] ?? "",
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: fetchUserData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
          children: [
            _HeaderCard(
              imageUrl: imageUrl,
              displayName: (user?['displayName'] ?? '') as String,
              onEditAvatar: pickImage,
            ),
            const SizedBox(height: 16),

            // Thông tin cơ bản
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(title: "Thông tin cá nhân"),
                    const SizedBox(height: 12),
                    TextField(
                      controller: displayNameController,
                      decoration: _inputDecorationWithIcon(
                        label: "Tên hiển thị",
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecorationWithIcon(
                        label: "Số điện thoại",
                        icon: Icons.phone_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Địa chỉ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionTitle(title: "Địa chỉ nhận hàng"),
                ElevatedButton.icon(
                  onPressed: addAddressDialog,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text("Thêm địa chỉ"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(fontSize: 14),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (addresses.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.black54),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Chưa có địa chỉ nào",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _AddressTile(
                  address: addresses[index],
                  onDelete: () => removeAddress(index),
                ),
              ),

            const SizedBox(height: 24),

            // Lưu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : updateUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
                    : const Text("Lưu thay đổi"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // Style helpers
  // =========================
  static InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  InputDecoration _inputDecorationWithIcon({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primaryColor, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

// =========================
// Sub-widgets
// =========================

class _HeaderCard extends StatelessWidget {
  final String imageUrl;
  final String displayName;
  final VoidCallback onEditAvatar;

  const _HeaderCard({
    required this.imageUrl,
    required this.displayName,
    required this.onEditAvatar,
    super.key,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.take(1).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() +
        parts.last.characters.take(1).toString())
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, secondaryColor.withOpacity(.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white,
                  backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                  child: imageUrl.isEmpty
                      ? Text(
                    _initials(displayName.isEmpty ? "User" : displayName),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  )
                      : null,
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Material(
                  color: primaryColor,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEditAvatar,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              displayName.isEmpty ? "User" : displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: Colors.black,
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  final String address;
  final VoidCallback onDelete;
  const _AddressTile({
    required this.address,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: primaryColor),
        title: Text(
          address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
          tooltip: 'Xóa địa chỉ',
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
