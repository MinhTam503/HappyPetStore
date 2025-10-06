import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/services/goship_service.dart';
import '../lib/services/shipping_service.dart';

void main() {
  setUpAll(() async {
    // Load environment variables for testing
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // If .env doesn't exist, use default values for testing
      dotenv.testLoad(fileInput: '''
USE_GOSHIP=false
GOSHIP_BASE_URL=https://api-staging.goship.io
GOSHIP_API_KEY=gs_test_mock_key_for_testing
STORE_NAME=Happy Pets Store
STORE_ADDRESS=123 Test Street, Thủ Đức, TP.HCM
STORE_PHONE=0123456789
STORE_EMAIL=store@happypets.com
''');
    }
  });

  group('🚚 Shipping Integration Tests', () {
    group('Mock API Tests', () {
      test('Should create shipment with mock API', () async {
        // Force mock API usage
        dotenv.env['USE_GOSHIP'] = 'false';

        final result = await ShippingService.createShipment(
          orderId: 'TEST_ORDER_001',
          shippingAddress: '456 Customer Street, Quận 1, TP.HCM',
          customerInfo: {
            'name': 'Test Customer',
            'phone': '0987654321',
            'email': 'test@example.com',
          },
          totalValue: 150000,
          items: [
            {
              'name': 'Test Pet Food',
              'quantity': 1,
              'price': 150000,
              'weight': 1000,
            }
          ],
        );

        expect(result['success'], true);
        expect(result['data']['trackingNumber'], isNotNull);
        expect(result['data']['trackingNumber'], startsWith('MOCK'));
        expect(result['data']['carrier'], 'Mock Shipping');
      });

      test('Should track shipment with mock API', () async {
        // Force mock API usage
        dotenv.env['USE_GOSHIP'] = 'false';

        final result = await ShippingService.trackShipment('MOCK123456789');

        expect(result['success'], true);
        expect(result['data']['status'], isNotNull);
        expect(result['data']['trackingHistory'], isA<List>());
      });

      test('Should handle shipping operations with mock API', () async {
        // Force mock API usage
        dotenv.env['USE_GOSHIP'] = 'false';

        // Test creating and tracking in sequence
        final createResult = await ShippingService.createShipment(
          orderId: 'TEST_MOCK_FEE_001',
          shippingAddress: 'Quận 1, TP.HCM',
          customerInfo: {
            'name': 'Test Customer',
            'phone': '0987654321',
            'email': 'test@example.com',
          },
          totalValue: 100000,
          items: [
            {
              'name': 'Test Item',
              'quantity': 1,
              'price': 100000,
              'weight': 1000,
            }
          ],
        );

        expect(createResult['success'], true);
        
        // Test tracking the created shipment
        final trackingNumber = createResult['data']['trackingNumber'];
        final trackResult = await ShippingService.trackShipment(trackingNumber);
        
        expect(trackResult['success'], true);
        expect(trackResult['data']['status'], isNotNull);
      });
    });

    group('GoSHIP API Tests', () {
      test('Should test GoSHIP connection (may fail without real API key)', () async {
        // These tests may fail without real GoSHIP credentials
        // but should not crash the app
        try {
          final result = await GoShipService.testConnection();
          // If we have real credentials, expect success
          if (dotenv.env['GOSHIP_API_KEY']?.startsWith('gs_') == true) {
            expect(result['success'], true);
          }
        } catch (e) {
          // Expected if no real API key
          expect(e.toString(), contains('API'));
        }
      });

      test('Should handle GoSHIP API errors gracefully', () async {
        // Test with invalid API key
        final originalKey = dotenv.env['GOSHIP_API_KEY'];
        dotenv.env['GOSHIP_API_KEY'] = 'invalid_key';

        try {
          final result = await GoShipService.testConnection();
          expect(result['success'], false);
          expect(result['message'], isNotNull);
        } finally {
          // Restore original key
          dotenv.env['GOSHIP_API_KEY'] = originalKey ?? '';
        }
      });

      test('Should fallback to mock when GoSHIP fails', () async {
        // Simulate GoSHIP failure by using invalid base URL
        final originalUrl = dotenv.env['GOSHIP_BASE_URL'];
        final originalUseGoship = dotenv.env['USE_GOSHIP'];
        
        dotenv.env['GOSHIP_BASE_URL'] = 'https://invalid-url.com';
        dotenv.env['USE_GOSHIP'] = 'true';

        try {
          final result = await ShippingService.createShipment(
            orderId: 'TEST_FALLBACK_001',
            shippingAddress: '456 Test Street, Quận 1, TP.HCM',
            customerInfo: {
              'name': 'Test Customer',
              'phone': '0987654321',
              'email': 'test@example.com',
            },
            totalValue: 150000,
            items: [
              {
                'name': 'Test Item',
                'quantity': 1,
                'price': 150000,
                'weight': 1000,
              }
            ],
          );

          // Should fallback to mock and still succeed
          expect(result['success'], true);
          expect(result['data']['trackingNumber'], startsWith('MOCK'));
        } finally {
          // Restore original values
          dotenv.env['GOSHIP_BASE_URL'] = originalUrl ?? '';
          dotenv.env['USE_GOSHIP'] = originalUseGoship ?? 'false';
        }
      });
    });

    group('Hybrid Service Tests', () {
      test('Should route to correct service based on USE_GOSHIP flag', () async {
        // Test Mock routing
        dotenv.env['USE_GOSHIP'] = 'false';
        
        final mockResult = await ShippingService.createShipment(
          orderId: 'TEST_HYBRID_001',
          shippingAddress: '456 Test Street, Quận 1, TP.HCM',
          customerInfo: {
            'name': 'Test Customer',
            'phone': '0987654321',
            'email': 'test@example.com',
          },
          totalValue: 150000,
          items: [
            {
              'name': 'Test Item',
              'quantity': 1,
              'price': 150000,
              'weight': 1000,
            }
          ],
        );

        expect(mockResult['success'], true);
        expect(mockResult['data']['trackingNumber'], startsWith('MOCK'));

        // Test GoSHIP routing (will fallback to mock if no real API)
        dotenv.env['USE_GOSHIP'] = 'true';
        
        final goshipResult = await ShippingService.createShipment(
          orderId: 'TEST_HYBRID_002',
          shippingAddress: '456 Test Street, Quận 1, TP.HCM',
          customerInfo: {
            'name': 'Test Customer',
            'phone': '0987654321',
            'email': 'test@example.com',
          },
          totalValue: 150000,
          items: [
            {
              'name': 'Test Item',
              'quantity': 1,
              'price': 150000,
              'weight': 1000,
            }
          ],
        );

        expect(goshipResult['success'], true);
        expect(goshipResult['data']['trackingNumber'], isNotNull);
      });

      test('Should handle environment variable edge cases', () async {
        final originalValue = dotenv.env['USE_GOSHIP'];

        // Test undefined value
        dotenv.env.remove('USE_GOSHIP');
        var result = await ShippingService.createShipment(
          orderId: 'TEST_ENV_001',
          shippingAddress: '456 Test Street, Quận 1, TP.HCM',
          customerInfo: {
            'name': 'Test Customer',
            'phone': '0987654321',
            'email': 'test@example.com',
          },
          totalValue: 150000,
          items: [
            {
              'name': 'Test Item',
              'quantity': 1,
              'price': 150000,
              'weight': 1000,
            }
          ],
        );
        expect(result['success'], true); // Should default to mock

        // Test empty string
        dotenv.env['USE_GOSHIP'] = '';
        result = await ShippingService.createShipment(
          orderId: 'TEST_ENV_002',
          shippingAddress: '456 Test Street, Quận 1, TP.HCM',
          customerInfo: {
            'name': 'Test Customer',
            'phone': '0987654321',
            'email': 'test@example.com',
          },
          totalValue: 150000,
          items: [
            {
              'name': 'Test Item',
              'quantity': 1,
              'price': 150000,
              'weight': 1000,
            }
          ],
        );
        expect(result['success'], true); // Should default to mock

        // Restore original value
        if (originalValue != null) {
          dotenv.env['USE_GOSHIP'] = originalValue;
        }
      });
    });

    group('Data Validation Tests', () {
      test('Should validate required fields', () async {
        // Test missing orderId
        expect(
          () => ShippingService.createShipment(
            orderId: '',
            shippingAddress: '456 Test Street, Quận 1, TP.HCM',
            customerInfo: {
              'name': 'Test Customer',
              'phone': '0987654321',
              'email': 'test@example.com',
            },
            totalValue: 150000,
            items: [],
          ),
          throwsException,
        );
      });

      test('Should handle Vietnamese addresses correctly', () async {
        dotenv.env['USE_GOSHIP'] = 'false';

        final result = await ShippingService.createShipment(
          orderId: 'TEST_VN_001',
          shippingAddress: '123 Nguyễn Văn Cừ, Phường 4, Quận 5, TP.HCM',
          customerInfo: {
            'name': 'Nguyễn Văn A',
            'phone': '0987654321',
            'email': 'nguyenvana@example.com',
          },
          totalValue: 200000,
          items: [
            {
              'name': 'Thức ăn cho chó',
              'quantity': 2,
              'price': 100000,
              'weight': 1500,
            }
          ],
        );

        expect(result['success'], true);
        expect(result['data']['trackingNumber'], isNotNull);
      });

      test('Should handle large orders correctly', () async {
        dotenv.env['USE_GOSHIP'] = 'false';

        final items = List.generate(10, (index) => {
          'name': 'Pet Item ${index + 1}',
          'quantity': 1,
          'price': 50000,
          'weight': 500,
        });

        final result = await ShippingService.createShipment(
          orderId: 'TEST_LARGE_001',
          shippingAddress: '456 Test Street, Quận 1, TP.HCM',
          customerInfo: {
            'name': 'Test Customer',
            'phone': '0987654321',
            'email': 'test@example.com',
          },
          totalValue: 500000,
          items: items,
        );

        expect(result['success'], true);
        expect(result['data']['trackingNumber'], isNotNull);
      });
    });
  });

  group('🧪 Performance Tests', () {
    test('Should respond within acceptable time limits', () async {
      dotenv.env['USE_GOSHIP'] = 'false';

      final stopwatch = Stopwatch()..start();

      final result = await ShippingService.createShipment(
        orderId: 'TEST_PERF_001',
        shippingAddress: '456 Test Street, Quận 1, TP.HCM',
        customerInfo: {
          'name': 'Test Customer',
          'phone': '0987654321',
          'email': 'test@example.com',
        },
        totalValue: 150000,
        items: [
          {
            'name': 'Test Item',
            'quantity': 1,
            'price': 150000,
            'weight': 1000,
          }
        ],
      );

      stopwatch.stop();

      expect(result['success'], true);
      expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete within 5 seconds
    });

    test('Should handle concurrent requests', () async {
      dotenv.env['USE_GOSHIP'] = 'false';

      final futures = List.generate(5, (index) => 
        ShippingService.createShipment(
          orderId: 'TEST_CONCURRENT_${index + 1}',
          shippingAddress: '456 Test Street, Quận 1, TP.HCM',
          customerInfo: {
            'name': 'Test Customer ${index + 1}',
            'phone': '098765432${index}',
            'email': 'test${index}@example.com',
          },
          totalValue: 150000,
          items: [
            {
              'name': 'Test Item ${index + 1}',
              'quantity': 1,
              'price': 150000,
              'weight': 1000,
            }
          ],
        )
      );

      final results = await Future.wait(futures);

      for (final result in results) {
        expect(result['success'], true);
        expect(result['data']['trackingNumber'], isNotNull);
      }
    });
  });
}