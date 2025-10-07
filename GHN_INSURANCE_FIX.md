# GHN Insurance Value Limit Fix

## 📋 Problem Summary
GHN API was rejecting order creation with error:
```
"Giá trị khai giá vượt quá mức cho phép: 5000000"
```

This occurred because orders with total value > 5M VNĐ exceeded GHN's insurance value limit.

## 🔧 Solution Implemented

### 1. Orders Admin (Web) - `orders_admin.dart`
```dart
// Added insurance value limiter method
double _limitInsuranceValue(double value) {
  const maxInsuranceValue = 5000000.0; // 5M VND limit
  return value > maxInsuranceValue ? maxInsuranceValue : value;
}

// Applied limit in onChangeStatus callback
totalValue: _limitInsuranceValue(double.tryParse(total.replaceAll('\$', '')) ?? 0),
```

### 2. Shipping Service - `shipping_service.dart`
```dart
// Added static insurance value limiter
static double? _limitInsuranceValue(double? value) {
  if (value == null) return null;
  const maxInsuranceValue = 5000000.0; // 5M VND limit
  return value > maxInsuranceValue ? maxInsuranceValue : value;
}

// Applied limit in GHN order creation
insuranceValue: _limitInsuranceValue(totalValue)?.toInt(),
```

## ✅ Fixed Issues

1. **GHN Order Creation Failures**: Now caps insurance value at 5M VNĐ maximum
2. **Widget Lifecycle Errors**: Continued improvements with mounted checks
3. **Data Type Safety**: Maintains safe conversion with _safeWeight()

## 🚀 Testing Status

- ✅ **Build Success**: Flutter web builds without errors
- ✅ **Compilation**: No static analysis errors
- ✅ **Integration**: Both admin web and mobile cart now use capped insurance

## 📝 Next Steps

1. Test GHN order creation with high-value orders (>5M VNĐ)
2. Verify insurance value is properly capped in API requests
3. Monitor for any remaining widget deactivation errors
4. Check phone number extraction consistency

## 🔍 Log Monitoring

Watch for these log messages:
```
📦 GHN Insurance capped: [original] → 5000000
✅ GHN Order created successfully
```

## 💡 Business Impact

- High-value orders (pets >5M VNĐ) can now be shipped via GHN
- Insurance coverage limited to GHN's maximum but orders proceed
- No impact on shipping functionality or customer experience