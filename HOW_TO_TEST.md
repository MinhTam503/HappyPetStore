# 🧪 Hướng Dẫn Test Shipping - Từng Bước

## 🎯 Mục Tiêu
Hiểu luồng hoạt động và test shipping system của Happy Pets một cách đơn giản.

## 📚 Luồng Hoạt động Tổng Quan

```
👤 Customer đặt hàng → 👨‍💼 Admin xử lý → 🚚 Tạo shipment → 📱 Customer track → ✅ Giao hàng
```

**Chi Tiết:**
1. **Customer**: Đặt hàng pet (chó, mèo, thức ăn...)
2. **Admin**: Vào admin page, chuyển order status từ "Pending" → "Processing"
3. **System**: Tự động tạo shipment với GoSHIP/Mock API
4. **Customer**: Nhận email với tracking number, có thể track đơn hàng
5. **Delivery**: Theo dõi trạng thái giao hàng real-time

---

## 🚀 Test Ngay - Không Cần Setup Phức Tạp

### **Option 1: Test với Mock API (Recommended để bắt đầu)**

#### **Bước 1: Setup Mock API (30 giây)**
```bash
# Tạo file .env trong project root
cd "d:\Subjects\FinalReport\project\pet_shop"
echo "USE_GOSHIP=false" > .env
```

#### **Bước 2: Chạy App**
```bash
flutter run -d chrome
```

#### **Bước 3: Test Workflow**

**3.1 - Tạo Order (Customer Side):**
1. Vào app → Login (tạo account mới nếu cần)
2. Chọn pet bất kỳ → Add to cart
3. Checkout → Nhập địa chỉ giao hàng
4. Place order → Lưu lại Order ID

**3.2 - Admin Xử Lý (Admin Side):**
```bash
# Mở tab mới, vào admin
http://localhost:xxxxx/admin
```
1. Login admin account
2. Vào "Orders Management"
3. Tìm order vừa tạo
4. **Quan trọng**: Click "Mark as Processing"
5. **Magic happens**: System tự động tạo shipment!

**3.3 - Tracking (Customer Side):**
1. Check email → sẽ có tracking number
2. Hoặc vào app → "My Orders" → Track
3. Xem shipping status updates

#### **Bước 4: Verify Results**
```bash
✅ Order status: Pending → Processing
✅ Shipment created: Tracking number MOCK_xxxxx
✅ Email sent: Customer nhận tracking info
✅ Tracking works: Status progression hiển thị
✅ Admin view: Shipping tab có data
```

---

## 🌟 Test với GoSHIP API (Nâng Cao)

### **Bước 1: Register GoSHIP Test Account**
1. Vào: https://sandbox.goship.io/ (hoặc tìm GoSHIP staging)
2. Đăng ký account test
3. Lấy API key có format: `gs_test_xxxxx`

### **Bước 2: Update .env**
```env
USE_GOSHIP=true
GOSHIP_BASE_URL=https://api-staging.goship.io
GOSHIP_API_KEY=gs_test_your_real_key_here
STORE_NAME=Happy Pets Store (Test)
STORE_ADDRESS=123 Test Street, Thủ Đức, TP.HCM
STORE_PHONE=0123456789
STORE_EMAIL=test@happypets.com
```

### **Bước 3: Test Same Workflow**
- Làm giống hệt Mock API test
- Khác biệt: Tracking number sẽ là format GoSHIP thật
- API response time sẽ slower hơn Mock

---

## 🔍 Debug và Troubleshoot

### **Nếu App Không Chạy:**
```bash
# Check dependencies
flutter pub get

# Check errors
flutter doctor

# Run with verbose
flutter run -v
```

### **Nếu Shipping Không Hoạt Động:**

**Check 1: .env file**
```bash
# Verify .env exists
ls -la .env

# Check content
cat .env
```

**Check 2: Order Status**
```bash
# Order phải ở status "Processing" mới tạo shipment
# Admin phải click "Mark as Processing"
```

