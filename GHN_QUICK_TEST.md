# 🚀 GHN Quick Test Guide

## ⚡ Immediate Testing Steps

### 1. **Access GHN Test Page**
```
http://localhost:port/#/admin 
→ Login as admin
→ Navigate to "GHN Test" tab (bug icon)
```

### 2. **Run Test Sequence**
```
1. Click "Test Connection" ✅
   - Should show: "Kết nối GHN API thành công!"
   - Shows provinces count

2. Click "Get Provinces" ✅  
   - Should list Vietnamese provinces
   - Shows first 5 as example

3. Click "Create Shipment" ✅
   - Creates real GHN shipment
   - Returns tracking number
   - Stores for tracking test

4. Click "Track Shipment" ✅
   - Tracks the shipment just created
   - Shows current status
```

## 🔧 Expected Results

### ✅ Success Scenario:
```
🧪 GHN Test Page initialized
✅ Connection successful!
📊 Token: 07b708bf-...
🏪 Shop ID: 197574
🌍 Provinces available: 63
✅ Shipment created successfully!
📦 Tracking Number: L8MAWXQB
🚚 Company: Giao Hàng Nhanh
💰 Shipping Fee: 22000 VNĐ
🔧 Provider: ghn
✅ Tracking successful!
📊 Status: pickup_pending
```

### ❌ Fallback Scenario (if GHN fails):
```
⚠️ GHN failed, falling back to mock
📦 Using shipping provider: mock
✅ Mock shipment created: HPS722970881
```

## 🐛 Troubleshooting

### Issue: "GHN credentials missing"
**Solution:** 
- Web app uses hardcoded test credentials
- Should auto-fallback to GHN test credentials
- Check browser console for debug logs

### Issue: "Connection failed"
**Solution:**
```bash
# Check network
ping dev-online-gateway.ghn.vn

# Check credentials in GHN service
# File: lib/services/ghn_service.dart
# Look for: _getCredentials() method
```

### Issue: "Provider shows mock instead of ghn"
**Solution:**
- Web mode defaults to GHN
- Check shipping_service.dart _currentProvider getter
- Look for: "🌐 Web mode: Using GHN provider"

## 📱 Mobile Testing

For mobile testing with .env file:
```bash
# Update .env
SHIPPING_PROVIDER=ghn

# Restart app
flutter hot restart

# Test same flow in mobile
```

## 🔍 Debug Console Logs

Look for these patterns in browser dev tools:
```
🌐 Using hardcoded GHN credentials for web
📱 Web mode: Using GHN provider  
🧪 Testing GHN connection...
🔑 Token: 07b708bf-...
🏪 Shop ID: 197574
🚚 Creating GHN shipment for order: GHN_TEST_xxx
✅ GHN shipment created: L8MAWXQB
```

## 🎯 Test Data

### Default Locations:
- **From**: Quận 1, TP.HCM (ID: 1463)
- **To**: Test address in HCMC
- **Weight**: 2kg
- **Dimensions**: 30x30x20 cm

### Expected Fees:
- **Standard delivery**: ~22,000 VNĐ
- **Express delivery**: ~35,000 VNĐ

## ✅ Verification Checklist

- [ ] GHN Test page loads without errors
- [ ] Test Connection returns success
- [ ] Provinces list shows 63 items
- [ ] Create Shipment returns real GHN tracking number
- [ ] Track Shipment shows status and history
- [ ] No console errors in browser dev tools
- [ ] Provider shows "ghn" not "mock"

## 🚀 Next Steps

After successful testing:
1. **Production Orders**: Normal order flow will auto-use GHN
2. **Real Tracking**: Customer orders get real GHN tracking
3. **Fee Calculation**: Accurate shipping fees from GHN
4. **Status Updates**: Real-time shipping status from GHN

---

## 🎉 Success Criteria

**GHN integration is working when:**
- ✅ All 4 test buttons return success
- ✅ Real tracking numbers generated (format: L8MAWXQB)
- ✅ Provider shows "ghn" 
- ✅ Shipping fees show real VNĐ amounts
- ✅ No error messages in console

**Ready for production! 🚀**