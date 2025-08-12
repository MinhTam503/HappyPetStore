import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPicker extends StatefulWidget {
  LatLng selected;
   MapPicker({super.key,required this.selected});

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late LatLng selected;
  GoogleMapController? mapController;
  @override
  void initState() {
    selected =widget.selected;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chọn vị trí cửa hàng")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: selected,
          zoom: 15,
        ),
        onMapCreated: (controller) {
          mapController = controller;
        },
        onTap: (LatLng position) {
          setState(() {
            selected = position;
          });
        },
        markers: {
          Marker(
            markerId: const MarkerId('selected'),
            position: selected,
          ),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context, selected);
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}
