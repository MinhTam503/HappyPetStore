import 'package:flutter/material.dart';
import 'package:pet_shop/services/shipping_service.dart';
import 'package:pet_shop/presentation/components/shipping_tracking_widget.dart';

/// 🧪 Demo Page - Test shipping functionality
class ShippingDemoPage extends StatefulWidget {
  const ShippingDemoPage({super.key});

  @override
  State<ShippingDemoPage> createState() => _ShippingDemoPageState();
}

class _ShippingDemoPageState extends State<ShippingDemoPage> {
  final _addressController = TextEditingController(text: 'abc, Thủ Đức, Hồ Chí Minh');
  final _customerNameController = TextEditingController(text: 'Nguyễn Văn A');
  final _customerEmailController = TextEditingController(text: 'customer@example.com');
  final _orderValueController = TextEditingController(text: '150000');
  
  String? _createdTrackingNumber;
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.science),
            SizedBox(width: 8),
            Text('Demo Shipping API'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreateShipmentSection(),
            if (_createdTrackingNumber != null) ...[
              const SizedBox(height: 32),
              _buildTrackingSection(),
            ],
            const SizedBox(height: 32),
            _buildInstructionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateShipmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_box, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  '1. Tạo đơn giao hàng mới',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ giao hàng',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên khách hàng',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _customerEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email khách hàng',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _orderValueController,
              decoration: const InputDecoration(
                labelText: 'Giá trị đơn hàng (VND)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createShipment,
                icon: _isCreating 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_shipping),
                label: Text(_isCreating ? 'Đang tạo...' : 'Tạo đơn giao hàng'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.track_changes, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '2. Theo dõi đơn hàng',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đơn giao hàng đã được tạo thành công!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          'Mã vận đơn: $_createdTrackingNumber',
                          style: TextStyle(color: Colors.green.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ShippingTrackingWidget(
              trackingNumber: _createdTrackingNumber!,
              isAdminView: true, // Cho phép admin update status
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Hướng dẫn sử dụng',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInstructionItem(
              '📦',
              'Tạo đơn giao hàng',
              'Khi đơn hàng chuyển sang "Processing", hệ thống tự động tạo đơn giao hàng với API miễn phí.',
            ),
            _buildInstructionItem(
              '🚚',
              'Theo dõi thời gian thực',
              'Status progression tự động: Chờ lấy hàng → Đang vận chuyển → Đang giao hàng → Đã giao hàng.',
            ),
            _buildInstructionItem(
              '👨‍💼',
              'Quản lý admin',
              'Admin có thể cập nhật trạng thái giao hàng trực tiếp từ giao diện quản lý.',
            ),
            _buildInstructionItem(
              '💡',
              'Mock API',
              'Sử dụng mock data để demo, không cần API key thật. Dễ dàng chuyển sang API thật sau này.',
            ),
            _buildInstructionItem(
              '🎯',
              'Tích hợp hoàn chỉnh',
              'Đã tích hợp vào orders admin, có thể mở rộng cho mobile app và customer tracking.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createShipment() async {
    if (_addressController.text.isEmpty ||
        _customerNameController.text.isEmpty ||
        _customerEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final result = await ShippingService.createShipment(
        orderId: 'DEMO-${DateTime.now().millisecondsSinceEpoch}',
        shippingAddress: _addressController.text,
        customerInfo: {
          'name': _customerNameController.text,
          'email': _customerEmailController.text,
        },
        totalValue: double.tryParse(_orderValueController.text) ?? 0,
      );

      if (result['success']) {
        setState(() {
          _createdTrackingNumber = result['data']['trackingNumber'];
          _isCreating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tạo đơn giao hàng thành công: $_createdTrackingNumber'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isCreating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi không mong muốn: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _orderValueController.dispose();
    super.dispose();
  }
}