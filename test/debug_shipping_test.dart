import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/services/shipping_service.dart';

void main() {
  setUpAll(() async {
    // Load test environment
    dotenv.testLoad(fileInput: '''
USE_GOSHIP=false
''');
  });

  group('Shipping Service Debug Tests', () {
    test('Should create mock shipment with all required parameters', () async {
      final result = await ShippingService.createShipment(
        orderId: 'DEBUG_TEST_001',
        shippingAddress: '123 Test Street, Thủ Đức, TP.HCM',
        customerInfo: {
          'name': 'Test Customer',
          'email': 'test@example.com',
        },
        totalValue: 45.0,
        items: [
          {
            'name': 'Pet Store Order',
            'quantity': 1,
            'price': 45.0,
            'weight': 1000,
          }
        ],
      );

      print('🧪 Test Result: ${result}');

      expect(result['success'], true);
      expect(result['data']['trackingNumber'], isNotNull);
      expect(result['data']['trackingNumber'], isA<String>());
      expect(result['data']['trackingNumber'].length, greaterThan(5)); // Should be realistic length
      expect(result['data']['status'], 'pickup_pending');
      expect(result['data']['shippingCompany'], isNotNull);
    });

    test('Should handle missing items parameter gracefully', () async {
      final result = await ShippingService.createShipment(
        orderId: 'DEBUG_TEST_002',
        shippingAddress: '456 Test Avenue, Quận 1, TP.HCM',
        customerInfo: {
          'name': 'Test Customer 2',
          'email': 'test2@example.com',
        },
        totalValue: 100.0,
        // No items parameter - should still work
      );

      expect(result['success'], true);
      expect(result['data']['trackingNumber'], isNotNull);
    });

    test('Should parse total value correctly', () async {
      final result = await ShippingService.createShipment(
        orderId: 'DEBUG_TEST_003',
        shippingAddress: 'Test Address',
        customerInfo: {
          'name': 'Test Customer',
          'email': 'test@example.com',
        },
        totalValue: 250000.0, // Large Vietnamese price
        items: [
          {
            'name': 'Golden Retriever',
            'quantity': 1,
            'price': 250000.0,
            'weight': 5000, // 5kg
          }
        ],
      );

      expect(result['success'], true);
      expect(result['data']['shippingFee'], greaterThan(0));
    });

    test('Should use Mock API when USE_GOSHIP=false', () async {
      // Verify environment
      expect(dotenv.env['USE_GOSHIP'], 'false');

      final result = await ShippingService.createShipment(
        orderId: 'DEBUG_ENVIRONMENT_TEST',
        shippingAddress: 'Test Environment Address',
        customerInfo: {
          'name': 'Environment Test',
          'email': 'env@test.com',
        },
        totalValue: 50.0,
        items: [
          {
            'name': 'Environment Test Item',
            'quantity': 1,
            'price': 50.0,
            'weight': 500,
          }
        ],
      );

      expect(result['success'], true);
      expect(result['data']['trackingNumber'], isA<String>());
      expect(result['data']['trackingNumber'].length, greaterThan(5));
    });

    test('Should track created shipment', () async {
      // First create a shipment
      final createResult = await ShippingService.createShipment(
        orderId: 'DEBUG_TRACK_TEST',
        shippingAddress: 'Tracking Test Address',
        customerInfo: {
          'name': 'Track Test',
          'email': 'track@test.com',
        },
        totalValue: 75.0,
        items: [
          {
            'name': 'Tracking Test Item',
            'quantity': 1,
            'price': 75.0,
            'weight': 750,
          }
        ],
      );

      expect(createResult['success'], true);
      
      final trackingNumber = createResult['data']['trackingNumber'];
      expect(trackingNumber, isNotNull);

      // Then track it
      final trackResult = await ShippingService.trackShipment(trackingNumber);
      expect(trackResult['success'], true);
      expect(trackResult['data']['status'], 'pickup_pending');
      expect(trackResult['data']['trackingHistory'], isA<List>());
    });
  });
}

// Helper function to run this test manually
void runDebugTests() async {
  print('🧪 Starting Shipping Service Debug Tests...');
  
  // Setup
  dotenv.testLoad(fileInput: '''
USE_GOSHIP=false
''');

  // Test 1: Basic shipment creation
  try {
    final result = await ShippingService.createShipment(
      orderId: 'MANUAL_DEBUG_001',
      shippingAddress: '123 Manual Test, Thủ Đức, TP.HCM',
      customerInfo: {
        'name': 'Manual Test Customer',
        'email': 'manual@test.com',
      },
      totalValue: 99.0,
      items: [
        {
          'name': 'Manual Test Pet',
          'quantity': 1,
          'price': 99.0,
          'weight': 1500,
        }
      ],
    );

    print('✅ Manual Test Result: $result');
    
    if (result['success']) {
      final trackingNumber = result['data']['trackingNumber'];
      print('✅ Tracking Number: $trackingNumber');
      
      // Test tracking
      final trackResult = await ShippingService.trackShipment(trackingNumber);
      print('✅ Track Result: $trackResult');
    }
  } catch (e) {
    print('❌ Manual Test Error: $e');
  }

  print('🧪 Debug Tests Complete!');
}