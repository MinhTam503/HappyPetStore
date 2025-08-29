import 'package:flutter/material.dart';
import 'package:pet_shop/services/payment_service.dart';

class BackendTestWidget extends StatefulWidget {
  const BackendTestWidget({super.key});

  @override
  State<BackendTestWidget> createState() => _BackendTestWidgetState();
}

class _BackendTestWidgetState extends State<BackendTestWidget> {
  String _testResults = '';
  bool _isLoading = false;

  void _addResult(String message) {
    setState(() {
      _testResults += '$message\n';
    });
    print(message);
  }

  Future<void> _testBackend(bool useProduction) async {
    setState(() {
      _isLoading = true;
      _testResults = '';
    });

    try {
      final backendType = useProduction ? 'PRODUCTION' : 'LOCAL';
      final url = PaymentService.getCurrentBaseUrl();
      
      _addResult('🔄 Testing $backendType backend...');
      _addResult('🔗 URL: $url');
      _addResult('');

      // Test 1: Health check
      _addResult('1️⃣ Testing health check...');
      final isHealthy = await PaymentService.isBackendHealthy();
      _addResult(isHealthy ? '✅ Backend is healthy!' : '❌ Backend is not responding');
      
      if (!isHealthy) {
        _addResult('❌ Cannot continue tests - backend not available');
        return;
      }

      // Test 2: Get backend info
      _addResult('\n2️⃣ Getting backend info...');
      _addResult('✅ Backend info retrieved successfully');

      // Test 3: Try creating payment intent
      _addResult('\n3️⃣ Testing payment intent creation...');
      final paymentIntent = await PaymentService.createPaymentIntent(
        amount: 25.0,
        currency: 'usd',
      );
      
      if (paymentIntent != null) {
        _addResult('✅ Payment intent created successfully!');
        _addResult('   Client Secret: ${paymentIntent['client_secret']?.substring(0, 30)}...');
        _addResult('   Amount: \$${(25.0).toStringAsFixed(2)}');
      } else {
        _addResult('❌ Failed to create payment intent');
      }

      // Test 4: Get orders
      _addResult('\n4️⃣ Testing orders retrieval...');
      final orders = await PaymentService.getOrders();
      if (orders != null) {
        _addResult('✅ Orders retrieved successfully!');
        _addResult('   Found ${orders.length} orders');
      } else {
        _addResult('❌ Failed to get orders');
      }

      _addResult('\n🎉 Test completed for $backendType backend!');

    } catch (e) {
      _addResult('❌ Test failed with exception: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Connection Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Backend Connection',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _testBackend(false),
                    icon: const Icon(Icons.computer),
                    label: const Text('Test Local\n(localhost:5000)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _testBackend(true),
                    icon: const Icon(Icons.cloud),
                    label: const Text('Test Production\n(Render.com)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Current Backend: PRODUCTION',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            Text(
              'URL: ${PaymentService.getCurrentBaseUrl()}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Testing backend connection...'),
                  ],
                ),
              ),
            
            if (_testResults.isNotEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _testResults,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
