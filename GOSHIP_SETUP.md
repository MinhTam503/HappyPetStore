# 🚚 GoSHIP Testing Guide - Happy Pets

## 📋 Tổng Quan

Hướng dẫn sử dụng **GoSHIP API Test/Staging** cho **Happy Pets Store** để demo và học tập. **KHÔNG sử dụng production API**.

## 🧪 Setup GoSHIP Test Account

### **Bước 1: Đăng Ký GoSHIP Test Account**
1. Truy cập: https://merchants-staging.goship.io/ (Test environment)
2. Đăng ký tài khoản test miễn phí
3. Không cần xác thực doanh nghiệp (chỉ để test)
4. Lấy test API credentials từ staging dashboard

### **Bước 2: Lấy Test API Key**
```bash
# Trong GoSHIP Staging Dashboard:
1. Vào Settings → API Integration
2. Generate Test API Key
3. Copy Test API Key và Staging Base URL
# Note: Test API key có prefix gs_test_
```

### **Bước 3: Cấu Hình Environment cho Testing**
```env
# File .env - CHỈ DÙNG CHO TESTING
USE_GOSHIP=true
GOSHIP_BASE_URL=https://api-staging.goship.io
GOSHIP_API_KEY=gs_test_your_staging_key_here

# Store info for testing (có thể dùng thông tin fake)
STORE_NAME=Happy Pets Store (Test)
STORE_ADDRESS=123 Test Street, Thủ Đức, TP.HCM
STORE_PHONE=0123456789
STORE_EMAIL=test@happypets.com
```

## 🧪 Testing Environments

### **GoSHIP Staging (Recommended cho học tập)**
```env
# File .env - STAGING ENVIRONMENT
USE_GOSHIP=true
GOSHIP_BASE_URL=https://api-staging.goship.io
GOSHIP_API_KEY=gs_test_your_staging_key_here
```
**✅ Ưu điểm:**
- API thật nhưng môi trường test
- Không tốn phí thật
- Học được cách tích hợp API
- Tracking data giống thật

### **Mock API (Backup option)**
```env
# File .env - MOCK ENVIRONMENT  
USE_GOSHIP=false
# Sẽ sử dụng Mock API có sẵn
```
**✅ Ưu điểm:**
- Instant testing không cần internet
- Không cần đăng ký account
- Hoạt động offline
- Perfect cho development

## 🔧 Dependencies Required

### **Thêm vào pubspec.yaml:**
```yaml
dependencies:
  http: ^1.1.0
  flutter_dotenv: ^5.2.1
  
# Đã có sẵn trong project
```

### **Load .env file trong main.dart:**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  runApp(MyApp());
}
```

## 🚀 Usage Examples (Test Environment)

### **1. Tạo Test Shipment:**
```dart
// Trong orders_admin.dart - đã tích hợp sẵn
final result = await ShippingService.createShipment(
  orderId: 'TEST_ORDER_123',
  shippingAddress: 'Test Address, Thủ Đức, Hồ Chí Minh',
  customerInfo: {
    'name': 'Test Customer',
    'phone': '0123456789',
    'email': 'test@example.com',
  },
  totalValue: 150000,
  items: [
    {
      'name': 'Test Pet Food',
      'quantity': 1,
      'price': 150000,
      'weight': 2000, // 2kg in grams
    }
  ],
);

if (result['success']) {
  final trackingNumber = result['data']['trackingNumber'];
  print('Test Tracking: $trackingNumber');
  // Tracking number sẽ có format: GST_test_xxxxx
}
```

### **2. Test Tracking:**
```dart
// Test tracking với staging data
final result = await ShippingService.trackShipment('GST_test_123456');

if (result['success']) {
  final status = result['data']['status'];
  final history = result['data']['trackingHistory'];
  // Sẽ hiển thị test tracking data
}
```

### **3. Test API Connection:**
```dart
// Verify staging API connection
final result = await GoShipService.testConnection();

if (result['success']) {
  print('✅ GoSHIP Staging API connected');
} else {
  print('❌ Connection failed: ${result['message']}');
}
```

## 📊 GoSHIP Test Features

### **✅ Test Environment Capabilities:**
- **Rate Calculation** - Tính phí ship test (không tính tiền thật)
- **Test Order Creation** - Tạo đơn hàng demo với tracking
- **Simulated Tracking** - Theo dõi trạng thái test
- **Multiple Test Carriers** - Demo nhiều đơn vị vận chuyển
- **Test COD** - Demo thu hộ tiền (không có tiền thật)
- **Test Insurance** - Demo bảo hiểm (không có coverage thật)

### **🔄 Test Status Flow:**
| GoSHIP Test Status | Happy Pets Status | Description |
|-------------------|-------------------|-------------|
| `test_pending` | `pickup_pending` | Test: Chờ lấy hàng |
| `test_picked_up` | `in_transit` | Test: Đang vận chuyển |
| `test_out_for_delivery` | `out_for_delivery` | Test: Đang giao hàng |
| `test_delivered` | `delivered` | Test: Đã giao hàng |
| `test_failed` | `failed` | Test: Giao hàng thất bại |

**Note:** Tất cả status đều có prefix "test_" để phân biệt với production.

## 💰 Test Environment Pricing

### **GoSHIP Test Pricing:**
- **Setup Fee**: **MIỄN PHÍ** (test account)
- **Monthly Fee**: **MIỄN PHÍ** (staging environment)
- **Transaction Fee**: **0 VND** (chỉ test, không tính tiền)
- **API Calls**: **Unlimited** (test environment)

### **Test Shipping Rates:**
```dart
// Ví dụ test shipping fee (không phải tiền thật)
HCM → Hà Nội: 25,000 VND (test fee)
HCM → Đà Nẵng: 20,000 VND (test fee)  
HCM → Nội thành: 15,000 VND (test fee)

