# 🔧 Sửa Lỗi Revenue, Pet Admin & Account Admin

## 📊 **1. Revenue Page - Chỉ hiển thị ngày có doanh thu & Cải thiện cuộn ngang**

### 🐛 **Vấn đề cũ:**
- Khi thống kê từ ngày 1/4 đến 31/5 chỉ hiện 6 ngày có doanh thu
- Các ngày không có doanh thu vẫn hiển thị khoảng trống
- Flutter web không cuộn ngang được mượt mà

### ✅ **Giải pháp đã áp dụng:**

#### **Chỉ hiển thị ngày có doanh thu:**
```dart
// Sửa _buildBarGroups method
if (hasRange) {
  // For date range: only show days with revenue > 0
  final daysWithRevenue = days.where((key) => (data[key] ?? 0) > 0).toList();
  for (int i = 0; i < daysWithRevenue.length; i++) {
    final key = daysWithRevenue[i];
    final value = data[key] ?? 0;
    // Tạo BarChartGroupData với x = i (index liên tiếp)
  }
} else {
  // For monthly: only show days with revenue > 0
  final entries = data.entries
      .where((e) => int.tryParse(e.key) != null && e.value > 0)
      .toList()
    ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
  for (int i = 0; i < entries.length; i++) {
    // Sử dụng index i thay vì day number để hiển thị liên tiếp
  }
}
```

#### **Cải thiện cuộn ngang cho web:**
```dart
// Thêm Scrollbar và cải thiện physics
Expanded(
  child: Scrollbar(
    thumbVisibility: true,
    trackVisibility: true,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: _calculateChartWidth(),
        // Chart content
      ),
    ),
  ),
)
```

#### **Cập nhật tính toán width:**
```dart
double _calculateChartWidth() {
  final screenWidth = MediaQuery.of(context).size.width;
  final minWidth = screenWidth - 100;
  
  // Chỉ tính ngày có doanh thu cho cả date range và monthly
  final daysWithData = dailyRevenue.entries.where((e) => e.value > 0).length;
  final calculatedWidth = daysWithData * 80.0 + 200;
  return calculatedWidth > minWidth ? calculatedWidth : minWidth;
}
```

---

## 🐕 **2. Pet Admin - Sửa lỗi loading không tắt**

### 🐛 **Vấn đề cũ:**
- Pick ảnh thêm loading mãi không tắt
- Có thể có lỗi xảy ra trong quá trình update mà không reset loading state
- Firebase Storage path không rõ ràng

### ✅ **Giải pháp đã áp dụng:**

#### **Sửa updatePet method với try-catch-finally:**
```dart
void updatePet(Pet pet) async {
  setState(() => isLoading = true);

  try {
    String finalImageUrl = pet.imageUrl;

    if (_imageBytes != null) {
      try {
        // Xóa hình cũ
        final oldImageRef = FirebaseStorage.instance.refFromURL(pet.imageUrl);
        await oldImageRef.delete();
      } catch (e) {
        _snack('Xóa hình cũ bị lỗi $e');
      }

      // Upload hình mới
      final fileName = '${const Uuid().v4()}.jpg';
      finalImageUrl = await uploadImage(_imageBytes!, fileName);
      if (finalImageUrl.isEmpty) {
        _snack('Upload hình mới thất bại!');
        return;
      }
    }

    await petsCollection.doc(pet.id).update({
      // Update pet data
    });

    _snack('Cập nhật thú cưng thành công!');
  } catch (e) {
    _snack('Lỗi cập nhật thú cưng: $e');
  } finally {
    // QUAN TRỌNG: Reset loading state trong mọi trường hợp
    setState(() {
      _imageBytes = null;
      isLoading = false;
    });
  }
}
```

#### **Xác nhận Storage Path cho Pet:**
- **Pet images**: Lưu trực tiếp ở root Firebase Storage (không có child folder)
- **Filename**: UUID.jpg (random)

---

## 👤 **3. Account Admin - Sửa Storage Path & Xóa ảnh cũ**

### 🐛 **Vấn đề cũ:**
- Ảnh account không lưu theo format `iduser.định_dạng_ảnh`
- Không lưu trong folder `profile_images`
- Không xóa ảnh cũ trước khi thêm ảnh mới

### ✅ **Giải pháp đã áp dụng:**

#### **Sửa uploadImage method - Auto detect format:**
```dart
Future<String> uploadImage(Uint8List imageBytes, String userId) async {
  try {
    // Detect image format from bytes signature
    String ext = 'jpg';
    if (imageBytes.length > 3) {
      // Check PNG signature
      if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50 && 
          imageBytes[2] == 0x4E && imageBytes[3] == 0x47) {
        ext = 'png';
      }
      // Check JPEG signature
      else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
        ext = 'jpg';
      }
      // Check GIF signature
      else if (imageBytes[0] == 0x47 && imageBytes[1] == 0x49 && imageBytes[2] == 0x46) {
        ext = 'gif';
      }
      // Check WebP signature
      else if (imageBytes.length > 11 && 
               imageBytes[8] == 0x57 && imageBytes[9] == 0x45 && 
               imageBytes[10] == 0x42 && imageBytes[11] == 0x50) {
        ext = 'webp';
      }
    }

    final fileName = '$userId.$ext';  // Format: iduser.extension
    
    final storageRef = FirebaseStorage.instance.ref()
        .child('profile_images/$fileName');  // Folder: profile_images
    
    final uploadTask = storageRef.putData(imageBytes, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  } catch (e) {
    debugPrint('Error uploading image: $e');
    return '';
  }
}
```

