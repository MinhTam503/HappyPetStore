# App Download Setup Guide

## Hướng dẫn cấu hình tải ứng dụng Android & iOS

### 📱 Tổng quan

Ứng dụng web của bạn hiện có chức năng download mobile app với UI đẹp và animations. Tài liệu này hướng dẫn cách setup file APK/IPA để người dùng có thể tải về.

---

## 🎯 Hai phương pháp hosting

### ✅ Phương pháp 1: Firebase Storage (Khuyến nghị)

**Ưu điểm:**
- Dễ update app mới không cần deploy lại web
- Bandwidth và CDN tốt
- Có thể track số lượt download
- Secure và reliable

**Bước 1: Upload APK lên Firebase Storage**

```bash
# Build APK production
flutter build apk --release

# File APK sẽ ở: build/app/outputs/flutter-apk/app-release.apk
```

1. Mở Firebase Console: https://console.firebase.google.com
2. Chọn project của bạn
3. Vào **Storage** → Click **Get Started**
4. Tạo folder `apps/` trong root
5. Upload `app-release.apk` vào folder `apps/`
6. Click vào file → Tab **File location** → Copy download URL

**Bước 2: Cấu hình Security Rules**

Vào Storage Rules và thêm:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow public read for app downloads
    match /apps/{allFiles=**} {
      allow read: if true;
      allow write: if request.auth != null; // Only authenticated users can upload
    }
    
    // Your existing rules...
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Bước 3: Update code**

Mở file `lib/presentation/widgets/download_app_section.dart`:

```dart
// Line ~223, replace the URL
if (platform == 'android') {
  // Replace YOUR_PROJECT_ID with your Firebase project ID
  url = 'https://firebasestorage.googleapis.com/v0/b/YOUR_PROJECT_ID.appspot.com/o/apps%2Fapp-release.apk?alt=media';
}
```

**Lấy Project ID:**
- Firebase Console → Project Settings → Project ID
- Hoặc check file `lib/firebase_options.dart`

---

### 📦 Phương pháp 2: Web Server Hosting

**Ưu điểm:**
- Full control
- Có thể customize download flow

**Bước 1: Deploy file lên server**

```bash
# Build APK
flutter build apk --release

# Upload to your server (example with scp)
scp build/app/outputs/flutter-apk/app-release.apk user@your-server.com:/var/www/html/downloads/
```

**Bước 2: Configure server (Nginx example)**

```nginx
location /downloads/ {
    alias /var/www/html/downloads/;
    
    # Force download instead of opening in browser
    add_header Content-Disposition 'attachment; filename="HappyPets.apk"';
    add_header Content-Type 'application/vnd.android.package-archive';
    
    # Enable CORS if needed
    add_header 'Access-Control-Allow-Origin' '*';
}
```

**Bước 3: Update code**

```dart
// In download_app_section.dart
if (platform == 'android') {
  url = 'https://your-domain.com/downloads/app-release.apk';
}
```

---

## 🍎 iOS App Distribution

iOS apps không thể tải trực tiếp file IPA do giới hạn của Apple. Có 3 cách:

### Option 1: App Store (Production)

```dart
if (platform == 'ios') {
  // Replace with your App Store ID
  url = 'https://apps.apple.com/app/id123456789';
}
```

**Cách lấy App Store ID:**
1. Sau khi submit app lên App Store Connect
2. Vào App Store Connect → My Apps → Your App
3. App ID sẽ hiện trong URL hoặc App Information section

### Option 2: TestFlight (Beta Testing)

```dart
if (platform == 'ios') {
  // Replace with your TestFlight invite code
  url = 'https://testflight.apple.com/join/YOUR_CODE';
}
```

**Setup TestFlight:**
1. Xcode → Archive your app
2. Upload to App Store Connect
3. Vào TestFlight tab
4. Add testers (external or internal)
5. Get public link từ TestFlight settings

### Option 3: Enterprise Distribution (Nếu có Enterprise account)

Chỉ dùng nếu có Apple Developer Enterprise Program ($299/year).

---

## 🔧 Custom Naming & Versioning

### Đổi tên file APK

Trong `android/app/build.gradle`:

