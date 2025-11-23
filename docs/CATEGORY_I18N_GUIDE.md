# Hướng dẫn Cập nhật Category để hỗ trợ Đa ngôn ngữ (i18n)

## Vấn đề đã giải quyết

1. **Categories được hardcode** trong code (Dogs, Cats, Fish, Birds) → Nếu thêm category mới sẽ bị lỗi
2. **Thiếu đa ngôn ngữ** → Tên category chỉ hiển thị tiếng Anh

## Giải pháp đã triển khai

### 1. Load động categories từ Firestore
- Tất cả màn hình giờ đều load categories từ Firestore thay vì hardcode
- Nếu có thêm category mới trong Firestore → Tự động hiển thị

### 2. Hỗ trợ đa ngôn ngữ
- Thêm field `nameVi` trong Firestore để lưu tên tiếng Việt
- Tự động hiển thị theo ngôn ngữ người dùng chọn

## Cấu trúc Category trong Firestore

```javascript
// Collection: Category
{
  "name": "Dogs",           // Tên tiếng Anh (bắt buộc)
  "nameVi": "Chó",          // Tên tiếng Việt (khuyến nghị)
  "imageUrl": "https://...", // URL hình ảnh
  "breeds": [               // Danh sách giống
    "Phốc sóc",
    "Poodle",
    "Chihuahua",
    "Husky",
    "Golden Retriever"
  ]
}
```

## Các bước cập nhật Firestore

### Bước 1: Thêm field `nameVi` cho categories hiện có

Truy cập Firebase Console > Firestore > Collection `Category`, cập nhật từng document:

**Dogs:**
```javascript
{
  "name": "Dogs",
  "nameVi": "Chó",
  "imageUrl": "...",
  "breeds": [...]
}
```

**Cats:**
```javascript
{
  "name": "Cats",
  "nameVi": "Mèo",
  "imageUrl": "...",
  "breeds": [...]
}
```

**Fish:**
```javascript
{
  "name": "Fish",
  "nameVi": "Cá",
  "imageUrl": "...",
  "breeds": [...]
}
```

**Birds:**
```javascript
{
  "name": "Birds",
  "nameVi": "Chim",
  "imageUrl": "...",
  "breeds": [...]
}
```

### Bước 2: Kiểm tra trên app

1. **Chuyển ngôn ngữ sang tiếng Việt** (nếu chưa có trong settings, app sẽ dùng locale thiết bị)
2. **Kiểm tra trang chủ** → Categories hiển thị bằng tiếng Việt
3. **Chuyển sang tiếng Anh** → Categories hiển thị bằng tiếng Anh
4. **Admin panel** → Có thể thấy tất cả categories động

### Bước 3: Thêm category mới (ví dụ: Hamster)

```javascript
// Thêm document mới vào Collection Category
{
  "name": "Hamsters",
  "nameVi": "Chuột Hamster",
  "imageUrl": "https://firebasestorage.googleapis.com/.../hamster.jpg",
  "breeds": [
    "Syrian Hamster",
    "Dwarf Hamster",
    "Roborovski Hamster"
  ]
}
```

**Kết quả:** Category mới sẽ tự động hiển thị ở:
- Trang chủ (categories section)
- Admin panel (dropdown khi thêm/sửa pet)
- Trang All Pets (filter dropdown)

## Logic hiển thị

```dart
String _getCategoryDisplayName(BuildContext context, Map<String, dynamic> category) {
  final locale = Localizations.localeOf(context).languageCode;
  
  // Nếu là tiếng Việt và có field nameVi → Dùng nameVi
  if (locale == 'vi' && category.containsKey('nameVi') && category['nameVi'] != null) {
    return category['nameVi'];
  }
  
  // Mặc định dùng name (tiếng Anh)
  return category['name'] ?? '';
}
```

## Files đã được cập nhật

1. **lib/presentation/widgets/home/categories_section.dart**
   - Thêm method `_getCategoryDisplayName()` để hiển thị đúng ngôn ngữ
   - Sử dụng locale để chọn tên hiển thị

2. **lib/presentation/pages/web/screen_admin/pet/pets_admin.dart**
   - Đổi từ `final List<String>` → `List<String>` để có thể update
   - Thêm method `_loadCategories()` load từ Firestore
   - Fallback về list mặc định nếu load thất bại

3. **lib/presentation/pages/mobile/pet/all_pet.dart**
   - Thêm `availableCategories` list động
   - Load categories từ Firestore khi khởi tạo
   - Pass vào _FilterBar widget

## Lưu ý quan trọng

### ✅ Ưu điểm của giải pháp
- **Dễ bảo trì**: Thêm category mới chỉ cần thêm vào Firestore
- **Đa ngôn ngữ**: Hỗ trợ nhiều ngôn ngữ bằng cách thêm fields (nameVi, nameJa, nameKo...)
- **Tương thích ngược**: Nếu không có `nameVi`, vẫn hiển thị `name` bình thường

### ⚠️ Các trường hợp đặc biệt
1. **Pet Try-On Page (3D)**: Vẫn dùng hardcode categories vì phụ thuộc vào 3D assets
2. **Filters**: Khi filter pets theo category, vẫn dùng field `category` trong Pets collection (English name)

### 🔄 Migration plan
Nếu muốn đổi tất cả `category` field trong Pets sang tiếng Việt:
1. Không khuyến nghị vì ảnh hưởng lớn đến dữ liệu
2. Nên giữ `category` = English name (khóa chính)
3. Chỉ dùng `nameVi` cho hiển thị UI

## Mở rộng cho nhiều ngôn ngữ

Nếu muốn hỗ trợ thêm ngôn ngữ khác (Nhật, Hàn, Trung...):

```javascript
{
  "name": "Dogs",
  "nameVi": "Chó",
  "nameJa": "犬",
  "nameKo": "개",
  "nameZh": "狗",
  "imageUrl": "...",
  "breeds": [...]
}
```

Update logic:
```dart
String _getCategoryDisplayName(BuildContext context, Map<String, dynamic> category) {
  final locale = Localizations.localeOf(context).languageCode;
  
  final nameKey = 'name${locale.toUpperCase()}'; // nameVI, nameJA, nameKO...
  if (category.containsKey(nameKey) && category[nameKey] != null) {
    return category[nameKey];
  }
  
  return category['name'] ?? '';
}
```

## Testing checklist

- [ ] Thêm field `nameVi` cho tất cả categories trong Firestore
- [ ] Test hiển thị tiếng Việt trên trang chủ
- [ ] Test hiển thị tiếng Anh khi chuyển locale
- [ ] Test admin panel load categories động
- [ ] Test filter trong All Pets page
- [ ] Thêm 1 category mới và verify tự động hiển thị
- [ ] Test backward compatibility (categories không có nameVi)

## Câu hỏi thường gặp

**Q: Tôi có thể xóa field `name` và chỉ dùng `nameVi` không?**
A: Không nên. Field `name` (English) được dùng làm key trong nhiều chỗ (filter, query, 3D models). Chỉ thêm `nameVi` cho UI display.

**Q: Làm sao để thêm ngôn ngữ thứ 3?**
A: Thêm field `nameJa`, `nameKo`, etc. và update method `_getCategoryDisplayName()`.

**Q: Admin panel có cần hiển thị 2 ngôn ngữ không?**
A: Tùy yêu cầu. Hiện tại admin dùng English name. Có thể customize để hiển thị cả 2: "Dogs (Chó)".

---

**Tác giả:** GitHub Copilot
**Ngày cập nhật:** 2025-11-23
