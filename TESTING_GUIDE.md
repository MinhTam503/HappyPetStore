# 🧪 Testing Guide - GoSHIP Integration

## 🎯 Test Scenarios

### **1. Mock API Testing (Instant)**
```bash
# Setup for immediate testing
USE_GOSHIP=false
```

**Test Cases:**
```dart
✅ Create shipment → Mock tracking number generated
✅ Track shipment → Mock status progression  
✅ Admin dashboard → Mock shipment data displayed
✅ Order workflow → Pending → Processing → Delivered
✅ Customer notifications → Email with tracking info
```

### **2. GoSHIP Staging Testing**
```bash
# Setup for staging environment
USE_GOSHIP=true
GOSHIP_BASE_URL=https://api-staging.goship.io
GOSHIP_API_KEY=gs_test_staging_key
```

**Test Cases:**
```dart
✅ API Connection → Test basic connectivity
✅ Rate calculation → Real shipping fees
✅ Shipment creation → Real tracking numbers
✅ Tracking updates → Live status changes
✅ Webhook handling → Real-time notifications
```

### **3. Production Testing**
```bash
# Setup for live environment
USE_GOSHIP=true
GOSHIP_BASE_URL=https://api.goship.io
GOSHIP_API_KEY=gs_live_production_key
```

**Test Cases:**
```dart
✅ Live orders → Real shipping process
✅ Customer experience → End-to-end flow
✅ Payment integration → COD handling
✅ Performance monitoring → Response times
✅ Error handling → Fallback mechanisms
```

## 🔄 Automated Test Scripts

### **API Connection Test:**
```dart
// File: test/shipping_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/goship_service.dart';

void main() {
  group('GoSHIP Integration Tests', () {
    test('API connection test', () async {
      final result = await GoShipService.testConnection();
      expect(result['success'], true);
    });

    test('Rate calculation test', () async {
      final result = await GoShipService.calculateShippingFee(
        from: 'Thủ Đức, TP.HCM',
        to: 'Quận 1, TP.HCM',
        weight: 1000,
        value: 100000,
      );
      expect(result['success'], true);
      expect(result['data']['fee'], greaterThan(0));
    });

    test('Shipment creation test', () async {
      final result = await GoShipService.createShipment(
        orderId: 'TEST_ORDER_001',
        from: {
          'name': 'Happy Pets Store',
          'phone': '0123456789',
          'address': '123 Test Street, Thủ Đức, TP.HCM',
        },
        to: {
          'name': 'Test Customer',
          'phone': '0987654321',
          'address': '456 Customer Street, Quận 1, TP.HCM',
        },
        items: [
          {
            'name': 'Test Pet Food',
            'quantity': 1,
            'weight': 1000,
            'value': 100000,
          }
        ],
      );
      expect(result['success'], true);
      expect(result['data']['trackingNumber'], isNotNull);
    });
  });
}
```

### **Run Tests:**
```bash
# Run all shipping tests
flutter test test/shipping_integration_test.dart

# Run with coverage
flutter test --coverage
```

## 📊 Performance Benchmarks

### **Response Time Expectations:**
```dart
✅ Rate calculation: < 2 seconds
✅ Shipment creation: < 3 seconds  
✅ Tracking query: < 1 second
✅ Status updates: Real-time via webhook
```

### **Load Testing:**
```dart
// Test concurrent shipment creation
void stressTest() async {
  final futures = <Future>[];
  
  for (int i = 0; i < 10; i++) {
    futures.add(createTestShipment(i));
  }
  
  final results = await Future.wait(futures);
  final successCount = results.where((r) => r['success']).length;
  
  print('Success rate: ${successCount}/10');
}
```

## 🐛 Common Issues & Solutions

### **1. API Key Issues**
```dart
❌ Error: "Invalid API key"
✅ Solution: 
- Check .env file exists
- Verify API key format: gs_test_xxx or gs_live_xxx
- Ensure no extra spaces in .env
```

### **2. Address Format Issues**
```dart
❌ Error: "Invalid address format"
✅ Solution:
- Use full address: "Street, Ward, District, City"
- Include Vietnamese diacritics correctly
- Test with GoSHIP address validation
```

