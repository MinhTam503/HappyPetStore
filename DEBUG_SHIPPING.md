# 🐛 Quick Debug Test

Để test shipping integration ngay lập tức, làm theo steps:

## 🚀 Test Workflow

### **1. Check Current Environment:**
```bash
# Kiểm tra .env file
cat .env
# Phải có: USE_GOSHIP=false
```

### **2. Run Debug Test:**
1. **Mở browser dev tools** (F12 → Console)
2. **Reload page** 
3. **Login admin**
4. **Tạo order mới hoặc use existing order**
5. **Click "Mark as Processing"**
6. **Xem console logs:**

**Expected logs:**
```
🚚 Creating shipment for order: [OrderID]
📊 Use GoSHIP: false
🚚 Creating mock shipment for order: [OrderID]
✅ Mock shipment created: MOCK_xxxxx
Đã tạo đơn giao hàng: MOCK_xxxxx
```

### **3. Check Results:**
1. **Snackbar message** phải hiện: "Đã tạo đơn giao hàng: MOCK_xxxxx"
2. **Shipping tab** phải có data mới
3. **Order** phải có trackingNumber trong Firebase

## 🔧 Common Issues

### **Issue 1: "Lỗi tạo đơn giao hàng"**
```bash
# Fix: Check if items parameter is provided
# Should have: items: [{'name': '...', 'quantity': 1, ...}]
```

### **Issue 2: Console shows errors about totalValue**
```bash
# Fix: Check if total parsing works
# Should parse: "$45" → 45.0
```

### **Issue 3: No shipment in shipping tab**
```bash
# Cause: Shipment created but not saved to Firebase
# Fix: Check updateOrder call after shipment creation
```

### **Issue 4: Environment not loaded**
```bash
# Check: dotenv.env['USE_GOSHIP'] returns value
# Fix: Restart app after changing .env
```

## 🎯 Immediate Test Commands

```bash
# Test 1: Quick mock test
echo "USE_GOSHIP=false" > .env
flutter hot restart

# Test 2: Test with console logging
# Open Dev Tools → Console → Process order → Watch logs

# Test 3: Check shipping service directly
# Add to shipping_service.dart temporarily:
print('🔍 Environment loaded: ${dotenv.env}');
print('🔍 USE_GOSHIP value: ${dotenv.env['USE_GOSHIP']}');
```

## 📋 Test Checklist

- [ ] .env file has USE_GOSHIP=false
- [ ] App restarted after .env change
- [ ] Console logs show shipment creation
- [ ] Snackbar shows success message
- [ ] Shipping tab has new data
- [ ] No red error messages
- [ ] Order has trackingNumber field

## 🆘 If Still Not Working

1. **Add debug prints** trong orders_admin.dart:
```dart
print('🔍 Order ID: $orderId');
print('🔍 Address: $address');
print('🔍 Total: $total');
print('🔍 New Status: $newStatus');
```

2. **Check Firebase rules** - đảm bảo admin có quyền update orders

3. **Restart Flutter app completely**:
```bash
flutter clean
flutter pub get  
flutter run -d chrome
```

---

**💡 Tip:** Nếu vẫn không work, copy full console log và paste để tôi debug further.