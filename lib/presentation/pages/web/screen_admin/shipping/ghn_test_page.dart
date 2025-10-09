import 'package:flutter/material.dart';
import 'package:pet_shop/services/ghn_service.dart';
import 'package:pet_shop/services/shipping_service.dart';

/// 🧪 GHN Test Page - Test GHN API integration
class GHNTestPage extends StatefulWidget {
  const GHNTestPage({super.key});

  @override
  State<GHNTestPage> createState() => _GHNTestPageState();
}

class _GHNTestPageState extends State<GHNTestPage> {
  final _scrollController = ScrollController();
  final List<String> _logs = [];
  bool _isLoading = false;
  String? _lastCreatedTrackingNumber; // Store last created tracking number

  @override
  void initState() {
    super.initState();
    _addLog('🧪 GHN Test Page initialized');
    _addLog('📋 Available tests:');
    _addLog('• Test Connection');
    _addLog('• Get Provinces');
    _addLog('• Create Test Shipment');
    _addLog('• Track Shipment');
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toIso8601String().substring(11, 19)} $message');
    });
    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('🧹 Logs cleared');
  }

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);
    _addLog('🔄 Testing GHN API connection...');
    
    try {
      final result = await GHNService.testConnection();
      
      if (result['success']) {
        _addLog('✅ Connection successful!');
        _addLog('📊 Token: ${result['data']['token']}');
        _addLog('🏪 Shop ID: ${result['data']['shopId']}');
        _addLog('🌍 Provinces available: ${result['data']['provinces_count']}');
      } else {
        _addLog('❌ Connection failed: ${result['message']}');
        _addLog('🔍 Error: ${result['error']}');
      }
    } catch (e) {
      _addLog('💥 Exception: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _getProvinces() async {
    setState(() => _isLoading = true);
    _addLog('🔄 Getting provinces list...');
    
    try {
      final result = await GHNService.getProvinces();
      
      if (result['success']) {
        final provinces = result['data'] as List;
        _addLog('✅ Found ${provinces.length} provinces');
        
        // Show first 5 provinces as example
        for (int i = 0; i < (provinces.length > 5 ? 5 : provinces.length); i++) {
          final province = provinces[i];
          _addLog('  📍 ${province['ProvinceName']} (ID: ${province['ProvinceID']})');
        }
        
        if (provinces.length > 5) {
          _addLog('  ... and ${provinces.length - 5} more provinces');
        }
      } else {
        _addLog('❌ Failed to get provinces: ${result['message']}');
      }
    } catch (e) {
      _addLog('💥 Exception: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _createTestShipment() async {
    setState(() => _isLoading = true);
    _addLog('🔄 Creating test shipment...');
    
    try {
      final result = await ShippingService.createShipment(
        orderId: 'GHN_TEST_${DateTime.now().millisecondsSinceEpoch}',
        shippingAddress: 'Test Address, Phường 1, Quận 1, TP.HCM',
        customerInfo: {
          'name': 'Test Customer',
          'phone': '0987654321', // Valid Vietnamese phone number
          'email': 'test@example.com',
        },
        totalValue: 100000.0,
        totalWeight: 2.0, // 2kg
        items: [
          {
            'name': 'Test Pet Food',
            'quantity': 1,
            'price': 100000,
            'weight': 2000, // 2kg in grams
          }
        ],
      );
      
      if (result['success']) {
        final data = result['data'];
        _addLog('✅ Shipment created successfully!');
        _addLog('📦 Tracking Number: ${data['trackingNumber']}');
        _addLog('🚚 Company: ${data['shippingCompany']}');
        _addLog('💰 Shipping Fee: ${data['shippingFee']} VNĐ');
        _addLog('📅 Estimated Delivery: ${data['estimatedDelivery']}');
        _addLog('🔧 Provider: ${data['provider'] ?? 'unknown'}');
        
        // Store tracking number for future tracking test
        _lastCreatedTrackingNumber = data['trackingNumber'];
        
        if (data['ghnOrderCode'] != null) {
          _addLog('🎯 GHN Order Code: ${data['ghnOrderCode']}');
        }
      } else {
        _addLog('❌ Failed to create shipment: ${result['message']}');
        _addLog('🔍 Error: ${result['error']}');
      }
    } catch (e) {
      _addLog('💥 Exception: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _trackTestShipment() async {
    setState(() => _isLoading = true);
    _addLog('🔄 Testing shipment tracking...');
    
    // Use last created tracking number or test with a known working tracking
    String testTrackingNumber = _lastCreatedTrackingNumber ?? 'L8MAWXQB'; 
    
    // If we have a created tracking number, test it; otherwise test GHN sample
    if (_lastCreatedTrackingNumber != null) {
      _addLog('📦 Tracking created shipment: $testTrackingNumber');
    } else {
      _addLog('📦 Testing with sample tracking: $testTrackingNumber');
      _addLog('💡 Create a shipment first for better testing');
    }
    
    try {
      final result = await ShippingService.trackShipment(testTrackingNumber);
      
      if (result['success']) {
        final data = result['data'];
        _addLog('✅ Tracking successful!');
        _addLog('📦 Tracking: ${data['trackingNumber']}');
        _addLog('📊 Status: ${data['status']}');
        _addLog('🚚 Company: ${data['shippingCompany']}');
        _addLog('📍 Current Location: ${data['currentLocation'] ?? 'Unknown'}');
        _addLog('🔧 Provider: ${data['provider'] ?? 'unknown'}');
        
        final history = data['trackingHistory'] as List?;
        if (history != null && history.isNotEmpty) {
          _addLog('📋 Tracking History:');
          for (final event in history.take(3)) {
            _addLog('  • ${event['description']} (${event['timestamp']})');
          }
        }
      } else {
        _addLog('❌ Tracking failed: ${result['message']}');
        _addLog('🔍 Error: ${result['error']}');
        
        // Provide helpful suggestions
        if (_lastCreatedTrackingNumber == null) {
          _addLog('💡 Tip: Create a shipment first, then track it');
          _addLog('💡 Or the sample tracking number may not exist in GHN test environment');
        }
      }
    } catch (e) {
      _addLog('💥 Exception: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _updateShipmentStatus() async {
    if (_lastCreatedTrackingNumber == null) {
      _addLog('❌ No shipment to update. Create a shipment first.');
      return;
    }
    
    setState(() => _isLoading = true);
    _addLog('🔄 Simulating status update...');
    _addLog('📦 Tracking Number: $_lastCreatedTrackingNumber');
    _addLog('⚠️  NOTE: This is SIMULATION only!');
    _addLog('');
    
    // Simulate status progression
    final statuses = ['picked', 'storing', 'transporting', 'delivering', 'delivered'];
    final randomStatus = statuses[DateTime.now().millisecond % statuses.length];
    
    try {
      final result = await GHNService.updateOrderStatus(
        orderCode: _lastCreatedTrackingNumber!,
        newStatus: randomStatus,
        description: 'Test status update từ Happy Pets',
      );
      
      if (result['success']) {
        final data = result['data'];
        _addLog('✅ Status simulation completed!');
        _addLog('📊 Simulated Status: ${data['status']}');
        _addLog('📝 Description: ${data['description']}');
        _addLog('⏰ Simulated At: ${data['updatedAt']}');
        _addLog('');
        _addLog('⚠️ IMPORTANT: For REAL status update:');
        _addLog('1. Go to: https://5sao.ghn.dev/order');
        _addLog('2. Find order: $_lastCreatedTrackingNumber');
        _addLog('3. Click order → Update status manually');
        _addLog('4. Then track here to see real changes');
      } else {
        _addLog('❌ Simulation failed: ${result['message']}');
        _addLog('🔍 Error: ${result['error']}');
      }
    } catch (e) {
      _addLog('💥 Exception: $e');
    }
    
    setState(() => _isLoading = false);
  }

  void _showTestInstructions() {
    _addLog('📋 === GHN TEST INSTRUCTIONS ===');
    _addLog('');
    _addLog('🎯 Test Environment Info:');
    _addLog('• URL: https://5sao.ghn.dev (TEST only)');
    _addLog('• No real shipping costs');
    _addLog('• No actual delivery');
    _addLog('• Free to test and experiment');
    _addLog('');
    _addLog('🔄 REAL Status Update (ONLY way):');
    _addLog('1. Go to https://5sao.ghn.dev/order');
    _addLog('2. Find your order (tracking: $_lastCreatedTrackingNumber)');
    _addLog('3. Click on order → Update status');
    _addLog('4. Choose: Picked → Storing → Delivering → Delivered');
    _addLog('5. Come back and track to see REAL changes');
    _addLog('');
    _addLog('⚠️  "Update Status" button = SIMULATION only!');
    _addLog('• GHN test environment blocks programmatic updates');
    _addLog('• Only manual updates via portal work');
    _addLog('• Button just tests UI logic, not real API');
    _addLog('');
    _addLog('🧪 Proper Testing Flow:');
    _addLog('1. Create Shipment → Get tracking number');
    _addLog('2. Manual update on GHN portal');
    _addLog('3. Track Shipment → Verify REAL status');
    _addLog('4. Repeat with different statuses');
    _addLog('');
    _addLog('✅ Success Criteria:');
    _addLog('• Create shipment works → Real tracking');
    _addLog('• Manual portal update works');
    _addLog('• Track shows updated status from GHN');
    _addLog('• Provider shows "ghn" not "mock"');
    _addLog('');
    _addLog('🚀 Ready for production when all tests pass!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 GHN API Test'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Test buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _testConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Test Connection'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _getProvinces,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Get Provinces'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createTestShipment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Create Shipment'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _trackTestShipment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Track Shipment'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Third row for advanced testing
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_isLoading || _lastCreatedTrackingNumber == null) ? null : _updateShipmentStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Update Status'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _showTestInstructions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Instructions'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Processing...'),
                ],
              ),
            ),
          
          // Logs display
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.greenAccent,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}