import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/payment_service.dart';

// Conditional imports cho web/mobile compatibility
import 'debug_connection_stub.dart'
    if (dart.library.html) 'debug_connection_web.dart'
    if (dart.library.io) 'debug_connection_mobile.dart';

/// Debug utility để test kết nối backend
class DebugConnectionScreen extends StatefulWidget {
  const DebugConnectionScreen({Key? key}) : super(key: key);

  @override
  State<DebugConnectionScreen> createState() => _DebugConnectionScreenState();
}

class _DebugConnectionScreenState extends State<DebugConnectionScreen> {
  String _output = '';
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _output += '${DateTime.now().toString().substring(11, 19)}: $message\n';
    });
    print(message);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _output = 'Starting connection test...\n';
    });

    _addLog(' Testing PaymentService connection...');
    _addLog(' Platform info: ${PlatformInfo.getBrowserInfo()}');
    
    // Test basic health check
    _addLog(' Step 1: Basic health check');
    bool healthy = await PaymentService.isBackendHealthy();
    _addLog('Health check result: ${healthy ? 'PASS' : ' FAIL'}');

    // Test payment intent creation
    _addLog('\n Step 2: Payment Intent Test');
    final paymentResult = await PaymentService.createPaymentIntent(amount: 10.0);
    if (paymentResult != null) {
      _addLog(' Payment intent created successfully');
      _addLog('   Client secret: ${paymentResult['client_secret']?.substring(0, 50)}...');
    } else {
      _addLog(' Payment intent creation failed');
    }

    // Test current base URL
    _addLog('\n Step 3: Current configuration');
    _addLog('Current base URL: ${PaymentService.getCurrentBaseUrl()}');
    
    // Platform security info
    _addLog('\n Step 4: Platform security info');
    _addLog('Protocol: ${PlatformInfo.getProtocol()}');
    _addLog('Host: ${PlatformInfo.getHost()}');
    _addLog('Is HTTPS: ${PlatformInfo.isHttps()}');

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Connection'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              child: _isLoading 
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Testing...'),
                    ],
                  )
                : const Text('Test Backend Connection'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _output.isEmpty ? 'No tests run yet' : _output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _output = '';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
              ),
              child: const Text('Clear Log'),
            ),
          ],
        ),
      ),
    );
  }
}
