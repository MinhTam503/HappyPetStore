# Facebook Sign-In Setup Guide

## Tạo Facebook App Mới

### 1. Tạo App trên Facebook Developer Console
- Vào: https://developers.facebook.com/
- **My Apps** → **Create App**
- Chọn **Consumer** → **Next**
- **App Name**: Pet Shop
- **App Contact Email**: your-email@gmail.com
- **Create App**

### 2. Thêm Facebook Login Product
- **Add Products** → **Facebook Login** → **Set Up**
- **Platform**: Android
- **Package Name**: com.example.pet_shop
- **Class Name**: com.example.pet_shop.MainActivity
- **Key Hash**: AE:43:18:D7:A7:67:92:23:AE:BC:A1:7C:71:31:61:BD:0A:FD:88:7F

### 3. Cấu hình Settings
- **Settings** → **Basic**
- Copy **App ID** và **App Secret**

### 4. Cập nhật file Android
```xml
<!-- android/app/src/main/res/values/strings.xml -->
<string name="facebook_app_id">NEW_APP_ID_HERE</string>
<string name="facebook_client_token">NEW_CLIENT_TOKEN_HERE</string>
<string name="fb_login_protocol_scheme">NEW_APP_ID_HERE</string>
```

### 5. Enable trong Firebase Console
- Firebase Console → Authentication → Sign-in methods
- Facebook → Enable
- App ID: NEW_APP_ID_HERE
- App Secret: NEW_APP_SECRET_HERE

## Hoặc Tắt Facebook Sign-In Tạm Thời

Nếu không muốn setup ngay, có thể tắt Facebook button trong UI.