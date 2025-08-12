import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pet_shop/view/web/screen_admin/MapPicker.dart';
import '../../../auth/firestore_service.dart';

class ShopInfo extends StatefulWidget {
  const ShopInfo({super.key});

  @override
  State<ShopInfo> createState() => _ShopInfoState();
}

class _ShopInfoState extends State<ShopInfo> {
  Map<String, dynamic>? shopInfo;
  Set<Marker> _markers = {};
  late GoogleMapController mapController;
  LatLng? _center;

  TextEditingController nameController = TextEditingController();
  TextEditingController aboutController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  String? address;
  bool isLoading = false;

  final _fService = Firestore_Service();

  Uint8List? _imageBytes;
  String? _filename;

  @override
  void initState() {
    fetchShopInfo();
    super.initState();
  }

  LatLng? convertToLatLng(String googleMapsUrl) {
    final uri = Uri.parse(googleMapsUrl);
    final queryParams = uri.queryParameters;
    final coordinates = queryParams['query']?.split(',');

    if (coordinates != null && coordinates.length == 2) {
      final lat = double.tryParse(coordinates[0]);
      final lng = double.tryParse(coordinates[1]);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    return null;
  }

  Future<void> fetchShopInfo() async {
    final shopData = await _fService.getShopInfo();
    if (shopData != null) {
      final LatLng location = convertToLatLng(shopData['googleMapsUrl']) ??
          const LatLng(10.980712020778228, 106.6743278503418);
      setState(() {
        shopInfo = shopData;
        nameController.text = shopInfo!['name'];
        aboutController.text = shopInfo!['about'];
        addressController.text = shopInfo!['address'];
        address = shopData['googleMapsUrl'];
        _center = location;
        _markers.add(Marker(
          markerId: const MarkerId('selectedLocation'),
          position: location,
          infoWindow: const InfoWindow(title: 'Vị trí cửa hàng'),
        ));
      });
    }
  }

  void _selectedLocation() async {
    final LatLng? location = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPicker(
          selected:
              _center ?? const LatLng(10.980712020778228, 106.6743278503418),
        ),
      ),
    );

    if (location != null) {
      print("Vị trí đã chọn: ${location.latitude}, ${location.longitude}");
      String googleMapsUrl =
          "https://www.google.com/maps/search/?api=1&query=${location.latitude}, ${location.longitude}";
      _fService.updateMapShopInfo(googleMapsUrl);
      setState(() {
        _center = location;
        _markers.add(Marker(
          markerId: const MarkerId('selectedLocation'),
          position: location,
          infoWindow: const InfoWindow(title: 'Vị trí cửa hàng'),
        ));
      });
      mapController.animateCamera(
        CameraUpdate.newLatLng(location),
      );
    }
  }

  @override
  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<String> uploadImage(
      Uint8List imageBytes, String fileName, String oldImageShop) async {
    try {
      await FirebaseStorage.instance.refFromURL(oldImageShop).delete();
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putData(imageBytes);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print(e.toString());
      return "";
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        String? extension = result.files.first.extension;

        _filename = "avatarShop.${extension ?? 'png'}";

        print("✅ Image picked: ${_imageBytes!.length} bytes, File: $_filename");
      });

      String newAvatarUrl =
          await uploadImage(_imageBytes!, _filename!, shopInfo!['avatar']);
      String finalAvatarUrl =
          "$newAvatarUrl?timestamp=${DateTime.now().millisecondsSinceEpoch}";
      await _fService.updateAvatarShop(finalAvatarUrl);

      await fetchShopInfo();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avatar updated successfully!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Shop Info",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: shopInfo == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 250, right: 250, bottom: 50, top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 75,
                              backgroundImage:
                                  NetworkImage(shopInfo!['avatar']),
                              onBackgroundImageError: (_, __) =>
                                  const Icon(Icons.error),
                            ),
                            Positioned(
                              top: 10,
                              right: 5,
                              child: GestureDetector(
                                onTap: () {
                                  _pickImage();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      width: 1,
                                      color: Colors.blue,
                                    ),
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 25,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Expanded(
                            child: TextField(
                              controller: nameController,
                              maxLines: null,
                              decoration: const InputDecoration(
                                  labelText: "Shop Name",
                                  labelStyle: TextStyle(fontSize: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Colors.blue, width: 2))),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: TextField(
                            controller: addressController,
                            maxLines: null,
                            decoration: const InputDecoration(
                                labelText: "Địa chỉ",
                                labelStyle: TextStyle(fontSize: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.blue, width: 2))),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      const Text(
                        "Vị trí",
                        style: TextStyle(
                            fontSize: 25, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 50.0),
                        child: Row(
                          children: [
                            Container(
                              height: 300,
                              width: 700,
                              child: GoogleMap(
                                onMapCreated: onMapCreated,
                                initialCameraPosition: CameraPosition(
                                  target: _center ??
                                      const LatLng(10.980712020778228,
                                          106.6743278503418),
                                  zoom: 15,
                                ),
                                markers: _markers,
                                onTap:
                                    null, // Khi nhấn vào bản đồ, sẽ thêm marker
                              ),
                            ),
                            const SizedBox(
                              width: 20,
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _selectedLocation();
                              },
                              child: const Icon(
                                Icons.edit,
                                size: 30,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: TextField(
                            controller: aboutController,
                            maxLines: null,
                            decoration: const InputDecoration(
                                labelText: "Giới thiệu",
                                labelStyle: TextStyle(fontSize: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.blue, width: 2))),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      GestureDetector(
                        onTap: () async {
                          setState(() {
                            isLoading = true;
                          });
                          if (aboutController.text.isNotEmpty &&
                              addressController.text.isNotEmpty &&
                              nameController.text.isNotEmpty) {
                            await _fService.updateaInfoShop(
                                aboutController.text,
                                addressController.text,
                                nameController.text);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Đã cập nhật thành công"),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Vui lòng nhập đầy đủ thông tin"),
                              ),
                            );
                          }
                          setState(() {
                            isLoading = false;
                          });
                        },
                        child: Center(
                            child: Container(
                          width: 150,
                          height: 50,
                          decoration: BoxDecoration(
                            border: Border.all(
                                width: 2, color: Colors.pink.shade100),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.blue,
                          ),
                          child: !isLoading
                              ? const Center(
                                  child: Text(
                                  "Save",
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                ))
                              : const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        )),
                      )
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
