import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/constants/vn_admin_units.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'widgets/address_form.dart';

class AddressEditPage extends StatefulWidget {
  final Map<String, dynamic>? address;
  final bool isEdit;

  const AddressEditPage({
    super.key,
    this.address,
    this.isEdit = false,
  });

  @override
  State<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends State<AddressEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailController = TextEditingController();

  String? selectedProvince;
  String? selectedWard;
  bool isDefault = false;
  LatLng? selectedLocation;
  MapController mapController = MapController();
  Location location = Location();
  bool _locationPermissionGranted = false;

  // Provinces and wards loaded from assets/vn_admin_units.json
  List<String> provinces = const [];
  Map<String, List<String>> wardsByProvince = const {};
  // Loading state is lightweight; we rely on setState to refresh dropdowns once loaded.

  @override
  void initState() {
    super.initState();
    _loadAdminUnits();
    _initializeLocation();
    if (widget.address != null) {
      _nameController.text = widget.address!['name'] ?? '';
      _phoneController.text = widget.address!['phone'] ?? '';
      isDefault = widget.address!['isDefault'] == true;

      // Parse existing coordinates if available
      if (widget.address!['latitude'] != null &&
          widget.address!['longitude'] != null) {
        selectedLocation = LatLng(
          widget.address!['latitude'].toDouble(),
          widget.address!['longitude'].toDouble(),
        );
      }

      // Prefer structured fields if available, else parse from combined address string
      final fullAddress = widget.address!['address'] ?? '';
      final province = widget.address!['province'] as String?;
      final ward = widget.address!['ward'] as String?;
      final detail = widget.address!['detail'] as String?;

      if ((province != null && province.isNotEmpty) || (ward != null && ward.isNotEmpty)) {
        selectedProvince = province;
        selectedWard = ward;
        _detailController.text = detail ?? '';
      } else {
        // Fallback parse from combined address
        _parseAddress(fullAddress);
      }
    }
  }

  Future<void> _loadAdminUnits() async {
    await VNAdminUnits.instance.load();
    setState(() {
      if (VNAdminUnits.instance.provinces.isNotEmpty) {
        provinces = VNAdminUnits.instance.provinces;
        wardsByProvince = VNAdminUnits.instance.wardsByProvince;
      }
    });
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    setState(() {
      _locationPermissionGranted = true;
    });

    // Get current location if no coordinates saved yet
    if (selectedLocation == null) {
      try {
        final locationData = await location.getLocation();
        setState(() {
          selectedLocation =
              LatLng(locationData.latitude!, locationData.longitude!);
        });
      } catch (e) {
        debugPrint('Error getting current location: $e');
        // Default to Ho Chi Minh City center if location fails
        setState(() {
          selectedLocation = const LatLng(10.762622, 106.660172);
        });
      }
    }
  }

  void _parseAddress(String fullAddress) {
    // Try to parse the address format: "detail, ward, province"
    final parts = fullAddress.split(', ');
    if (parts.length >= 3) {
      selectedProvince = parts.last.trim();
      // Back-compat: map legacy province labels (e.g., "Hồ Chí Minh")
      // to official labels in the dataset (e.g., "Thành phố Hồ Chí Minh").
      if (!provinces.contains(selectedProvince)) {
        final canonical = _canonicalProvinceName(selectedProvince!);
        if (provinces.contains(canonical)) {
          selectedProvince = canonical;
        }
      }
      selectedWard = parts[parts.length - 2].trim();
      _detailController.text =
          parts.sublist(0, parts.length - 2).join(', ').trim();

      // Validate if province and ward exist in our data
      if (!provinces.contains(selectedProvince)) {
        selectedProvince = null;
      }
      if (selectedProvince != null) {
        final wards = wardsByProvince[selectedProvince!] ?? const <String>[];
        // Try exact match first, then try case-insensitive match
        if (!wards.contains(selectedWard)) {
          final match = wards.firstWhere(
              (w) => w.toLowerCase() == (selectedWard ?? '').toLowerCase(),
              orElse: () => '');
          selectedWard = match.isNotEmpty ? match : null;
        }
      }
    } else {
      // If parsing fails, put everything in detail
      _detailController.text = fullAddress;
    }
  }

  String _canonicalProvinceName(String input) {
    final simple = input.replaceFirst(RegExp(r'^(Tỉnh|Thành phố)\s+'), '').trim();
    for (final p in provinces) {
      if (p == input) return p; // exact match
      final alias = p.replaceFirst(RegExp(r'^(Tỉnh|Thành phố)\s+'), '').trim();
      if (alias == input || alias == simple) {
        return p;
      }
    }
    return input;
  }

  Future<void> _showMapDialog() async {
    if (!_locationPermissionGranted) {
      NotificationHelper.showWarning(
        context,
        'Quyền truy cập vị trí',
        'Cần cấp quyền truy cập vị trí để sử dụng tính năng này.',
      );
      return;
    }

    LatLng tempLocation =
        selectedLocation ?? const LatLng(10.762622, 106.660172);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chọn vị trí trên bản đồ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: tempLocation,
                      initialZoom: 15.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (tapPosition, point) {
                        setDialogState(() {
                          tempLocation = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.pet_shop',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: tempLocation,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedLocation = tempLocation;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Xác nhận'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildFullAddress() {
    if (selectedProvince == null ||
        selectedWard == null ||
        _detailController.text.trim().isEmpty) {
      return '';
    }
    return '${_detailController.text.trim()}, $selectedWard, $selectedProvince';
  }

  void _saveAddress() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedProvince == null || selectedWard == null) {
      NotificationHelper.showWarning(
        context,
        'Thông tin chưa đầy đủ',
        'Vui lòng chọn tỉnh/thành phố và phường/xã',
      );
      return;
    }

    final result = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _buildFullAddress(),
      // keep structured fields for reliability
      'province': selectedProvince,
      'ward': selectedWard,
      'detail': _detailController.text.trim(),
      'isDefault': isDefault,
      'latitude': selectedLocation?.latitude,
      'longitude': selectedLocation?.longitude,
    };

    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isEdit ? 'Chỉnh sửa địa chỉ' : 'Thêm địa chỉ',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: const [],
      ),
      body: AddressForm(
        formKey: _formKey,
        nameController: _nameController,
        phoneController: _phoneController,
        detailController: _detailController,
        provinces: provinces,
        wardsByProvince: wardsByProvince,
        selectedProvince: selectedProvince,
        selectedWard: selectedWard,
        isDefault: isDefault,
        selectedLocation: selectedLocation,
        onPickLocation: _showMapDialog,
        onProvinceChanged: (value) => setState(() {
          selectedProvince = value;
          selectedWard = null;
        }),
        onWardChanged: (value) => setState(() {
          selectedWard = value;
        }),
        onDefaultChanged: (value) => setState(() {
          isDefault = value ?? false;
        }),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saveAddress,
              icon: const Icon(Icons.save),
              label: const Text(
                'Lưu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