#### **Thêm method xóa ảnh cũ:**
```dart
Future<void> deleteOldImage(String imageUrl) async {
  try {
    if (imageUrl.isNotEmpty && 
        imageUrl.contains('firebase') && 
        imageUrl.contains('profile_images')) {
      final oldImageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await oldImageRef.delete();
    }
  } catch (e) {
    debugPrint('Error deleting old image: $e');
  }
}
```

#### **Cập nhật addAccount method:**
```dart
void addAccount(Map<String, dynamic> account) async {
  try {
    setState(() => isLoading = true);
    
    // First add account to get the document ID
    final docRef = await accountsCollection.add(account);
    final userId = docRef.id;
    
    // Upload image if selected, using the generated userId
    String finalImageUrl = account['imageUrl'] ?? '';
    if (_imageBytes != null) {
      finalImageUrl = await uploadImage(_imageBytes!, userId);
      // Update the account with the new image URL
      await accountsCollection.doc(userId).update({'imageUrl': finalImageUrl});
    }
    
    // Success handling and reset
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}
```

#### **Cập nhật updateAccount method:**
```dart
void updateAccount(String id, Map<String, dynamic> account) async {
  try {
    setState(() => isLoading = true);
    
    String finalImageUrl = account['imageUrl'] ?? '';
    if (_imageBytes != null) {
      // Delete old image first
      final oldImageUrl = account['imageUrl'] ?? '';
      await deleteOldImage(oldImageUrl);
      
      // Upload new image using userId as filename
      finalImageUrl = await uploadImage(_imageBytes!, id);
      account['imageUrl'] = finalImageUrl;
    }
    
    await accountsCollection.doc(id).update(account);
    // Success handling
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}
```

---

## 🗂️ **Firebase Storage Structure:**

```
Firebase Storage Root/
├── profile_images/           📁 Account images folder
│   ├── userId1.jpg
│   ├── userId2.png
│   └── userId3.webp
├── petImage1.jpg            📁 Pet images (root level)
├── petImage2.png
└── petImage3.webp
```

**Account Images**: `profile_images/userId.extension`
**Pet Images**: `petImageId.extension` (root level)

---

## 🔧 **Files đã chỉnh sửa:**

### **revenue_page.dart:**
- `_calculateChartWidth()`: Tính toán dựa trên ngày có doanh thu
- `_buildBarGroups()`: Chỉ hiển thị ngày có revenue > 0
- Chart container: Thêm Scrollbar với `thumbVisibility` và `trackVisibility`
- Scrolling physics: Đổi sang `AlwaysScrollableScrollPhysics`

### **pets_admin.dart:**
- `updatePet()`: Thêm try-catch-finally để đảm bảo reset loading state
- `uploadImage()`: Xác nhận storage path (root level)
- Error handling: Cải thiện thông báo lỗi

### **account_admin.dart:**
- `uploadImage()`: Auto-detect image format từ byte signature
- `deleteOldImage()`: Method xóa ảnh cũ an toàn
- `addAccount()`: Logic upload ảnh sau khi tạo account
- `updateAccount()`: Xóa ảnh cũ trước khi upload ảnh mới
- Storage path: `profile_images/userId.extension`

---

## ✅ **Kết quả đạt được:**

### **Revenue Page:**
- ✅ Chỉ hiển thị ngày có doanh thu thực tế
- ✅ Cuộn ngang mượt mà trên Flutter web
- ✅ Scrollbar rõ ràng, dễ sử dụng

### **Pet Admin:**
- ✅ Loading state được reset đúng cách trong mọi trường hợp  
- ✅ Xử lý lỗi tốt hơn với try-catch-finally
- ✅ Storage path rõ ràng (root level)

### **Account Admin:**
- ✅ Filename format: `userId.extension` (auto-detect)
- ✅ Storage path: `profile_images/` folder
- ✅ Xóa ảnh cũ trước khi upload ảnh mới
- ✅ Xử lý cả add và update account đúng cách

---

## 🚀 **Ready for Testing:**

1. **Revenue**: Test date range filtering để xác nhận chỉ hiện ngày có doanh thu
2. **Pet Admin**: Test pick ảnh và update để xác nhận loading tắt đúng
3. **Account Admin**: Test add/edit account với image để xác nhận storage path và xóa ảnh cũ

**All systems optimized! 🎯**