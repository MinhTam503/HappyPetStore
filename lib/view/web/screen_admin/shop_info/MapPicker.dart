import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pet_shop/utils/contants.dart';

class MapPicker extends StatefulWidget {
  final LatLng selected;
  const MapPicker({super.key, required this.selected});

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late LatLng _selected;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(LatLng p) => '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chọn vị trí cửa hàng • ${_fmt(_selected)}'),
        backgroundColor: Colors.white,
        elevation: .5,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selected, zoom: 15),
            onMapCreated: (c) => _controller = c,
            onTap: (LatLng p) {
              setState(() => _selected = p);
              _controller?.animateCamera(CameraUpdate.newLatLng(p));
            },
            markers: {
              Marker(markerId: const MarkerId('selected'), position: _selected),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),
          // Hints
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: const Text('Chạm lên bản đồ để chọn vị trí', style: TextStyle(fontSize: 12, color: Colors.black87)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(context, _selected),
          icon: const Icon(Icons.check, color: Colors.white),
          label: const Text('Xác nhận vị trí', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
