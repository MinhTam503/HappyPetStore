# 🎯 Test Specific Features - Step by Step

## 🚀 Quick Start (Ngay Lập Tức)

### **1️⃣ Test Cơ Bản Nhất (5 phút)**

```bash
# Step 1: Tạo .env file đơn giản
cd "d:\Subjects\FinalReport\project\pet_shop"
echo USE_GOSHIP=false > .env

# Step 2: Chạy app
flutter run -d chrome

# Step 3: Test workflow cơ bản
```

**Workflow Test:**
1. **Customer**: Mở app → Buy pet → Checkout
2. **Admin**: Mở `/admin` → Orders → Click "Mark as Processing"  
3. **Result**: Tracking number xuất hiện → Email gửi customer

---

## 📱 Test Chi Tiết Từng Feature

### **Feature 1: Order to Shipment Auto-Creation**

**📍 Location**: `lib/presentation/admin/orders_admin.dart` line ~200

**Test Steps:**
```bash
1. Tạo order bất kỳ từ customer side
2. Vào admin orders page
3. Find order với status "Pending"
4. Click button "Mark as Processing"
5. Watch magic happen!
```

**Expected Result:**
```bash
✅ Order status changes: Pending → Processing
✅ Shipment auto-created in background
✅ Tracking number generated (HPS123456789, VTP123456789, etc.)
✅ Email sent to customer
✅ Admin sees shipment trong shipping tab
```

**Debug nếu fail:**
```bash
# Check console logs
F12 → Console → Look for "🚚 Creating shipment for order:"

# Check shipping service
Look for "✅ Shipment created successfully:" message

# Verify .env
Make sure USE_GOSHIP=false in .env file
```

---

### **Feature 2: Tracking System**

**📍 Location**: `lib/presentation/tracking/shipping_tracking_widget.dart`

**Test Steps:**
```bash
1. Get tracking number từ step trước (MOCK_xxxxx)
2. Vào customer side → "Track Order" 
3. Nhập tracking number
4. Xem tracking info
```

**Test Data:**
```bash
# Mock tracking numbers để test (realistic format)
HPS123456789
VTP987654321  
JNT555666777
GHN888999000

# GoSHIP test format (nếu có)
GST_test_123456
```

**Expected Result:**
```bash
✅ Tracking status hiển thị: "pickup_pending"
✅ Tracking history có timeline
✅ Estimated delivery date
✅ Carrier info: "Giao Hàng Nhanh", "Viettel Post", etc.
```

---

### **Feature 3: Admin Shipping Dashboard**

**📍 Location**: `lib/presentation/admin/shipping_management_page.dart`

**Test Steps:**
```bash
1. Login admin account
2. Navigate to "Shipping" tab
3. View all active shipments
4. Test search/filter functions
```

**Expected Result:**
```bash
✅ List all shipments with status
✅ Search by tracking number works  
✅ Filter by status works
✅ Click shipment → detail view
✅ Bulk operations available
```

---

### **Feature 4: Email Notifications**

**📍 Location**: `lib/services/email_service.dart`

**Test Steps:**
```bash
1. Tạo order với email thật của bạn
2. Process order to "Processing"
3. Check email inbox (và spam folder)
```

**Expected Email Content:**
```
Subject: Your Happy Pets order is being shipped!
Body: 
- Order ID: ORDER_xxxxx
- Tracking Number: MOCK_xxxxx  
- Track URL: link to tracking page
- Estimated delivery: date
```

**Debug Email Issues:**
```bash
# Check EmailJS configuration
1. Verify service ID in email_service.dart
2. Check template ID matches
3. Verify public key

# Test email function directly
await EmailService.sendTrackingEmail(...)
```

---

### **Feature 5: Mock vs GoSHIP API Switching**

**📍 Location**: `lib/services/shipping_service.dart`

**Test Switching:**
```bash
# Test 1: Mock API
echo USE_GOSHIP=false > .env
flutter hot restart
# Create shipment → should get MOCK_xxxxx

# Test 2: GoSHIP (fake key)
echo USE_GOSHIP=true >> .env
echo GOSHIP_API_KEY=fake_key >> .env
flutter hot restart  
# Create shipment → should fallback to Mock

# Test 3: GoSHIP (real key - if you have)
# Update .env with real staging key
# Create shipment → should get GST_xxxxx
```

