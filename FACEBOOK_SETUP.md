# Hướng dẫn cấu hình Facebook Authentication

## 1. Tạo Facebook App

1. Đi đến [Facebook Developers](https://developers.facebook.com/)
2. Đăng nhập và tạo ứng dụng mới
3. Chọn "Consumer" cho loại ứng dụng
4. Điền thông tin ứng dụng:
   - App Name: "Pet Shop"
   - App Contact Email: your-email@example.com

## 2. Cấu hình Facebook Login

1. Trong Dashboard của Facebook App, thêm sản phẩm "Facebook Login"
2. Chọn "Android" platform
3. Cấu hình Android:
   - Package Name: `com.example.pet_shop`
   - Class Name: `com.example.pet_shop.MainActivity`
   - Key Hashes: Sử dụng debug key hash

## 3. Lấy App ID và Client Token

1. Vào Settings > Basic trong Facebook App Dashboard
2. Copy App ID và App Secret
3. Tạo Client Token trong Settings > Advanced

## 4. Cập nhật Android Configuration

Mở file `android/app/src/main/res/values/strings.xml` và thay thế:

```xml
<!-- Thay thế YOUR_FACEBOOK_APP_ID bằng App ID thực tế -->
<string name="facebook_app_id">1234567890123456</string>
<string name="facebook_client_token">abcdef1234567890abcdef1234567890</string>
<string name="fb_login_protocol_scheme">fb1234567890123456</string>
```

## 5. Tạo Key Hash cho Debug

Chạy lệnh sau để tạo key hash:

```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
```

Mật khẩu mặc định: `android`

## 6. Cấu hình Firebase

1. Vào Firebase Console > Authentication > Sign-in method
2. Bật Facebook provider
3. Nhập App ID và App Secret từ Facebook App

## 7. Test Facebook Login

Sau khi cấu hình xong, Facebook login sẽ hoạt động trên:
- Android device/emulator với Google Play Services
- iOS simulator/device (cần cấu hình thêm iOS)

## Lưu ý quan trọng

- Facebook App phải ở chế độ "Live" để hoạt động với người dùng khác
- Cần thêm Test Users trong Facebook App Dashboard để test
- Key Hash phải chính xác, khác nhau giữa debug và release

## Troubleshooting

### Lỗi "Invalid key hash"
- Kiểm tra lại key hash trong Facebook App settings
- Đảm bảo package name đúng

### Lỗi "MissingPluginException"  
- Đã được xử lý trong code với error message thân thiện
- Kiểm tra cấu hình AndroidManifest.xml

### Lỗi "App not setup"
- Facebook App chưa được cấu hình đầy đủ
- Kiểm tra Facebook Login product đã được thêm chưa