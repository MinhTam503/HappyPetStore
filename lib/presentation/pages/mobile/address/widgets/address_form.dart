import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'searchable_dropdown_field.dart';

class AddressForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController detailController;
  final List<String> provinces;
  final Map<String, List<String>> wardsByProvince;
  final String? selectedProvince;
  final String? selectedWard;
  final bool isDefault;
  final LatLng? selectedLocation;
  final VoidCallback onPickLocation;
  final ValueChanged<String?> onProvinceChanged;
  final ValueChanged<String?> onWardChanged;
  final ValueChanged<bool?> onDefaultChanged;

  const AddressForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.detailController,
    required this.provinces,
    required this.wardsByProvince,
    required this.selectedProvince,
    required this.selectedWard,
    required this.isDefault,
    required this.selectedLocation,
    required this.onPickLocation,
    required this.onProvinceChanged,
    required this.onWardChanged,
    required this.onDefaultChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact info
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thông tin liên hệ',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên người nhận *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên người nhận'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Vui lòng nhập số điện thoại';
                      if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(v.trim()))
                        return 'Số điện thoại không hợp lệ';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Address fields
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Địa chỉ',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 16),
                  SearchableDropdownField(
                    labelText: 'Tỉnh/Thành phố *',
                    hintText: 'Nhập tên tỉnh/thành phố',
                    prefixIcon: Icons.location_city,
                    initialValue: selectedProvince,
                    items: provinces,
                    onChanged: onProvinceChanged,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Vui lòng chọn tỉnh/thành phố'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  SearchableDropdownField(
                    labelText: 'Phường/Xã *',
                    hintText: selectedProvince == null
                        ? 'Chọn tỉnh trước'
                        : 'Nhập tên phường/xã',
                    prefixIcon: Icons.location_on,
                    enabled: selectedProvince != null,
                    initialValue: selectedWard,
                    items: selectedProvince == null
                        ? const <String>[]
                        : (wardsByProvince[selectedProvince!] ??
                            const <String>[]),
                    onChanged: onWardChanged,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Vui lòng chọn phường/xã'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: detailController,
                    keyboardType: TextInputType.streetAddress,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    autocorrect: true,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ chi tiết *',
                      hintText: 'Số nhà, tên đường, khu vực...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.home),
                      alignLabelWithHint: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 200,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập địa chỉ chi tiết'
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Map + Default
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vị trí trên bản đồ',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedLocation != null
                              ? 'Vị trí: ${selectedLocation!.latitude.toStringAsFixed(6)}, ${selectedLocation!.longitude.toStringAsFixed(6)}'
                              : 'Chưa chọn vị trí trên bản đồ',
                          style: TextStyle(
                            color: selectedLocation != null
                                ? Colors.green[700]
                                : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onPickLocation,
                        icon: Icon(Icons.map, color: Theme.of(context).colorScheme.primary),
                        tooltip: 'Chọn vị trí trên bản đồ',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Đặt làm địa chỉ mặc định'),
                    subtitle: const Text(
                        'Địa chỉ này sẽ được chọn mặc định khi đặt hàng'),
                    value: isDefault,
                    onChanged: onDefaultChanged,
                    activeColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
