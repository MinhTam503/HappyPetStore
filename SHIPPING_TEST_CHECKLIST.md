# ✅ Shipping System Test Checklist

## 📦 Test Scenarios

### 1. Cart Screen - Tạo Đơn Hàng Mới
```
[ ] Thêm sản phẩm vào giỏ hàng
[ ] Chọn địa chỉ giao hàng
[ ] Tính phí ship tự động (calculateShippingFee)
[ ] Tạo đơn hàng với payment (Stripe/PayPal)
[ ] Tạo đơn hàng COD
[ ] Kiểm tra Firebase order structure:
    - shippingAddress exists
    - customerInfo exists
    - deliveryInfo exists
    - NO duplicate 'address' field
    - NO 'shippingInfo' field
    - trackingNumber created
    - shippingCompany saved
```

### 2. Your Order Screen - Xem Đơn Hàng
```
[ ] Hiển thị danh sách orders
[ ] Filter by status (All/Pending/Processing/Shipped/Completed)
[ ] Sort by date (newest/oldest)
[ ] Click vào order → Mở order details
[ ] Order details hiển thị:
    - Customer name & phone từ customerInfo
    - Shipping address đúng format
    - Total amount = subtotal + shippingFee
    - Tracking number (nếu có)
[ ] ShippingTrackingWidget hiển thị khi có trackingNumber:
    - Tracking history
    - Current status
    - Estimated delivery
```

### 3. Shipping Management (Admin)
```
[ ] Load all shipments from Firebase
[ ] Search by tracking number
[ ] Search by order ID
[ ] Filter by status (pickup_pending/in_transit/delivered/etc)
[ ] Click shipment → Mở tracking details
[ ] Update status → Save to Firebase
[ ] Refresh → Data updates correctly
```

### 4. ShippingService Integration
```
[ ] GHN provider works (when SHIPPING_PROVIDER=ghn)
[ ] Mock provider works (when SHIPPING_PROVIDER=mock)
[ ] createShipment returns tracking number
[ ] trackShipment returns status & history
[ ] calculateShippingFee returns fee
[ ] getAllShipments returns all orders with tracking
[ ] updateShipmentStatus updates Firebase & notifies user
```

### 5. Backward Compatibility
```
[ ] Old orders (có 'address' field) vẫn hiển thị đúng
[ ] Old orders (có 'shippingInfo') vẫn đọc được
[ ] Migration không break existing data
```

## 🐛 Debug Commands

### Check Firebase Order Structure
```dart
print('📦 Order Fields:');
print('  - shippingAddress: ${orderData['shippingAddress']}');
print('  - customerInfo: ${orderData['customerInfo']}');
print('  - deliveryInfo: ${orderData['deliveryInfo']}');
print('  - trackingNumber: ${orderData['trackingNumber']}');
print('  - subtotal: ${orderData['subtotal']}');
print('  - shippingFee: ${orderData['shippingFee']}');
print('  - totalAmount: ${orderData['totalAmount']}');
```

### Check Shipping Service
```dart
// Test calculate fee
final result = await ShippingService.calculateShippingFee(
  shippingAddress: 'Test Address',
  totalValue: 500000,
  totalWeight: 2.0,
  customerInfo: {'name': 'Test', 'phone': '0987654321'},
);
print('💰 Shipping fee: ${result['data']['shippingFee']}');

// Test create shipment
final shipment = await ShippingService.createShipment(
  orderId: 'test_order',
  shippingAddress: 'Test Address',
  customerInfo: {'name': 'Test', 'phone': '0987654321', 'email': 'test@test.com'},
  totalWeight: 2.0,
  totalValue: 500000,
);
print('🚚 Tracking: ${shipment['data']['trackingNumber']}');

// Test track
final tracking = await ShippingService.trackShipment('HPS123456789');
print('📍 Status: ${tracking['data']['status']}');
```

## ✅ Success Criteria

### Data Structure
- ✅ No duplicate fields (address vs shippingAddress)
- ✅ No duplicate structures (shippingInfo vs customerInfo+deliveryInfo)
- ✅ Single source of truth for customer data
- ✅ Consistent field names across all orders

### Functionality
- ✅ Orders created with correct structure
- ✅ Tracking numbers generated
- ✅ Shipping status updates
- ✅ Real-time tracking works
- ✅ Admin can manage all shipments

### User Experience
- ✅ Address displays correctly
- ✅ Phone numbers show properly
- ✅ Tracking widget loads fast
- ✅ Status updates in real-time
- ✅ No broken old orders

### Developer Experience
- ✅ Clear log messages
- ✅ Easy to debug
- ✅ Well-documented code
- ✅ Backward compatible

## 🚨 Common Issues & Solutions

### Issue 1: "Tracking number not found"
**Cause**: Order created before refactoring, no trackingNumber field
**Solution**: Backward compatible - ShippingTrackingWidget handles gracefully

### Issue 2: "Address not displaying"
**Cause**: Reading wrong field name
**Solution**: Use fallback chain: shippingAddress → deliveryInfo → address

### Issue 3: "Phone number missing"
**Cause**: Not reading from customerInfo
**Solution**: Priority: customerInfo.phone → phone → deliveryInfo.phone

### Issue 4: "Duplicate data in Firebase"
**Cause**: Old code still writing shippingInfo
**Solution**: Fixed - only write customerInfo + deliveryInfo now

## 📊 Test Results Log

```
Date: _________
Tester: _________

[ ] All cart operations work
[ ] Order details display correctly  
[ ] Tracking widget functional
[ ] Admin management works
[ ] No console errors
[ ] Firebase structure correct

Notes:
_________________________________
_________________________________
_________________________________
```

## 🎯 Performance Checks

- [ ] Order creation < 3 seconds
- [ ] Tracking load < 2 seconds
- [ ] Admin list load < 5 seconds
- [ ] No memory leaks
- [ ] Smooth scrolling in order list

## 🔐 Security Checks

- [ ] User can only see their orders
- [ ] Admin can see all orders
- [ ] Tracking numbers are unique
- [ ] No sensitive data in logs
- [ ] Firebase rules enforced
