import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectShopLocation(_fmt(_selected)), style: TextStyle(
          color: Theme.of(context).appBarTheme.foregroundColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        )),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: .5,
        iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
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
              child: Text(l10n.tapMapToSelectLocation, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(context, _selected),
          icon: const Icon(Icons.check, color: Colors.white),
          label: Text(l10n.confirmLocation, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
