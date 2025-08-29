import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pet_shop/utils/contants.dart'; // dùng primaryColor, secondaryColor nếu có
import 'package:pet_shop/view/web/screen_admin/shop_info/MapPicker.dart';
import '../../../../auth/firestore_service.dart';

class ShopInfo extends StatefulWidget {
  const ShopInfo({super.key});

  @override
  State<ShopInfo> createState() => _ShopInfoState();
}

class _ShopInfoState extends State<ShopInfo> {
  Map<String, dynamic>? shopInfo;
  final _fService = Firestore_Service();

  // Map
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  LatLng? _center;

  // Form
  final nameController = TextEditingController();
  final aboutController = TextEditingController();
  final addressController = TextEditingController();

  // Upload
  Uint8List? _imageBytes;
  String? _filename;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchShopInfo();
  }

  @override
  void dispose() {
    nameController.dispose();
    aboutController.dispose();
    addressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  LatLng? _latLngFromUrl(String googleMapsUrl) {
    try {
      final uri = Uri.parse(googleMapsUrl);
      final q = uri.queryParameters['query'];
      if (q != null && q.contains(',')) {
        final parts = q.split(',');
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
    } catch (_) {}
    return null;
  }

  Future<void> fetchShopInfo() async {
    final data = await _fService.getShopInfo();
    if (!mounted) return;
    if (data == null) return;
    final pos = _latLngFromUrl(data['googleMapsUrl']) ??
        const LatLng(10.980712020778228, 106.6743278503418);
    setState(() {
      shopInfo = data;
      nameController.text = data['name'] ?? '';
      aboutController.text = data['about'] ?? '';
      addressController.text = data['address'] ?? '';
      _center = pos;
      _markers = {
        Marker(
          markerId: const MarkerId('selectedLocation'),
          position: pos,
          infoWindow: const InfoWindow(title: 'Vị trí cửa hàng'),
        )
      };
    });
  }

  void _onMapCreated(GoogleMapController c) => _mapController = c;

  Future<String> _uploadImage(
      Uint8List imageBytes,
      String fileName,
      String? oldImageShop,
      ) async {
    try {
      if (oldImageShop != null && oldImageShop.startsWith('http')) {
        try {
          await FirebaseStorage.instance.refFromURL(oldImageShop).delete();
        } catch (_) {
          // có thể ảnh cũ đã bị xóa/no-op
        }
      }
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final task = ref.putData(imageBytes);
      final snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return "";
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;
    setState(() => _imageBytes = result.files.first.bytes);
    final ext = result.files.first.extension ?? 'png';
    _filename = "avatarShop.$ext";

    if (_imageBytes != null && shopInfo != null) {
      final url = await _uploadImage(_imageBytes!, _filename!, shopInfo!['avatar']);
      if (url.isNotEmpty) {
        final cacheBust = "$url?ts=${DateTime.now().millisecondsSinceEpoch}";
        await _fService.updateAvatarShop(cacheBust);
        await fetchShopInfo();
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.avatarUpdatedSuccessfully)),
        );
      }
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? location = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPicker(
          selected: _center ??
              const LatLng(10.980712020778228, 106.6743278503418),
        ),
      ),
    );

    if (location == null) return;

    final googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}";
    await _fService.updateMapShopInfo(googleMapsUrl);

    setState(() {
      _center = location;
      _markers = {
        Marker(
          markerId: const MarkerId('selectedLocation'),
          position: location,
          infoWindow: const InfoWindow(title: 'Vị trí cửa hàng'),
        )
      };
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(location));
  }

  InputDecoration _dec(String label, {String? hint, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isReady = shopInfo != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shopInfo, style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).appBarTheme.foregroundColor,
        )),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: .5,
        iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: !isReady
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                // Header + avatar
                Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 72,
                              backgroundColor: secondaryColor,
                              backgroundImage: (shopInfo!['avatar'] != null && (shopInfo!['avatar'] as String).isNotEmpty)
                                  ? NetworkImage(shopInfo!['avatar'])
                                  : null,
                              child: (shopInfo!['avatar'] == null || (shopInfo!['avatar'] as String).isEmpty)
                                  ? const Icon(Icons.storefront, size: 48, color: primaryColor)
                                  : null,
                              onBackgroundImageError: (_, __) {},
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Material(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(24),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: _pickImage,
                                  child: const Padding(
                                    padding: EdgeInsets.all(10.0),
                                    child: Icon(Icons.edit, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Thông tin cửa hàng',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Form fields
                Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: nameController,
                                decoration: _dec('Shop Name', prefix: const Icon(Icons.store_mall_directory_outlined)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: addressController,
                                minLines: 1,
                                maxLines: 2,
                                decoration: _dec('Địa chỉ', prefix: const Icon(Icons.location_on_outlined)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: aboutController,
                                minLines: 4,
                                maxLines: 8,
                                decoration: _dec('Giới thiệu', prefix: const Icon(Icons.description_outlined)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Map picker
                Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children:  [
                            const Icon(Icons.map_outlined, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(l10n.shopLocation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 320,
                            width: double.infinity,
                            child: GoogleMap(
                              onMapCreated: _onMapCreated,
                              initialCameraPosition: CameraPosition(
                                target: _center ??
                                    const LatLng(10.980712020778228, 106.6743278503418),
                                zoom: 15,
                              ),
                              markers: _markers,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _pickLocation,
                            icon: const Icon(Icons.edit_location_alt_outlined),
                            label: Text(l10n.selectOnMap),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: const BorderSide(color: primaryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Save button
                Align(
                  alignment: Alignment.center,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                      setState(() => isLoading = true);
                      if (nameController.text.trim().isEmpty ||
                          addressController.text.trim().isEmpty ||
                          aboutController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.pleaseEnterAllInfo)),
                        );
                        setState(() => isLoading = false);
                        return;
                      }
                      await _fService.updateaInfoShop(
                        aboutController.text.trim(),
                        addressController.text.trim(),
                        nameController.text.trim(),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã cập nhật thành công')),
                      );
                      setState(() => isLoading = false);
                    },
                    icon: isLoading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.save_outlined, color: Colors.white),
                    label: Text(l10n.saveChanges, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