**Expected Behavior:**
```bash
✅ Mock API: Always works, instant response
✅ GoSHIP with fake key: Falls back to Mock
✅ GoSHIP with real key: Returns real tracking  
✅ Environment switching works seamlessly
✅ Tracking numbers: HPS123456789, VTP987654321, etc.
```

---

## 🔍 Advanced Testing

### **Performance Test:**
```bash
# Create 5 orders rapid fire
# Process all 5 to "Processing" 
# Check if all shipments created
# Verify no conflicts or delays
```

### **Error Handling Test:**
```bash
# Test invalid tracking numbers
Track: "INVALID123"
Expected: Error message displayed

# Test network offline
Disconnect internet → create shipment
Expected: Graceful error handling
```

### **Vietnamese Address Test:**
```bash
# Use Vietnamese address with diacritics
Address: "123 Nguyễn Văn Cừ, Phường 4, Quận 5, TP.HCM"
Expected: System handles correctly
```

---

## 📊 Test Results Checklist

### **Basic Functionality ✅**
- [ ] Orders create shipments automatically
- [ ] Tracking numbers generated correctly
- [ ] Email notifications sent
- [ ] Admin can view shipments
- [ ] Customer can track orders

### **API Integration ✅**
- [ ] Mock API works offline
- [ ] GoSHIP API integration functional
- [ ] Fallback mechanism works
- [ ] Environment switching seamless
- [ ] Error handling graceful

### **User Experience ✅**
- [ ] Responsive design mobile/desktop
- [ ] Vietnamese text support
- [ ] Loading states appropriate
- [ ] Error messages user-friendly
- [ ] Navigation intuitive

### **Business Logic ✅**
- [ ] Order status workflow correct
- [ ] Shipping costs calculated
- [ ] Delivery estimates reasonable
- [ ] Multiple carriers supported
- [ ] COD functionality working

---

## 🎯 Demo Script

**Cho Teacher/Reviewer:**

```bash
1. "Đây là pet store app với shipping integration"
2. "Customer đặt hàng" → Demo order process
3. "Admin xử lý đơn hàng" → Show admin dashboard  
4. "System tự động tạo shipment" → Click "Mark as Processing"
5. "Customer nhận thông báo tracking" → Show email
6. "Theo dõi đơn hàng real-time" → Demo tracking
7. "API integration với fallback" → Show .env switching
8. "Mobile responsive" → Test on phone view
```

**Key Points để Mention:**
- Real API integration (GoSHIP)
- Automatic fallback system
- Professional admin dashboard
- Email notification system
- Vietnamese market focused
- Production-ready architecture

---

## 🐛 Common Issues & Solutions

### **Issue: "Shipment not created"**
```bash
Solution:
1. Check order status = "Processing"
2. Verify .env file exists
3. Check console for errors
4. Try with USE_GOSHIP=false first
```

### **Issue: "Email not received"**
```bash
Solution:
1. Check spam folder
2. Verify EmailJS config
3. Test with different email provider
4. Check internet connection
```

### **Issue: "Tracking not working"**
```bash
Solution:  
1. Verify tracking number format
2. Check if shipment was created
3. Try with different tracking number
4. Refresh page/app
```

### **Issue: "Admin dashboard blank"**
```bash
Solution:
1. Create some test orders first
2. Process orders to generate shipments
3. Clear browser cache
4. Check admin authentication
```

---

## 🚀 Next Level Testing

Sau khi basic tests pass:

1. **Setup real GoSHIP staging account**
2. **Test with real API credentials**  
3. **Compare Mock vs GoSHIP performance**
4. **Test webhook integration (advanced)**
5. **Load testing với multiple orders**

**Goal**: Demonstrate professional shipping system ready for production scaling.

---

**💡 Pro Tip**: Start simple với Mock API, sau đó gradually move to real API. Điều này cho phép debug issues step by step thay vì overwhelm với complexity.