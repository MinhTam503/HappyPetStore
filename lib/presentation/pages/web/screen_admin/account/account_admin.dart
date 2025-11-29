import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';

import '../../components/empty_state.dart';
import 'components/account_card.dart';

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

  // Raw role values for database operations
  static const List<String> rawRoleValues = ['admin', 'user'];

  // UI states
  bool isLoading = false;
  int selectedRoleIndex = 0; // 0=All, 1=Admin, 2=User
  List<String> get roleChips => [
    AppLocalizations.of(context)!.all,
    AppLocalizations.of(context)!.admin,
    AppLocalizations.of(context)!.user
  ];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Image picking state
  Uint8List? _imageBytes;

  // ===== Storage =====
  Future<String> uploadImage(Uint8List imageBytes, String userId) async {
    try {
      // Detect image format from bytes
      String ext = 'jpg';
      if (imageBytes.length > 3) {
        // Check PNG signature
        if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50 && imageBytes[2] == 0x4E && imageBytes[3] == 0x47) {
          ext = 'png';
        }
        // Check JPEG signature
        else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
          ext = 'jpg';
        }
        // Check GIF signature
        else if (imageBytes[0] == 0x47 && imageBytes[1] == 0x49 && imageBytes[2] == 0x46) {
          ext = 'gif';
        }
        // Check WebP signature
        else if (imageBytes.length > 11 && 
                 imageBytes[8] == 0x57 && imageBytes[9] == 0x45 && 
                 imageBytes[10] == 0x42 && imageBytes[11] == 0x50) {
          ext = 'webp';
        }
      }

      final fileName = '$userId.$ext';
      String contentType = 'image/jpeg';
      if (ext == 'png')
        contentType = 'image/png';
      else if (ext == 'gif')
        contentType = 'image/gif';
      else if (ext == 'webp') 
        contentType = 'image/webp';

      final metadata = SettableMetadata(contentType: contentType);
      final storageRef =
          FirebaseStorage.instance.ref().child('profile_images/$fileName');
      final uploadTask = storageRef.putData(imageBytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return '';
    }
  }

  // ===== Delete old image =====
  Future<void> deleteOldImage(String imageUrl) async {
    try {
      if (imageUrl.isNotEmpty && imageUrl.contains('firebase') && imageUrl.contains('profile_images')) {
        final oldImageRef = FirebaseStorage.instance.refFromURL(imageUrl);
        await oldImageRef.delete();
      }
    } catch (e) {
      debugPrint('Error deleting old image: $e');
    }
  }

  // ===== Pick image =====
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _imageBytes = result.files.first.bytes;
      });
    }
  }

  void addAccount(Map<String, dynamic> account) async {
    try {
      setState(() => isLoading = true);
      
      // First add account to get the document ID
      final docRef = await accountsCollection.add(account);
      final userId = docRef.id;
      
      // Upload image if selected, using the generated userId
      String finalImageUrl = account['imageUrl'] ?? '';
      if (_imageBytes != null) {
        finalImageUrl = await uploadImage(_imageBytes!, userId);
        // Update the account with the new image URL
        await accountsCollection.doc(userId).update({'imageUrl': finalImageUrl});
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.accountAdded)));
      
      // Reset image after successful add
      setState(() {
        _imageBytes = null;
      });
    } catch (e) {
      debugPrint('Error adding account: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void updateAccount(String id, Map<String, dynamic> account) async {
    try {
      setState(() => isLoading = true);
      
      // Upload new image if selected
      String finalImageUrl = account['imageUrl'] ?? '';
      if (_imageBytes != null) {
        // Delete old image first
        final oldImageUrl = account['imageUrl'] ?? '';
        await deleteOldImage(oldImageUrl);
        
        // Upload new image using userId as filename
        finalImageUrl = await uploadImage(_imageBytes!, id);
        account['imageUrl'] = finalImageUrl;
      }
      
      await accountsCollection.doc(id).update(account);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.accountUpdated)));
      
      // Reset image after successful update
      setState(() {
        _imageBytes = null;
      });
    } catch (e) {
      debugPrint('Error updating account: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void deleteAccount(String id) async {
    try {
      setState(() => isLoading = true);
      await accountsCollection.doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.accountDeleted)));
    } catch (e) {
      debugPrint('Error deleting account: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  InputDecoration _input(String label, {Widget? prefix}) => InputDecoration(
        labelText: label,
        prefixIcon: prefix,
        border: const OutlineInputBorder(),
        focusedBorder:  OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context)
                                    .colorScheme.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(AppLocalizations.of(context)!.manageAccounts,
            style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < roleChips.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(roleChips[i]),
                          selected: selectedRoleIndex == i,
                          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(.15),
                          backgroundColor: Theme.of(context).chipTheme.backgroundColor,
                          labelStyle: TextStyle(
                            color: selectedRoleIndex == i
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          onSelected: (_) => setState(() => selectedRoleIndex = i),
                        ),
                      ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () => _showAccountDialog(null, null),
                      icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                      label: Text(AppLocalizations.of(context)!.createNew,
                          style: TextStyle(color: Theme.of(context).colorScheme.primary)),
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
                controller: _searchController,
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchByNameOrEmail,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot>(
              stream: accountsCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return EmptyState(
                      label: AppLocalizations.of(context)!.noAccountsAvailable,
                      icon: Icons.person_outline);
                }

                // Build list
                var docs = snapshot.data!.docs;
                // Client-side filter by role
                if (selectedRoleIndex != 0) { // 0 = All
                  String roleToFilter = rawRoleValues[selectedRoleIndex - 1];
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final role = (data['role'] ?? '').toString().toLowerCase();
                    return role == roleToFilter.toLowerCase();
                  }).toList();
                }
                // Search by name or email
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name =
                        (data['displayName'] ?? '').toString().toLowerCase();
                    final email =
                        (data['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return EmptyState(
                      label: AppLocalizations.of(context)!.noMatchingAccounts,
                      icon: Icons.search_off);
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        (constraints.maxWidth ~/ 360).clamp(1, 4);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 160, // Chiều cao item
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final id = doc.id;
                        final displayName =
                            (data['displayName'] ?? 'No Name').toString();
                        final email = (data['email'] ?? 'No Email').toString();
                        final phone = (data['phone'] ?? 'No Phone').toString();
                        final role = (data['role'] ?? 'user').toString();
                        final imageUrl = (data['imageUrl'] ?? '').toString();

                        return AccountCard(
                          name: displayName,
                          email: email,
                          phone: phone,
                          role: role,
                          imageUrl: imageUrl,
                          onEdit: () => _showAccountDialog(id, doc),
                          onDelete: () => _confirmDelete(id),
                          onTap: () => _showUserOrders(email, displayName),
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
              color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.processing, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
        ],
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   backgroundColor: primaryColor,
      //   onPressed: () => _showAccountDialog(null, null),
      //   icon: const Icon(Icons.add, color: Colors.white),
      //   label:
      //       const Text('Thêm tài khoản', style: TextStyle(color: Colors.white)),
      // ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirm),
        content: Text(AppLocalizations.of(context)!.confirmDeleteAccount),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (ok == true) deleteAccount(id);
  }

  void _showUserOrders(String email, String? userName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.ordersOf(userName ?? email),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          content: SizedBox(
            width: 720, // hoặc MediaQuery.of(context).size.width * 0.6
            height: 480, // quan trọng: CHIỀU CAO HỮU HẠN
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  ordersCollection.where('email', isEqualTo: email).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text(AppLocalizations.of(context)!.noOrdersFound));
                }

                final orders = snapshot.data!.docs;
                return ListView.separated(
                  // 3 dòng dưới giúp tránh cố đo kích thước vô hạn
                  shrinkWrap: true,
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(),

                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final order = orders[i];
                    final data = order.data() as Map<String, dynamic>;
                    final total = data['totalAmount']?.toString() ?? '0';
                    final status = data['statusOrder']?.toString() ?? 'unknown';
                    final createdAt = data['createdAt'];

                    return ListTile(
                      title: Text('Order ID: ${order.id}'),
                      subtitle: Text('Total: ${CurrencyHelper.formatVND(total)} • Status: $status'
                          '${createdAt != null ? ' • Date: $createdAt' : ''}'),
                      leading: const Icon(Icons.receipt_outlined),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.close),
            ),
          ],
        );
      },
    );
  }

  void _showAccountDialog(String? id, QueryDocumentSnapshot? account) {
    final nameController =
        TextEditingController(text: account?.get('displayName') ?? '');
    final emailController =
        TextEditingController(text: account?.get('email') ?? '');
    final phoneController =
        TextEditingController(text: account?.get('phone') ?? '');
    final roleController =
        TextEditingController(text: account?.get('role') ?? 'user');
    final imageUrlController =
        TextEditingController(text: account?.get('imageUrl') ?? '');

    // Reset image bytes when opening dialog for existing account
    if (account != null) {
      _imageBytes = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              title: Text(id == null ? AppLocalizations.of(context)!.addAccount : AppLocalizations.of(context)!.editAccount),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: _input(AppLocalizations.of(context)!.displayName,
                                      prefix: const Icon(Icons.badge_outlined)),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: emailController,
                                  decoration: _input(AppLocalizations.of(context)!.email,
                                      prefix:
                                          const Icon(Icons.alternate_email)),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: phoneController,
                                  decoration: _input(AppLocalizations.of(context)!.phone,
                                      prefix: const Icon(Icons.phone_outlined)),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: roleController.text.isNotEmpty
                                      ? roleController.text
                                      : 'user',
                                  decoration: _input(AppLocalizations.of(context)!.role,
                                      prefix: const Icon(
                                          Icons.lock_person_outlined)),
                                  items: rawRoleValues
                                      .map((rawRole) {
                                        // Map raw roles to localized display text
                                        String displayText = rawRole == 'admin' 
                                            ? AppLocalizations.of(context)!.admin
                                            : AppLocalizations.of(context)!.user;
                                        return DropdownMenuItem(
                                            value: rawRole, 
                                            child: Text(displayText));
                                      })
                                      .toList(),
                                  onChanged: (v) => setStateDialog(
                                      () => roleController.text = v ?? 'user'),
                                ),
                                const SizedBox(height: 16),
                                // Replace URL field with image picker button
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await _pickImage();
                                    setStateDialog(() {}); // Refresh preview
                                  },
                                  icon: const Icon(Icons.image),
                                  label: Text(_imageBytes != null 
                                      ? 'Image Selected' 
                                      : 'Select Image'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 180,
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(90),
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    color: secondaryColor,
                                    alignment: Alignment.center,
                                    child: _imageBytes != null
                                        ? Image.memory(
                                            _imageBytes!,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          )
                                        : (imageUrlController.text.isNotEmpty
                                            ? FittedBox(
                                                fit: BoxFit.cover,
                                                child: Image.network(
                                                    imageUrlController.text),
                                              )
                                            : const Icon(Icons.person_outline,
                                                size: 56)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(AppLocalizations.of(context)!.avatarPreview,
                                    style: TextStyle(
                                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.cancel)),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  onPressed: () {
                    final data = {
                      'displayName': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'role': roleController.text.trim().isEmpty
                          ? 'user'
                          : roleController.text.trim(),
                      'imageUrl': imageUrlController.text.trim(),
                    };
                    if (id == null) {
                      addAccount(data);
                    } else {
                      updateAccount(id, data);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child:
                      Text(AppLocalizations.of(context)!.save, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