```gradle
android {
    // ...
    
    applicationVariants.all { variant ->
        variant.outputs.all { output ->
            def appName = "HappyPets"
            def versionName = variant.versionName
            def versionCode = variant.versionCode
            
            outputFileName = "${appName}_v${versionName}_${versionCode}.apk"
            // Output: HappyPets_v1.0.0_1.apk
        }
    }
}
```

### Version Management

Trong `pubspec.yaml`:

```yaml
version: 1.0.0+1  # Format: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

Update khi release mới:
- Bug fix: `1.0.0+1` → `1.0.1+2`
- New feature: `1.0.0+1` → `1.1.0+2`
- Breaking change: `1.0.0+1` → `2.0.0+2`

---

## 📊 Track Downloads (Optional)

### Firebase Analytics

Thêm vào `_downloadApp` function trong `download_app_section.dart`:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

Future<void> _downloadApp(BuildContext context, String platform) async {
  // Existing code...
  
  // Track download event
  await FirebaseAnalytics.instance.logEvent(
    name: 'app_download',
    parameters: {
      'platform': platform,
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
  
  // Existing download code...
}
```

---

## 🔐 Security Best Practices

### 1. APK Signing
Luôn sign APK với production keystore:

```bash
# Generate keystore (one time)
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Configure in android/key.properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

Update `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 2. ProGuard/R8
Đã enabled mặc định trong release build để obfuscate code.

### 3. HTTPS Only
Chỉ dùng HTTPS URLs cho download links.

---

## 📱 User Instructions

Sau khi người dùng click download, họ cần:

### Android:
1. Cho phép install from unknown sources:
   - Settings → Security → Unknown Sources → Enable
   - Hoặc: Settings → Apps → Special Access → Install Unknown Apps → [Browser] → Allow
2. Open downloaded APK file
3. Click Install

### iOS:
- TestFlight: Click link → Install TestFlight app (nếu chưa có) → Open invite → Install
- App Store: Click link → Install như app thông thường

---

## 🎨 UI Customization

### Thay đổi màu sắc buttons

Trong `download_app_section.dart`, line ~120:

```dart
// Android - Green theme
colors: _isHovering
    ? [Colors.green[700]!, Colors.green[600]!]
    : [Colors.white, Colors.white],

// iOS - Blue theme  
colors: _isHovering
    ? [Colors.blue[900]!, Colors.blue[700]!]
    : [Colors.white, Colors.white],
```

### Thay đổi animations

```dart
// Hover animation speed
_controller = AnimationController(
  duration: const Duration(milliseconds: 200), // Change this
  vsync: this,
);

// Scale effect
_scaleAnimation = Tween<double>(
  begin: 1.0,
  end: 1.05, // Change for more/less zoom
).animate(...)
```

---

## ✅ Checklist trước khi deploy

- [ ] Build APK release mode (`flutter build apk --release`)
- [ ] Test APK trên thiết bị thật (không chỉ emulator)
- [ ] Upload APK lên Firebase Storage hoặc server
- [ ] Update download URL trong code
- [ ] Test download flow từ web
- [ ] Kiểm tra file có download về đúng không
- [ ] Verify APK có cài được không
- [ ] Setup Firebase Analytics tracking (optional)
- [ ] Document version number cho user
- [ ] Add release notes (optional)

---

## 🐛 Troubleshooting

### APK không tải được
- Check CORS headers trên server
- Verify URL có accessible publicly không
- Check Firebase Storage Rules
- Try direct URL trong browser

### APK tải về nhưng corrupted
- Verify Content-Type header: `application/vnd.android.package-archive`
- Check file size có đúng không
- Re-upload file

### iOS link không mở được
- Verify App Store ID đúng format
- Check TestFlight invite còn active không
- Ensure URL scheme đúng: `https://`

### Animations không smooth
- Check device có enable animations không (developer settings)
- Reduce animation duration
- Test trên device thật thay vì emulator

---

## 📞 Support

Nếu cần hỗ trợ:
1. Check Firebase Console logs
2. Test download URL directly trong browser
3. Verify APK có sign đúng không: `jarsigner -verify -verbose -certs app-release.apk`
4. Check web console cho errors

---

**Updated:** 2024
**Version:** 1.0.0
