import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTrackingData();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildShippingInfo(),
            const SizedBox(height: 16),
            _buildTrackingHistory(),
            if (widget.isAdminView) ...[
              const SizedBox(height: 16),
              _buildAdminActions(),
            ],
          ],
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
          _buildInfoRow('Dự kiến giao hàng', _formatDate(_trackingData!['estimatedDelivery']), Icons.schedule),
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

  Widget _buildTrackingHistory() {
    final history = List<Map<String, dynamic>>.from(_trackingData!['trackingHistory']);
    
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
        // Wrap trong Container với height cố định để có thể cuộn
        Container(
          height: 250, // Giới hạn chiều cao
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: history.length,
            separatorBuilder: (context, index) => Container(
              width: 2,
              height: 16,
              margin: const EdgeInsets.only(left: 11),
              color: Colors.grey.shade300,
            ),
            itemBuilder: (context, index) {
              final item = history[history.length - 1 - index]; // Reverse order (newest first)
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
                          item['description'],
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
                              _formatDateTime(item['timestamp']),
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
                                  item['location'],
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