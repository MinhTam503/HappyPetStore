import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'address_edit_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/presentation/bloc/address/address_bloc.dart';
import 'package:pet_shop/presentation/bloc/address/address_event.dart';
import 'package:pet_shop/presentation/bloc/address/address_state.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';

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
  bool _hasCompletedInitialLoad = false; // to decide when to show global overlay
  bool _hasInteracted = false; // user performed an action (add/edit/delete/default)

  @override
  void initState() {
    super.initState();
    // Loading is triggered in BlocProvider via create() ..add(LoadAddresses())
  }

  // _loadAddresses removed; AddressBloc handles loading and migration.

  Future<void> _setDefaultAddress(BuildContext ctx, int index) async {
    try {
      _hasInteracted = true;
      ctx.read<AddressBloc>().add(SetDefaultAddress(index));
    } catch (e) {
      NotificationHelper.showError(ctx, 'Lỗi', 'Không thể cập nhật địa chỉ mặc định: $e');
    }
  }

  Future<void> _deleteAddress(BuildContext ctx, int index) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
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
    if (!mounted) return;

    try {
      _hasInteracted = true;
      ctx.read<AddressBloc>().add(DeleteAddress(index));
    } catch (e) {
      NotificationHelper.showError(ctx, 'Lỗi', 'Không thể xóa địa chỉ: $e');
    }
  }

  void _navigateToEdit(BuildContext ctx, [Map<String, dynamic>? address, int? index]) async {
    _hasInteracted = true;
    final result = await Navigator.push<Map<String, dynamic>>(
      ctx,
      MaterialPageRoute(
        builder: (context) => AddressEditPage(
          address: address,
          isEdit: address != null,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      ctx.read<AddressBloc>().add(AddOrUpdateAddress(address: result, index: index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddressBloc()..add(LoadAddresses()),
      child: BlocConsumer<AddressBloc, AddressState>(
        listener: (context, state) {
          // Mark initial load done when we first see isLoading == false
          if (!state.isLoading && !_hasCompletedInitialLoad) {
            _hasCompletedInitialLoad = true;
          }
          // Show overlay for operations after initial load or after any user interaction
          if (state.isLoading && (_hasCompletedInitialLoad || _hasInteracted)) {
            DialogHelper.showLoadingDialog(context, message: 'Đang xử lý...');
          } else if (!state.isLoading) {
            DialogHelper.safeHideLoadingDialog();
          }

          if (state.infoMessage != null && state.infoMessage!.isNotEmpty) {
            NotificationHelper.showSuccess(context, 'Thành công', state.infoMessage!);
          }
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            NotificationHelper.showError(context, 'Lỗi', state.errorMessage!);
          }
          addresses = state.addresses;
          isLoading = state.isLoading;
        },
        builder: (context, state) {
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
            onPressed: () => _navigateToEdit(context),
          ),
        ],
      ),
  body: state.isLoading && state.addresses.isEmpty && !_hasCompletedInitialLoad
      ? const Center(child: CircularProgressIndicator())
      : state.addresses.isEmpty
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
                        onPressed: () => _navigateToEdit(context),
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
                  itemCount: state.addresses.length,
                  itemBuilder: (context, index) {
                    final address = state.addresses[index];
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
                                      onPressed: () => _setDefaultAddress(context, index),
                                      child: const Text('Đặt mặc định'),
                                    ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _navigateToEdit(context, address, index),
                                    child: const Text('Sửa'),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteAddress(context, index),
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
        },
      ),
    );
  }
}