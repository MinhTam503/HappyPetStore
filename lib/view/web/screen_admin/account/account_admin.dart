import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/utils/contants.dart';

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

  // UI states
  bool isLoading = false;
  String _roleFilter = 'All';
  final List<String> roleChips = const ['All', 'admin', 'user'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void addAccount(Map<String, dynamic> account) async {
    try {
      setState(() => isLoading = true);
      await accountsCollection.add(account);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Account added')));
    } catch (e) {
      debugPrint('Error adding account: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void updateAccount(String id, Map<String, dynamic> account) async {
    try {
      setState(() => isLoading = true);
      await accountsCollection.doc(id).update(account);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Account updated')));
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
          .showSnackBar(const SnackBar(content: Text('Account deleted')));
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
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Quản lý tài khoản',
            style: TextStyle(color: Colors.black)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final r in roleChips)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(r),
                          selected: _roleFilter == r,
                          selectedColor: primaryColor.withOpacity(.15),
                          labelStyle: TextStyle(
                            color: _roleFilter == r
                                ? primaryColor
                                : Colors.black87,
                          ),
                          onSelected: (_) => setState(() => _roleFilter = r),
                        ),
                      ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.white),
                      onPressed: () => _showAccountDialog(null, null),
                      icon: const Icon(Icons.add, color: primaryColor),
                      label: const Text('Create New',
                          style: TextStyle(color: primaryColor)),
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
                  hintText: 'Tìm theo tên hoặc email...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: secondaryColor,
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
                  return const EmptyState(
                      label: 'No accounts available',
                      icon: Icons.person_outline);
                }

                // Build list
                var docs = snapshot.data!.docs;
                // Client-side filter by role
                if (_roleFilter != 'All') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final role = (data['role'] ?? '').toString().toLowerCase();
                    return role == _roleFilter.toLowerCase();
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
                  return const EmptyState(
                      label: 'Không có tài khoản phù hợp',
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
              color: Colors.black38,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 8),
                  Text('Đang xử lý...', style: TextStyle(color: Colors.white)),
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
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc chắn muốn xóa tài khoản này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red))),
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
          title: Text('Orders of ${userName ?? email}',
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
                  return const Center(child: Text('No orders found'));
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
                      subtitle: Text('Total: \$${total} • Status: $status'
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
              child: const Text('Close'),
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              title: Text(id == null ? 'Add Account' : 'Edit Account'),
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
                                  decoration: _input('Display Name',
                                      prefix: const Icon(Icons.badge_outlined)),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: emailController,
                                  decoration: _input('Email',
                                      prefix:
                                          const Icon(Icons.alternate_email)),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: phoneController,
                                  decoration: _input('Phone',
                                      prefix: const Icon(Icons.phone_outlined)),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: roleController.text.isNotEmpty
                                      ? roleController.text
                                      : 'user',
                                  decoration: _input('Role',
                                      prefix: const Icon(
                                          Icons.lock_person_outlined)),
                                  items: const ['admin', 'user']
                                      .map((e) => DropdownMenuItem(
                                          value: e, child: Text(e)))
                                      .toList(),
                                  onChanged: (v) => setStateDialog(
                                      () => roleController.text = v ?? 'user'),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: imageUrlController,
                                  decoration: _input('Image URL',
                                      prefix: const Icon(Icons.link_outlined)),
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
                                    child: imageUrlController.text.isNotEmpty
                                        ? FittedBox(
                                            fit: BoxFit.contain,
                                            child: Image.network(
                                                imageUrlController.text),
                                          )
                                        : const Icon(Icons.person_outline,
                                            size: 56),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text('Avatar preview',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54)),
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
                    child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
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
                      const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
