import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import 'package:pet_shop/services/shipping_service.dart';

/// 📱 Tracking Widget - Hiển thị thông tin theo dõi đơn hàng
class ShippingTrackingWidget extends StatefulWidget {
  final String trackingNumber;
  final bool isAdminView; // Admin có thể update status
  
  const ShippingTrackingWidget({
    super.key,
    required this.trackingNumber,
    this.isAdminView = false,
  });

  @override
  State<ShippingTrackingWidget> createState() => _ShippingTrackingWidgetState();
}

class _ShippingTrackingWidgetState extends State<ShippingTrackingWidget> {
  Map<String, dynamic>? _trackingData;
  bool _isLoading = true;
  String? _error;
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>?>? _sub;
  final MapController _mapController = MapController();

  // Routing state
  List<LatLng>? _routePoints; // Real route polyline (if fetched)
  bool _routeLoading = false;
  String? _routeError;
  LatLng? _lastRouteOrigin;
  LatLng? _lastRouteDest;

  @override
  void initState() {
    super.initState();
    _loadTrackingData();
    _subscribeRealtime();
  }

  Future<void> _loadTrackingData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ShippingService.trackShipment(widget.trackingNumber);
      
      if (result['success']) {
        setState(() {
          _trackingData = result['data'];
          _isLoading = false;
        });

        // Attempt to fetch real driving route (OSRM) when positions available
        final origin = _trackingData!['origin'];
        final dest = _trackingData!['destination'];
        if (origin is Map && dest is Map &&
            origin['lat'] != null && origin['lng'] != null &&
            dest['lat'] != null && dest['lng'] != null) {
          final o = LatLng((origin['lat'] as num).toDouble(), (origin['lng'] as num).toDouble());
          final d = LatLng((dest['lat'] as num).toDouble(), (dest['lng'] as num).toDouble());
          _maybeLoadRoute(o, d);
        }
      } else {
        setState(() {
          _error = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Không thể tải thông tin tracking';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _subscribeRealtime() {
    // Lắng nghe realtime thay đổi từ Firestore
    _sub = ShippingService.watchShipment(widget.trackingNumber).listen((data) {
      if (!mounted) return;
      if (data == null) return; // keep previous if no data
      setState(() {
        _trackingData = data;
        _isLoading = false;
        _error = null;
      });

      // Khi có dữ liệu vị trí thì thử lấy lộ trình thực tế
      final origin = data['origin'];
      final dest = data['destination'];
      if (origin is Map && dest is Map &&
          origin['lat'] != null && origin['lng'] != null &&
          dest['lat'] != null && dest['lng'] != null) {
        final o = LatLng((origin['lat'] as num).toDouble(), (origin['lng'] as num).toDouble());
        final d = LatLng((dest['lat'] as num).toDouble(), (dest['lng'] as num).toDouble());
        _maybeLoadRoute(o, d);
      }
    });
  }

  Future<void> _maybeLoadRoute(LatLng origin, LatLng dest) async {
    // Avoid re-fetching same route
    if (_lastRouteOrigin == origin && _lastRouteDest == dest && _routePoints != null) return;
    _lastRouteOrigin = origin;
    _lastRouteDest = dest;
    setState(() {
      _routeLoading = true;
      _routeError = null;
      _routePoints = null;
    });

    try {
      // OSRM demo server: lon,lat;lon,lat
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = convert.jsonDecode(resp.body) as Map<String, dynamic>;
        if ((data['routes'] as List).isNotEmpty) {
          final geometry = (data['routes'][0]['geometry'] as Map<String, dynamic>);
          final coords = (geometry['coordinates'] as List);
          final pts = <LatLng>[];
          for (final c in coords) {
            if (c is List && c.length >= 2) {
              final lon = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              pts.add(LatLng(lat, lon));
            }
          }
          if (pts.length >= 2) {
            setState(() {
              _routePoints = pts;
              _routeLoading = false;
            });
            return;
          }
        }
      }
      setState(() {
        _routeLoading = false;
        _routeError = 'Không lấy được lộ trình thực tế, dùng đường thẳng tạm.';
      });
    } catch (e) {
      setState(() {
        _routeLoading = false;
        _routeError = 'Lỗi tải lộ trình: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadTrackingData,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildShippingInfo(),
              const SizedBox(height: 12),
              _buildRouteMapOrPlaceholder(),
              const SizedBox(height: 16),
              _buildTrackingHistory(),
              if (widget.isAdminView) ...[
                const SizedBox(height: 16),
                _buildAdminActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final status = _trackingData!['status'] as String;
    final statusColor = Color(int.parse(ShippingService.getStatusColor(status).substring(1), radix: 16) + 0xFF000000);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Text(
            ShippingService.getStatusText(status),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: _loadTrackingData,
          icon: const Icon(Icons.refresh),
          tooltip: 'Cập nhật thông tin',
        ),
      ],
    );
  }

  Widget _buildRouteMapOrPlaceholder() {
    final origin = _trackingData!['origin'];
    final dest = _trackingData!['destination'];
    if (origin is Map && dest is Map &&
        origin['lat'] != null && origin['lng'] != null &&
        dest['lat'] != null && dest['lng'] != null) {
      return _buildRouteMap(
        LatLng((origin['lat'] as num).toDouble(), (origin['lng'] as num).toDouble()),
        LatLng((dest['lat'] as num).toDouble(), (dest['lng'] as num).toDouble()),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: Text(
            'Bản đồ sẽ hiển thị khi có thông tin vị trí',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteMap(LatLng origin, LatLng dest) {
    // Setup periodic timer to update truck position
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Use real route when available; otherwise a simple straight polyline
    final points = (_routePoints != null && _routePoints!.length >= 2)
        ? _routePoints!
        : [origin, dest];
    final bounds = LatLngBounds.fromPoints([origin, dest]);

    // Decide truck position by shipping status first, then fallback to time interpolation
    LatLng truckPos = origin;
    final status = (_trackingData!['status'] ?? '').toString();
    if (status == 'pickup_pending') {
      truckPos = origin;
    } else if (status == 'out_for_delivery' || status == 'delivered') {
      // Đang giao hàng hoặc đã giao -> xe ở vị trí khách hàng (đích)
      truckPos = dest;
    } else {
      // Compute current truck position proportionally to time between createdAt and estimatedDelivery
      final createdAtIso = _trackingData!['createdAt'] as String?;
      final estimatedIso = _trackingData!['estimatedDelivery'] as String?;
      if (createdAtIso != null && estimatedIso != null) {
        try {
          final start = DateTime.parse(createdAtIso);
          final eta = DateTime.parse(estimatedIso);
          final now = DateTime.now();
          double frac;
          if (now.isAfter(eta)) {
            frac = 1.0;
          } else if (now.isBefore(start)) {
            frac = 0.0;
          } else {
            final total = eta.difference(start).inSeconds;
            final passed = now.difference(start).inSeconds;
            frac = total > 0 ? (passed / total).clamp(0.0, 1.0) : 0.0;
          }
          truckPos = _interpolateAlongPath(points, frac);
        } catch (_) {}
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: bounds.center,
            initialZoom: 11,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              // Fit bounds nicely when ready
              Future.delayed(const Duration(milliseconds: 100), () {
                _mapController.fitCamera(CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(24),
                ));
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'pet_shop',
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: points, color: Colors.blue, strokeWidth: 4),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: origin,
                  width: 32,
                  height: 32,
                  child: const Icon(Icons.store_mall_directory, color: Colors.green, size: 28),
                ),
                Marker(
                  point: dest,
                  width: 32,
                  height: 32,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 28),
                ),
                Marker(
                  point: truckPos,
                  width: 40,
                  height: 40,
                  child: Transform.rotate(
                    angle: 0, // Could add heading calc later
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.local_shipping, color: Colors.blue, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
            ),
            if (_routeLoading)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 6),
                      Text('Đang lấy lộ trình...', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            if (_routeError != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                  ),
                  child: Text(_routeError!, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Interpolate a position along the given polyline using a 0..1 fraction
  LatLng _interpolateAlongPath(List<LatLng> path, double frac) {
    if (path.isEmpty) return LatLng(0, 0);
    if (path.length == 1) return path.first;
    if (frac <= 0) return path.first;
    if (frac >= 1) return path.last;

    final dist = const Distance();
    // Compute total length
    double total = 0;
    for (var i = 0; i < path.length - 1; i++) {
      total += dist(path[i], path[i + 1]);
    }
    if (total <= 0) return path.last;

    double target = total * frac;
    double acc = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final seg = dist(path[i], path[i + 1]);
      if (acc + seg >= target) {
        final remain = target - acc;
        final t = seg > 0 ? (remain / seg) : 0.0;
        // linear on lat/lng is good enough at this scale
        final a = path[i];
        final b = path[i + 1];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      acc += seg;
    }
    return path.last;
  }

  Widget _buildShippingInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Mã vận đơn', widget.trackingNumber, Icons.local_shipping),
          const SizedBox(height: 8),
          _buildInfoRow('Đơn vị vận chuyển', _trackingData!['shippingCompany'], Icons.business),
          const SizedBox(height: 8),
          // Ẩn "Dự kiến giao hàng" khi đã giao, thay bằng "Thời gian nhận hàng"
          if ((_trackingData!['status'] ?? '') != 'delivered')
            _buildInfoRow('Dự kiến giao hàng', _formatDate(_trackingData!['estimatedDelivery']), Icons.schedule)
          else
            _buildInfoRow(
              'Thời gian nhận hàng',
              _formatDateTime(
                (_trackingData!['actualDeliveryTime'] ??
                        _trackingData!['deliveredAt'] ??
                        _trackingData!['estimatedDelivery'] ??
                        _trackingData!['createdAt']) as String,
              ),
              Icons.check_circle,
            ),
          if (_trackingData!['shippingFee'] != null && _trackingData!['shippingFee'] > 0) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Phí giao hàng', '${_formatCurrency(_trackingData!['shippingFee'])} ₫', Icons.attach_money),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  bool _showFullHistory = false;

  Widget _buildTrackingHistory() {
    final fullHistory = List<Map<String, dynamic>>.from(_trackingData!['trackingHistory']);
    // newest first
    final history = fullHistory.reversed.toList();
    final visibleCount = _showFullHistory ? history.length : history.length.clamp(0, 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lịch sử vận chuyển',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleCount,
            separatorBuilder: (context, index) => Container(
              width: 2,
              height: 16,
              margin: const EdgeInsets.only(left: 11),
              color: Colors.grey.shade300,
            ),
            itemBuilder: (context, index) {
              final item = history[index];
              final isLatest = index == 0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLatest ? Colors.green : Colors.grey.shade300,
                      border: Border.all(
                        color: isLatest ? Colors.green.shade700 : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isLatest
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['description'] ?? '',
                          style: TextStyle(
                            fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                            color: isLatest ? Colors.black : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(item['timestamp'] ?? ''),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (item['location'] != null) ...[
                              const SizedBox(width: 16),
                              Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item['location'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (history.length > 4)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showFullHistory = !_showFullHistory),
              icon: Icon(_showFullHistory ? Icons.expand_less : Icons.expand_more),
              label: Text(_showFullHistory ? 'Thu gọn' : 'Xem thêm'),
            ),
          ),
      ],
    );
  }

 Widget _buildAdminActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Quản lý giao hàng',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
               ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildStatusButton('in_transit', 'Đang vận chuyển'),
              _buildStatusButton('out_for_delivery', 'Đang giao hàng'),
              _buildStatusButton('delivered', 'Đã giao hàng'),
              _buildStatusButton('failed', 'Giao hàng thất bại'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String status, String label) {
    final currentStatus = _trackingData!['status'] as String;
    final isActive = currentStatus == status;
    
    return ElevatedButton(
      onPressed: isActive ? null : () => _updateStatus(status, label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.grey : Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _updateStatus(String status, String description) async {
    try {
      final result = await ShippingService.updateShipmentStatus(
        trackingNumber: widget.trackingNumber,
        newStatus: status,
        description: 'Admin cập nhật: $description',
        location: 'Cập nhật từ hệ thống',
      );

      if (result['success']) {
        await _loadTrackingData(); // Reload data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cập nhật trạng thái thành công: $description'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  String _formatDateTime(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}