### **3. Network Timeout**
```dart
❌ Error: "Request timeout"
✅ Solution:
- Increase timeout in http client
- Implement retry mechanism
- Check internet connection
- Verify GoSHIP server status
```

### **4. Webhook Issues**
```dart
❌ Error: "Webhook not receiving"
✅ Solution:
- Verify webhook URL is accessible
- Check HTTPS certificate
- Validate webhook signature
- Test with ngrok for local development
```

## 🔄 Development Workflow

### **Day 1: Mock Setup**
```bash
1. Set USE_GOSHIP=false
2. Test complete order flow with mock
3. Verify UI/UX works correctly
4. Test admin dashboard features
```

### **Day 2: GoSHIP Staging**
```bash
1. Register GoSHIP staging account
2. Set USE_GOSHIP=true with staging URL
3. Test real API calls
4. Compare with mock behavior
```

### **Day 3: Production Preparation**
```bash
1. Register GoSHIP production account
2. Setup webhook endpoints
3. Configure production environment
4. Run comprehensive tests
```

### **Day 4: Go Live**
```bash
1. Deploy with USE_GOSHIP=true
2. Monitor first real orders
3. Check customer experience
4. Monitor error logs
```

## 📈 Monitoring Setup

### **Key Metrics to Track:**
```dart
// API Performance
- Response time per endpoint
- Success rate vs error rate  
- API quota usage
- Rate limit hits

// Business Metrics
- Orders with tracking vs without
- Customer satisfaction scores
- Delivery success rate
- Cost per shipment

// Technical Metrics
- Mock vs GoSHIP usage ratio
- Fallback activation frequency
- Error types and frequency
- System uptime
```

### **Alerting Setup:**
```dart
// Critical Alerts
🚨 GoSHIP API down > 5 minutes
🚨 Success rate < 95% over 1 hour
🚨 Response time > 10 seconds
🚨 Webhook failures > 10% 

// Warning Alerts  
⚠️ API quota > 80% usage
⚠️ Fallback to mock activated
⚠️ Unusual error patterns
⚠️ Performance degradation
```

## 🎯 User Acceptance Testing

### **Customer Journey Tests:**

**Scenario 1: Standard Order**
```dart
1. Customer places order
2. Admin marks as "Processing"  
3. Shipment auto-created
4. Customer receives tracking email
5. Customer tracks order status
6. Order delivered successfully
```

**Scenario 2: Failed Delivery**
```dart
1. Delivery attempt fails
2. Status updates to "Failed"
3. Customer notified automatically
4. Admin can reschedule delivery
5. Second attempt successful
```

**Scenario 3: API Downtime**
```dart
1. GoSHIP API unavailable
2. System falls back to mock
3. Order processing continues
4. Customer experience unaffected
5. Auto-recovery when API returns
```

## 🚀 Production Checklist

### **Before Going Live:**
- [ ] All tests passing
- [ ] GoSHIP production account verified
- [ ] API keys secured in environment
- [ ] Webhook endpoints configured
- [ ] Error monitoring setup
- [ ] Fallback mechanism tested
- [ ] Documentation complete
- [ ] Team training completed

### **Launch Day:**
- [ ] Deploy with feature flag
- [ ] Monitor first orders closely
- [ ] Check error logs every hour
- [ ] Verify webhook deliveries
- [ ] Test customer notifications
- [ ] Monitor performance metrics

### **Post-Launch:**
- [ ] Weekly performance review
- [ ] Customer feedback analysis
- [ ] Cost optimization review
- [ ] Feature usage analytics
- [ ] Plan next iterations

---

**🎉 Testing Complete!**

Với testing framework này, **Happy Pets** có thể confident deploy GoSHIP integration với minimal risk và maximum reliability.

## 🆘 Emergency Procedures

### **If GoSHIP Goes Down:**
```dart
1. System auto-falls back to mock
2. Orders continue processing
3. Alert dev team immediately
4. Monitor GoSHIP status page
5. Switch back when restored
```

### **If Critical Bug Found:**
```dart
1. Immediately set USE_GOSHIP=false
2. All orders use mock API
3. Fix issue in staging
4. Test thoroughly
5. Re-enable GoSHIP
```

### **Contact Information:**
- **GoSHIP Support**: support@goship.io
- **Emergency Hotline**: Available in merchant dashboard
- **Status Page**: status.goship.io