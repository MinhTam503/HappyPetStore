import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPicker extends StatefulWidget {
  final LatLng selected;
  const MapPicker({super.key, required this.selected});

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late LatLng _selected;
  final MapController _mapController = MapController();
  double _zoom = 15;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  void dispose() {
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
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: _zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPosition, point) {
                setState(() => _selected = point);
                _mapController.move(point, _zoom);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.happypet.store',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                  ),
                ],
              ),
            ],
          ),
          // Hints
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Text(l10n.tapMapToSelectLocation, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.87))),
            ),
          ),
          // Simple zoom controls
          Positioned(
            right: 12,
            bottom: 90,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add,
                  onPressed: () {
                    setState(() => _zoom = (_zoom + 1).clamp(1, 19).toDouble());
                    _mapController.move(_selected, _zoom);
                  },
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  icon: Icons.remove,
                  onPressed: () {
                    setState(() => _zoom = (_zoom - 1).clamp(1, 19).toDouble());
                    _mapController.move(_selected, _zoom);
                  },
                ),
              ],
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

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _ZoomButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.87)),
        ),
      ),
    );
  }
}
