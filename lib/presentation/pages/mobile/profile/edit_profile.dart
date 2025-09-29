import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/constants/list_city.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:intl/intl.dart';



class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  Map<String, dynamic>? user;
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String? userIdentifier;
  String imageUrl = "";
  List<Map<String, dynamic>> deliveryInfos = [];
  DateTime? selectedBirthDate;
  String? selectedGender;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  void _initializeUser() async {
    UserManager userManager = UserManager();
    userIdentifier = await userManager.getUserIdentifier();
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
        emailController.text = user?['email'] ?? authUser.email ?? "";
        
        // Parse delivery infos
        var deliveryData = user?['deliveryInfos'];
        if (deliveryData is List) {
          deliveryInfos = List<Map<String, dynamic>>.from(deliveryData);
        } else {
          // Migrate old address format to new delivery info format
          var oldAddresses = user?['address'];
          if (oldAddresses is List) {
            deliveryInfos = oldAddresses.map<Map<String, dynamic>>((addr) => {
              'name': user?['displayName'] ?? '',
              'phone': user?['phone'] ?? '',
              'address': addr.toString(),
              'isDefault': deliveryInfos.isEmpty,
            }).toList();
          }
        }
        
        // Parse birth date
        if (user?['birthDate'] != null) {
          if (user!['birthDate'] is Timestamp) {
            selectedBirthDate = (user!['birthDate'] as Timestamp).toDate();
          } else if (user!['birthDate'] is String) {
            try {
              selectedBirthDate = DateTime.parse(user!['birthDate']);
            } catch (e) {
              print('Error parsing birth date: $e');
            }
          }
        }
        
        selectedGender = user?['gender'];
        imageUrl = user?['imageUrl'] ?? "";
      });
    }
  }

  Future<void> updateUserData() async {
    User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    setState(() => _isSaving = true);
    try {
      Map<String, dynamic> updateData = {
        'displayName': displayNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'deliveryInfos': deliveryInfos,
        'imageUrl': imageUrl,
        'gender': selectedGender,
      };
      
      if (selectedBirthDate != null) {
        updateData['birthDate'] = Timestamp.fromDate(selectedBirthDate!);
      }
      
      // Only update email if it's different and not empty
      String newEmail = emailController.text.trim();
      if (newEmail.isNotEmpty && newEmail != authUser.email) {
        // Verify email before updating
        await _verifyAndUpdateEmail(newEmail);
      }
      
      await FirebaseFirestore.instance.collection("users").doc(authUser.uid).update(updateData);
      
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

  Future<void> _verifyAndUpdateEmail(String newEmail) async {
    User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    try {
      // Send verification email to new address
      await authUser.verifyBeforeUpdateEmail(newEmail);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent to $newEmail. Please verify before the email is updated.'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating email: $e')),
        );
      }
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
  // Date Picker
  // =========================
  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedBirthDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null && picked != selectedBirthDate) {
      setState(() {
        selectedBirthDate = picked;
      });
    }
  }

  // =========================
  // Delivery Info Management
  // =========================
  Future<void> addDeliveryInfoDialog() async {
    List<String> provinces = ListCity().city;
    Map<String, List<String>> districts = ListCity().districts;
    String? selectedProvince;
    String? selectedDistrict;
    String detail = '';
    String name = displayNameController.text;
    String phone = phoneController.text;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Thêm thông tin giao hàng'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: _inputDecoration("Tên người nhận"),
                      onChanged: (value) => name = value,
                      controller: TextEditingController(text: name),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: _inputDecoration("Số điện thoại"),
                      onChanged: (value) => phone = value,
                      controller: TextEditingController(text: phone),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
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
                        'Địa chỉ chi tiết (số nhà, tên đường...)',
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
                        name.trim().isNotEmpty &&
                        phone.trim().isNotEmpty &&
                        userIdentifier != null) {
                      final newAddress = '$detail, $selectedDistrict, $selectedProvince';
                      final newDeliveryInfo = {
                        'name': name.trim(),
                        'phone': phone.trim(),
                        'address': newAddress,
                        'isDefault': deliveryInfos.isEmpty, // First one is default
                      };

                      setState(() {
                        deliveryInfos.add(newDeliveryInfo);
                      });

                      if (mounted) Navigator.pop(context);
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

  void removeDeliveryInfo(int index) {
    setState(() {
      bool wasDefault = deliveryInfos[index]['isDefault'] == true;
      deliveryInfos.removeAt(index);
      
      // If removed item was default, make first item default
      if (wasDefault && deliveryInfos.isNotEmpty) {
        deliveryInfos[0]['isDefault'] = true;
      }
    });
  }

  void setDefaultDeliveryInfo(int index) {
    setState(() {
      for (int i = 0; i < deliveryInfos.length; i++) {
        deliveryInfos[i]['isDefault'] = i == index;
      }
    });
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
                    const _SectionTitle(title: "Thông tin cá nhân"),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false, // Email không thể chỉnh sửa trực tiếp
                      decoration: _inputDecorationWithIcon(
                        label: "Email (liên hệ admin để thay đổi)",
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Birth Date
                    InkWell(
                      onTap: _selectBirthDate,
                      child: InputDecorator(
                        decoration: _inputDecorationWithIcon(
                          label: "Ngày sinh",
                          icon: Icons.cake_outlined,
                        ),
                        child: Text(
                          selectedBirthDate != null 
                              ? DateFormat('dd/MM/yyyy').format(selectedBirthDate!)
                              : 'Chưa chọn ngày sinh',
                          style: TextStyle(
                            color: selectedBirthDate != null ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Gender
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: _inputDecorationWithIcon(
                        label: "Giới tính",
                        icon: Icons.person_outline,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Nam')),
                        DropdownMenuItem(value: 'female', child: Text('Nữ')),
                        DropdownMenuItem(value: 'other', child: Text('Khác')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Thông tin giao hàng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle(title: "Thông tin giao hàng"),
                ElevatedButton.icon(
                  onPressed: addDeliveryInfoDialog,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text("Chỉnh sửa"),
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

            if (deliveryInfos.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.black54),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Chưa có thông tin giao hàng nào",
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
                itemCount: deliveryInfos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _DeliveryInfoTile(
                  deliveryInfo: deliveryInfos[index],
                  onDelete: () => removeDeliveryInfo(index),
                  onSetDefault: () => setDefaultDeliveryInfo(index),
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
  const _SectionTitle({required this.title});

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

class _DeliveryInfoTile extends StatelessWidget {
  final Map<String, dynamic> deliveryInfo;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;
  
  const _DeliveryInfoTile({
    required this.deliveryInfo,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final isDefault = deliveryInfo['isDefault'] == true;
    
    return Card(
      elevation: isDefault ? 3 : 1.5,
      color: isDefault ? primaryColor.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Mặc định',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                if (!isDefault)
                  TextButton(
                    onPressed: onSetDefault,
                    child: const Text('Đặt làm mặc định'),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Xóa thông tin giao hàng',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  deliveryInfo['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(deliveryInfo['phone'] ?? ''),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deliveryInfo['address'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