**Check 3: Console Logs**
```bash
# Mở browser dev tools → Console
# Look for shipping-related logs
```

### **Nếu Email Không Gửi:**
```bash
# Email system dùng EmailJS
# Check spam folder
# Verify email service trong EmailJS dashboard
```

---

## 📱 Test Cases chi tiết

### **Test Case 1: Happy Path**
```bash
1. Customer đặt hàng chó Golden Retriever
2. Admin mark as Processing
3. System tạo shipment successful
4. Customer nhận email tracking
5. Track cho thấy "pickup_pending"
6. Status progression: pickup → transit → delivery
```

### **Test Case 2: Mock API Fallback**
```bash
1. Set USE_GOSHIP=true với invalid API key
2. Tạo order và process
3. Should fallback to Mock API
4. Tracking vẫn hoạt động bình thường
```

### **Test Case 3: Multiple Orders**
```bash
1. Tạo 3-5 orders liên tiếp
2. Process tất cả orders
3. Check admin shipping management
4. Verify mỗi order có unique tracking
```

### **Test Case 4: Vietnamese Address**
```bash
1. Dùng địa chỉ có dấu: "Nguyễn Văn Cừ, Quận 5, TP.HCM"
2. Verify system handle correctly
3. Check tracking email format
```

---

## 📊 Expected Results

### **Mock API Results:**
```json
{
  "success": true,
  "data": {
    "trackingNumber": "MOCK_1696588800123",
    "carrier": "Mock Shipping",
    "status": "pickup_pending",
    "estimatedDelivery": "2024-10-08T00:00:00Z"
  }
}
```

### **GoSHIP API Results:**
```json
{
  "success": true,
  "data": {
    "trackingNumber": "GST_789123456",
    "carrier": "GoSHIP Express",
    "status": "pickup_pending", 
    "estimatedDelivery": "2024-10-08T00:00:00Z"
  }
}
```

---

## 🎯 Key Features để Test

### **1. Shipping Integration**
- [ ] Order tạo shipment khi status = "Processing"
- [ ] Tracking number được generate
- [ ] Email notification gửi customer
- [ ] Admin có thể view all shipments

### **2. Tracking System**
- [ ] Customer track bằng tracking number
- [ ] Status updates hiển thị correctly
- [ ] Tracking history chronological
- [ ] Mobile responsive tracking page

### **3. Admin Management**  
- [ ] Admin dashboard có shipping tab
- [ ] View all active shipments
- [ ] Search/filter shipments
- [ ] Bulk operations

### **4. Error Handling**
- [ ] GoSHIP API down → fallback to Mock
- [ ] Invalid tracking number → error message
- [ ] Network timeout → retry mechanism
- [ ] User-friendly error messages

---

## 🎉 Success Criteria

Sau khi test xong, bạn sẽ có:

**✅ Demo-Ready Shipping System:**
- Orders automatically create shipments
- Real-time tracking functionality  
- Professional admin dashboard
- Email notifications working
- Mobile-friendly interface

**✅ Technical Understanding:**
- Hybrid API system (GoSHIP + Mock)
- Environment-based configuration
- Error handling và fallback
- Vietnamese address support
- Email integration với EmailJS

**✅ Portfolio Value:**
- Professional shipping integration
- Real API consumption
- Modern Flutter architecture
- Production-ready error handling
- Complete user experience

---

## 🆘 Nếu Stuck ở Đâu

### **Quick Fixes:**
```bash
# Reset everything
rm .env
echo "USE_GOSHIP=false" > .env
flutter clean
flutter pub get
flutter run

# Check specific features
# → Vào HOW_TO_TEST_SPECIFIC.md (sẽ tạo tiếp)
```

### **Contact:**
- Check code comments trong `/lib/services/`
- Review console logs trong browser
- Compare với TESTING_GUIDE.md cho advanced scenarios

**🚀 Ready to test!** Bắt đầu với Mock API trước, sau đó nâng cấp lên GoSHIP khi cần.