# 🎉 Màn hình Get Started - Hướng dẫn sử dụng

## ✅ Đã hoàn thành

Màn hình GetStarted đã được tích hợp thành công vào ứng dụng với các tính năng:

### Tính năng đã triển khai:
1. ✅ **3 trang onboarding** với nội dung đa ngôn ngữ (Tiếng Việt/English)
2. ✅ **Nút "Bỏ qua"** để người dùng có thể bỏ qua onboarding
3. ✅ **Nút "Tiếp theo"** và **"Bắt đầu"** để điều hướng
4. ✅ **Page indicators** hiển thị tiến trình
5. ✅ **Chỉ hiển thị lần đầu** mở app (lưu trạng thái với SharedPreferences)
6. ✅ **Tự động lấy ngôn ngữ máy** làm ngôn ngữ mặc định
7. ✅ **Giao diện đẹp mắt, đồng bộ** với màu sắc chủ đề app

### Nội dung 3 trang:

#### Trang 1: Chào mừng
- **Tiếng Việt**: "Chào mừng đến Happy Pet Shop"
- **English**: "Welcome to Happy Pet Shop"
- Màu nền: Cam nhạt (#FFF3E0)

#### Trang 2: Tìm kiếm & Lựa chọn
- **Tiếng Việt**: "Dễ dàng tìm kiếm & Lựa chọn"
- **English**: "Easy Search & Selection"
- Màu nền: Xanh dương nhạt (#E3F2FD)

#### Trang 3: Mua sắm An toàn
- **Tiếng Việt**: "Mua sắm An toàn & Tiện lợi"
- **English**: "Safe & Convenient Shopping"
- Màu nền: Tím nhạt (#F3E5F5)

## 📁 Files đã tạo

1. **lib/presentation/pages/mobile/get_started/get_started_page.dart**
   - Widget chính cho màn hình GetStarted
   - PageView với 3 trang cuộn ngang
   - Logic điều hướng và lưu trạng thái

2. **lib/core/services/onboarding_service.dart**
   - Service quản lý trạng thái onboarding
   - Sử dụng SharedPreferences để lưu trữ
   - Methods: `hasSeenGetStarted()`, `setHasSeenGetStarted()`, `resetOnboarding()`

3. **lib/core/localization/l10n/app_vi.arb** (đã cập nhật)
   - Thêm các key localization cho tiếng Việt

4. **lib/core/localization/l10n/app_en.arb** (đã cập nhật)
   - Thêm các key localization cho tiếng Anh

5. **lib/main.dart** (đã cập nhật)
   - Tích hợp logic kiểm tra lần đầu mở app
   - Hiển thị GetStartedPage khi chưa xem onboarding

## 🖼️ Hình ảnh (Cần thêm)

Để hiển thị hình ảnh đầy đủ, vui lòng thêm 3 file PNG vào thư mục `assets/images/`:

1. **onboarding1.png** (800x800px) - Hình chào mừng
2. **onboarding2.png** (800x800px) - Hình tìm kiếm/lựa chọn
3. **onboarding3.png** (800x800px) - Hình mua sắm/giao hàng

> 💡 **Lưu ý**: Nếu không có hình, app sẽ tự động hiển thị icon pets mặc định (không gây lỗi).

Xem chi tiết tại: `assets/images/ONBOARDING_IMAGES_README.md`

## 🚀 Cách kiểm tra

### 1. Chạy app lần đầu
```bash
flutter run
```
- App sẽ hiển thị màn hình GetStarted với 3 trang
- Bạn có thể cuộn hoặc nhấn "Tiếp theo"
- Nhấn "Bỏ qua" hoặc "Bắt đầu" để vào app

### 2. Chạy app lần sau
- App sẽ KHÔNG hiển thị GetStarted nữa
- Chuyển thẳng đến màn hình đăng nhập/trang chủ

### 3. Reset onboarding (để test lại)
Để xem lại màn hình GetStarted, có 2 cách:

**Cách 1: Xóa data app**
```bash
# Android
flutter run --clear-app-data

# iOS
flutter clean
flutter run
```

**Cách 2: Sử dụng code** (thêm vào một nút nào đó)
```dart
import 'package:pet_shop/core/services/onboarding_service.dart';

// Trong một button hoặc menu
await OnboardingService.resetOnboarding();
// Sau đó restart app
```

## 🎨 Tùy chỉnh

### Thay đổi màu sắc
Sửa trong `get_started_page.dart`:
```dart
OnboardingContent(
  title: l10n.getStartedTitle1,
  description: l10n.getStartedDesc1,
  image: 'assets/images/onboarding1.png',
  backgroundColor: const Color(0xFFFFF3E0), // <- Đổi màu tại đây
),
```

### Thêm/bớt trang
Trong `get_started_page.dart`, sửa list `contents`:
```dart
final List<OnboardingContent> contents = [
  // Thêm hoặc xóa OnboardingContent tại đây
];
```

### Thay đổi text
Sửa trong `app_vi.arb` hoặc `app_en.arb`:
```json
"getStartedTitle1": "Tiêu đề mới",
"getStartedDesc1": "Mô tả mới"
```

## 🐛 Troubleshooting

### Lỗi: Hình không hiển thị
- Kiểm tra file hình đã đặt đúng đường dẫn `assets/images/onboardingX.png`
- Chạy `flutter clean && flutter pub get`
- Nếu vẫn không có hình, app sẽ hiển thị icon pets (không lỗi)

### Lỗi: Onboarding vẫn hiện mỗi lần mở app
- Kiểm tra `SharedPreferences` có hoạt động không
- Thử xóa app và cài lại
- Kiểm tra log: `await OnboardingService.hasSeenGetStarted()` trả về gì

### Lỗi: Ngôn ngữ không đúng
- Ngôn ngữ tự động lấy từ cài đặt máy
- Có thể thay đổi trong Settings của app
- Kiểm tra `LocaleProvider` có hoạt động đúng không

## 📱 Screenshots Demo

Màn hình sẽ trông như thế này:

```
┌─────────────────────┐
│     [Bỏ qua]       │  <- Nút skip ở góc phải
│                     │
│   ┌─────────────┐   │
│   │             │   │
│   │   [Hình 1]  │   │  <- Hình ảnh onboarding
│   │             │   │
│   └─────────────┘   │
│                     │
│  Chào mừng đến...   │  <- Tiêu đề
│                     │
│  Khám phá thế giới  │  <- Mô tả
│  thú cưng...        │
│                     │
│     ● ○ ○           │  <- Page indicators
│                     │
│  ┌───────────────┐  │
│  │  Tiếp theo ►  │  │  <- Nút next/get started
│  └───────────────┘  │
└─────────────────────┘
```

## 🎯 Luồng hoạt động

```
Mở app lần đầu
    ↓
Kiểm tra hasSeenGetStarted
    ↓
false → Hiển thị GetStartedPage
    ↓
User xem 3 trang hoặc nhấn "Bỏ qua"
    ↓
Lưu hasSeenGetStarted = true
    ↓
Chuyển đến màn hình đăng nhập/trang chủ
    ↓
Lần sau mở app → Bỏ qua GetStarted
```

## 🔧 API Reference

### OnboardingService

```dart
// Kiểm tra đã xem onboarding chưa
Future<bool> hasSeenGetStarted()

// Đánh dấu đã xem
Future<void> setHasSeenGetStarted()

// Reset (dùng cho testing)
Future<void> resetOnboarding()
```

## ✨ Kết luận

Màn hình GetStarted đã hoàn thiện 100% với tất cả tính năng yêu cầu:
- ✅ Hiển thị lần đầu mở app
- ✅ Đa ngôn ngữ tự động
- ✅ 3 trang cuộn ngang
- ✅ Nút bỏ qua
- ✅ Giao diện đẹp mắt

**Chỉ cần thêm 3 hình ảnh vào `assets/images/` để hoàn thiện 100%!** 🎉