// Test free shipping threshold
Order > 500,000 VND = Free shipping (demo)
```

**⚠️ Important:** Tất cả pricing trong test environment chỉ để demo, không có giao dịch tiền thật.

## 🔄 Setup Process cho Testing

### **Quick Start (5 phút):**

**Step 1:** Đăng ký test account
```bash
# 1. Vào https://merchants-staging.goship.io/
# 2. Đăng ký với email bất kỳ
# 3. Verify email (check spam folder)
# 4. Login vào staging dashboard
```

**Step 2:** Lấy test credentials
```bash
# Trong staging dashboard:
# Settings → API Integration → Generate Test Key
# Copy API key: gs_test_xxxxxxx
```

**Step 3:** Update .env file
```env
# Thay đổi dòng này trong .env
USE_GOSHIP=true
GOSHIP_BASE_URL=https://api-staging.goship.io
GOSHIP_API_KEY=gs_test_your_key_here
```

**Step 4:** Test connection
```dart
// Chạy test để verify
final test = await GoShipService.testConnection();
print('Test Connection: ${test['success']}');
```

**Step 5:** Demo workflow
```dart
// Tạo test order trong admin → xem tracking hoạt động
```

## 🚨 Test Environment Notes

### **Test API Behavior:**
```dart
// Automatic fallback nếu staging API down
if (stagingGoshipFails) {
  // Sẽ tự động chuyển sang Mock API
  // App vẫn hoạt động bình thường
}
```

### **Test Environment Limitations:**
1. **Test Data Only**: Không có giao hàng thật
2. **Staging Uptime**: Có thể down maintenance thỉnh thoảng  
3. **Test Rate Limits**: Có thể bị limit nếu test quá nhiều
4. **No Real Webhooks**: Webhook chỉ simulate

### **Common Test Issues:**
1. **"Test API Key Invalid"**: Check prefix `gs_test_`
2. **"Staging Server Down"**: Sẽ auto fallback to mock
3. **"Test Rate Limit"**: Wait vài phút rồi thử lại
4. **"Invalid Test Address"**: Dùng address format chuẩn Việt Nam

## 📈 Test Monitoring

### **Test Metrics to Track:**
```dart
// Monitor trong admin dashboard (test data)
- Test shipments created
- Mock vs GoSHIP test success rate  
- Test API response time
- Demo user experience
- Learning progress
```

### **Demo Performance:**
```dart
// Test environment benchmarks
- Test rate calculation: < 3 seconds
- Test shipment creation: < 5 seconds
- Test tracking query: < 2 seconds
- Mock fallback: Instant
```

## 🔐 Test Security

### **Test API Key Security:**
```dart
// Best practices cho test environment
- Sử dụng .env files
- Never commit test API keys to git
- Test keys có prefix gs_test_
- OK to share test keys trong documentation
- Monitor test API usage
```

### **Test Data Privacy:**
```dart
// Test environment data handling
- Chỉ dùng fake customer data
- Không dùng thông tin thật của khách hàng
- Test addresses có thể là fake
- Email notifications chỉ gửi cho test accounts
```

## 🎉 Demo Ready Checklist

### **Test Environment Setup:**
- [ ] GoSHIP staging account created
- [ ] Test API credentials obtained (gs_test_xxx)
- [ ] .env file updated with staging URL
- [ ] Test connection successful
- [ ] Mock fallback verified

### **Demo Preparation:**
- [ ] Test orders can be created
- [ ] Tracking simulation works
- [ ] Admin dashboard shows test data
- [ ] Error handling tested
- [ ] Documentation reviewed

### **Demo Scenarios:**
- [ ] Tạo test order → tracking number generated
- [ ] Track test shipment → status updates shown
- [ ] Test API failure → fallback to mock works
- [ ] Admin view → test shipments displayed
- [ ] Customer experience → email notifications work

---

**🎓 Perfect for Learning!** 

Với test setup này, **Happy Pets** có thể demo shipping integration một cách an toàn và học được cách tích hợp API thật mà không lo rủi ro.

## 🆘 Test Support

- **GoSHIP Test Support**: staging-support@goship.io
- **Test Documentation**: https://docs-staging.goship.io
- **Happy Pets Dev**: Xem test comments trong code
- **Test Status**: https://status-staging.goship.io

## 💡 Next Steps sau khi học xong

Nếu sau này muốn chuyển sang production thật:
1. Đăng ký GoSHIP production account
2. Verify business documents
3. Get production API key (gs_live_xxx)
4. Update .env với production URL
5. Test carefully trước khi go live

**Note:** Với test environment, bạn đã học được 90% cách tích hợp thật rồi! 🚀