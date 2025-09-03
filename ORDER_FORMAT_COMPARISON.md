# 📊 Order Data Format Comparison

## 🔄 **Before vs After Update**

### ❌ **Before (Web) - Inconsistent Format:**
```json
{
  "orderId": "abc123",
  "email": "user@example.com",
  "customerName": "John Doe",  // ❌ Different field name
  "phone": "123456789",
  "address": "123 Street",
  "totalAmount": 50,
  "statusPayment": "Payment Completed",
  "statusOrder": "Pending",
  "timestamp": "2025-08-29...",
  "paymentMethod": "stripe",    // ❌ Different value
  "stripeSessionId": "sess_123", // ❌ Different field name
  "items": [...]
}
```

### ✅ **After (Web) - Consistent with Mobile:**
```json
{
  "orderId": "yEp2NJxDNGiFjgD89zkv",
  "email": "user@example.com",
  "fullName": "t",                               // ✅ Matches mobile format
  "phone": "091234567",
  "address": "ac",                               // ✅ Matches mobile format
  "totalAmount": 50,
  "statusPayment": "Payment Completed",
  "statusOrder": "Completed",                    // ✅ Auto-complete if paid
  "timestamp": "29 August 2025 at 01:34:48 UTC+7",
  "paymentMethod": "stripe_web_demo",            // ✅ Specific web identifier
  "paymentIntentId": "pi_3S1AenK5lhkPHodu0krkdHzR", // ✅ Stripe payment intent
  "backendOrderId": "web_demo_1756406101767",    // ✅ Backend tracking ID
  "items": [
    {
      "productId": "1729250415537",
      "name": "Ca vang",
      "breed": "Cá vàng",
      "imageUrl": "https://firebasestorage...",
      "price": "5",                              // ✅ String format like mobile
      "quantity": 1                              // ✅ Number format
    }
  ]
}
```

### 📱 **Mobile Format (Reference):**
```json
{
  "orderId": "mobile123",
  "email": "user@example.com", 
  "phone": "091234567",
  "totalAmount": 185,
  "statusPayment": "Payment Completed",
  "statusOrder": "Pending",
  "timestamp": "...",
  "paymentMethod": "paypal",
  "shippingAddress": "123 Street",  // Mobile uses 'shippingAddress'
  "items": [
    {
      "productId": "pet123",
      "name": "Pet Name",
      "breed": "Pet Breed", 
      "price": "185",                // String format
      "quantity": 1
    }
  ]
}
```

---

## 🎯 **Key Changes Made:**

### 1. **Field Name Consistency:**
- ✅ `customerName` → `fullName`
- ✅ `stripeSessionId` → `paymentIntentId`

### 2. **Payment Method Specificity:**
- ✅ `"stripe"` → `"stripe_web_demo"`

### 3. **Status Logic:**
- ✅ Auto-complete order if payment successful
- ✅ `statusOrder: "Completed"` when paid

### 4. **Additional Fields:**
- ✅ Added `backendOrderId` for tracking
- ✅ Added `paymentIntentId` for Stripe reference

### 5. **Item Structure:**
- ✅ Clean item format with required fields only
- ✅ Price as string (consistent with mobile)
- ✅ Proper breed and imageUrl handling

### 6. **Pet Status Update:**
- ✅ Mark pets as sold after successful payment
- ✅ Set `isAvailable: false`

---

## 🔍 **Collection Strategy:**

| Platform | Collection | Purpose |
|----------|------------|---------|
| 📱 Mobile | `orders` | Mobile app orders |
| 🌐 Web | `ordersWeb` | Web app orders |
| 👨‍💼 Admin | Both | View all orders |

---

## ✅ **Verification Steps:**

1. **Test Web Checkout:** Place an order on web
2. **Check ordersWeb Collection:** Verify data format
3. **Compare with Mobile:** Ensure consistency
4. **Admin Panel:** Confirm both collections visible
5. **Pet Status:** Verify pets marked as sold

---

*Updated: September 3, 2025*
