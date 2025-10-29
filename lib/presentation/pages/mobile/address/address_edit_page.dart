import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/constants/list_city.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';

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
  String? selectedDistrict;
  bool isDefault = false;
  LatLng? selectedLocation;
  MapController mapController = MapController();
  Location location = Location();
  bool _locationPermissionGranted = false;

  List<String> provinces = ListCity().city;
  Map<String, List<String>> districts = ListCity().districts;

  @override
  void initState() {
    super.initState();
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

      // Parse address to extract province, district, and detail
      final fullAddress = widget.address!['address'] ?? '';
      _parseAddress(fullAddress);
    }
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
        print('Error getting current location: $e');
        // Default to Ho Chi Minh City center if location fails
        setState(() {
          selectedLocation = const LatLng(10.762622, 106.660172);
        });
      }
    }
  }

  void _parseAddress(String fullAddress) {
    // Try to parse the address format: "detail, district, province"
    final parts = fullAddress.split(', ');
    if (parts.length >= 3) {
      selectedProvince = parts.last.trim();
      selectedDistrict = parts[parts.length - 2].trim();
      _detailController.text =
          parts.sublist(0, parts.length - 2).join(', ').trim();

      // Validate if province and district exist in our data
      if (!provinces.contains(selectedProvince)) {
        selectedProvince = null;
      }
      if (selectedProvince != null &&
          (districts[selectedProvince!] == null ||
              !districts[selectedProvince!]!.contains(selectedDistrict))) {
        selectedDistrict = null;
      }
    } else {
      // If parsing fails, put everything in detail
      _detailController.text = fullAddress;
    }
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
                          backgroundColor: primaryColor,
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
        selectedDistrict == null ||
        _detailController.text.trim().isEmpty) {
      return '';
    }
    return '${_detailController.text.trim()}, $selectedDistrict, $selectedProvince';
  }

  void _saveAddress() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedProvince == null || selectedDistrict == null) {
      NotificationHelper.showWarning(
        context,
        'Thông tin chưa đầy đủ',
        'Vui lòng chọn tỉnh/thành phố và quận/huyện',
      );
      return;
    }

    final result = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _buildFullAddress(),
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
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
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
        actions: [
          TextButton(
            onPressed: _saveAddress,
            child: const Text(
              'Lưu',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name field
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin liên hệ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên người nhận *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên người nhận';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập số điện thoại';
                        }
                        // Basic phone validation
                        if (!RegExp(r'^[0-9+\-\s()]+$')
                            .hasMatch(value.trim())) {
                          return 'Số điện thoại không hợp lệ';
                        }
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Địa chỉ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Tỉnh/Thành phố *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      value: selectedProvince,
                      items: provinces
                          .map((province) => DropdownMenuItem(
                                value: province,
                                child: Text(province),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedProvince = value;
                          selectedDistrict =
                              null; // Reset district when province changes
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng chọn tỉnh/thành phố';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Quận/Huyện *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      value: selectedDistrict,
                      items: (selectedProvince != null &&
                              districts[selectedProvince!] != null)
                          ? districts[selectedProvince!]!
                              .map((district) => DropdownMenuItem(
                                    value: district,
                                    child: Text(district),
                                  ))
                              .toList()
                          : [],
                      onChanged: (value) {
                        setState(() {
                          selectedDistrict = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng chọn quận/huyện';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _detailController,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ chi tiết *',
                        hintText: 'Số nhà, tên đường, khu vực...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập địa chỉ chi tiết';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Map location selection card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vị trí trên bản đồ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
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
                          onPressed: _showMapDialog,
                          icon: const Icon(Icons.map, color: primaryColor),
                          tooltip: 'Chọn vị trí trên bản đồ',
                        ),
                      ],
                    ),
                    if (selectedLocation != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 16, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Vị trí đã được chọn',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Default address option
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: CheckboxListTile(
                title: const Text('Đặt làm địa chỉ mặc định'),
                subtitle: const Text(
                    'Địa chỉ này sẽ được chọn mặc định khi đặt hàng'),
                value: isDefault,
                onChanged: (value) {
                  setState(() {
                    isDefault = value ?? false;
                  });
                },
                activeColor: primaryColor,
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.isEdit ? 'Cập nhật địa chỉ' : 'Thêm địa chỉ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
