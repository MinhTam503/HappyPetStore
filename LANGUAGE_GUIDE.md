# Hướng dẫn sử dụng tính năng đổi ngôn ngữ (Language Switching)

## Tổng quan

Ứng dụng Pet Shop hiện đã hỗ trợ đầy đủ tính năng đổi ngôn ngữ trên cả Mobile App và Web Admin với 2 ngôn ngữ:
- **Tiếng Việt (vi)** - Mặc định
- **English (en)**

## Cách sử dụng

### Mobile App

1. **Truy cập Settings:**
   - Mở ứng dụng mobile
   - Vào tab Settings (Cài đặt)

2. **Đổi ngôn ngữ:**
   - Tìm mục "Ngôn ngữ" / "Language"
   - Chọn ngôn ngữ mong muốn:
     - 🇻🇳 Tiếng Việt (Vietnamese)
     - 🇺🇸 English (English US)

3. **Xác nhận thay đổi:**
   - Ứng dụng sẽ tự động thay đổi ngôn ngữ ngay lập tức
   - Hiển thị thông báo xác nhận bằng ngôn ngữ vừa chọn

### Web Admin

1. **Truy cập Language Selector:**
   - Đăng nhập vào Web Admin
   - Tìm biểu tượng ngôn ngữ (🌐) ở góc trên phải Dashboard

2. **Đổi ngôn ngữ:**
   - Click vào biểu tượng ngôn ngữ
   - Chọn ngôn ngữ từ dropdown:
     - English
     - Tiếng Việt

## Tính năng kỹ thuật

### Đồng bộ hóa
- Cài đặt ngôn ngữ được lưu cục bộ trên thiết bị
- Tự động đồng bộ giữa `LocaleProvider` và `SettingsService`
- Giữ nguyên lựa chọn khi restart ứng dụng

### Localization Coverage
- ✅ Tất cả giao diện web admin đã được localize
- ✅ Settings page mobile đã được localize  
- ✅ Thông báo và feedback đã được localize
- ✅ Tên ngôn ngữ hiển thị theo context hiện tại

### Persistence
- **Mobile**: SharedPreferences + SettingsService
- **Web**: SharedPreferences + LocaleProvider
- **Backup**: Cả hai đều có fallback mechanism

## Implementation Details

### Core Components

1. **LocaleProvider** (`lib/core/providers/locale_provider.dart`)
   - Quản lý state ngôn ngữ toàn ứng dụng
   - Tích hợp với SettingsService cho mobile
   - Hỗ trợ persistence với SharedPreferences

2. **SettingsService** (`lib/core/services/settings_service.dart`)
   - Quản lý các cài đặt mobile app
   - Stream-based cho real-time updates
   - Tích hợp với LocaleProvider

3. **LanguageSelector** (`lib/presentation/widgets/language_selector.dart`)
   - Widget đổi ngôn ngữ cho web admin
   - PopupMenu với localized names

### Localization Files
- `lib/core/localization/web/l10n/app_en.arb` - English strings
- `lib/core/localization/web/l10n/app_vi.arb` - Vietnamese strings
- Auto-generated: `.dart_tool/flutter_gen/gen_l10n/` - Generated classes

### Main App Configuration
```dart
// main.dart
locale: localeProvider.locale,
supportedLocales: LocaleProvider.supportedLocales,
localizationsDelegates: [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
],
```

## Test Coverage

Đã có test coverage cho:
- ✅ LocaleProvider initialization
- ✅ Locale changing functionality  
- ✅ Unsupported locale handling
- ✅ Supported locales validation
- ✅ Language names mapping

## Troubleshooting

### Nếu ngôn ngữ không thay đổi:
1. Kiểm tra console logs cho errors
2. Verify LocaleProvider được inject đúng cách
3. Restart ứng dụng nếu cần thiết

### Nếu text không được translate:
1. Kiểm tra `AppLocalizations.of(context)` có null không
2. Verify string key có tồn tại trong .arb files
3. Chạy `flutter gen-l10n` để regenerate

### Nếu setting không persist:
1. Kiểm tra SharedPreferences permissions
2. Verify SettingsService integration
3. Clear app data và test lại

## Future Enhancements

Có thể mở rộng thêm:
- [ ] Thêm ngôn ngữ khác (Japanese, Korean, etc.)
- [ ] Auto-detect device language
- [ ] Regional variants (en-US, en-UK)
- [ ] RTL language support
- [ ] Dynamic language loading