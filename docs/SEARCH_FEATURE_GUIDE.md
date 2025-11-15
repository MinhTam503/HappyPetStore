# Hướng Dẫn Sử Dụng Tính Năng Tìm Kiếm Social

## Tổng Quan
Tính năng tìm kiếm mới được thiết kế đẹp mắt và thân thiện với người dùng, cho phép tìm kiếm người dùng theo nhiều tiêu chí khác nhau.

## Các Tính Năng Chính

### 1. Giao Diện Tìm Kiếm
- **Thanh tìm kiếm**: Ở đầu trang với icon quay lại và nút xóa
- **Tự động gợi ý**: Hiển thị kết quả khi gõ ít nhất 2 ký tự
- **Debounce search**: Tránh tìm kiếm quá nhiều lần khi đang gõ

### 2. Tìm Kiếm Gần Đây
- Lưu lại 10 tìm kiếm gần nhất
- Hiển thị với icon lịch sử
- Có thể xóa từng mục hoặc xóa tất cả
- Click vào để tìm kiếm lại

### 3. Thẻ Xu Hướng (Trending Tags)
- Hiển thị các thẻ hashtag phổ biến nhất
- Được tính dựa trên 100 bài viết gần nhất
- Click vào thẻ để tìm kiếm theo thẻ đó
- Thiết kế chip với màu chủ đạo của app

### 4. Mẹo Tìm Kiếm
Hiển thị 3 gợi ý:
- **Tìm theo tên thú cưng**: VD: "Golden", "Luna", "Max"
- **Tìm theo giống**: VD: "Husky", "Persian", "Beagle"
- **Tìm theo thẻ**: VD: "#cute", "#funny", "#playful"

### 5. Kết Quả Tìm Kiếm
Mỗi kết quả hiển thị:
- **Avatar**: Ảnh đại diện người dùng (hoặc icon mặc định)
- **Tên hiển thị**: displayName (hoặc petName nếu không có)
- **Username**: @petName
- **Bio**: Phần giới thiệu ngắn (nếu có)
- **Thống kê**: Số bài viết và số người theo dõi
- **Icon mũi tên**: Chỉ định có thể click

Click vào kết quả → Mở trang cá nhân của người đó

### 6. Tiêu Chí Tìm Kiếm
Hệ thống tìm kiếm theo:
1. **Tên thú cưng** (petName)
2. **Tên hiển thị** (displayName)
3. **Giống** (breed)
4. **Bio** (phần giới thiệu)

### 7. Sắp Xếp Kết Quả
Kết quả được sắp xếp theo độ ưu tiên:
1. Khớp chính xác → Hiển thị đầu tiên
2. Khớp một phần → Sắp xếp theo số người theo dõi (nhiều nhất trước)

### 8. Trạng Thái Rỗng
- **Không có kết quả**: Icon search_off + thông báo "Không tìm thấy kết quả"
- **Gợi ý**: "Thử từ khóa khác"

## Cách Sử Dụng

### Mở Trang Tìm Kiếm
```dart
Navigator.pushNamed(context, '/social/search');
```

### Từ Social Home Page
Nhấn icon tìm kiếm (search_rounded) trên AppBar

### Luồng Hoạt Động
1. User nhấn icon tìm kiếm → Mở SocialSearchPage
2. Trang hiển thị: Recent searches + Trending tags + Search tips
3. User gõ từ khóa → Auto search sau 500ms
4. Hiển thị kết quả với avatar, tên, bio, stats
5. User click vào kết quả → Navigate đến profile page
6. Từ khóa được lưu vào recent searches

## Kỹ Thuật

### Repository - searchPets()
```dart
Future<List<SocialPetProfile>> searchPets(String query) async {
  // Query all public profiles
  // Filter by: petName, displayName, breed, bio
  // Sort by: exact match first, then by followers count
  return profiles;
}
```

### State Management
- **SocialBloc**: Quản lý state tìm kiếm
- **SearchPets event**: Trigger tìm kiếm
- **SocialSearchResults state**: Lưu kết quả

### Localization
Đã thêm các key mới:
- `recentSearches`: "Tìm kiếm gần đây"
- `clearAll`: "Xóa tất cả"
- `trending`: "Xu hướng"
- `searchTips`: "Mẹo tìm kiếm"
- `searchByPetName`: "Tìm theo tên thú cưng"
- `searchByBreed`: "Tìm theo giống"
- `searchByTag`: "Tìm theo thẻ"
- `noResults`: "Không tìm thấy kết quả"
- `tryDifferentKeywords`: "Thử từ khóa khác"

## Cải Tiến Tương Lai

### Phase 1 (Hoàn Thành ✅)
- [x] Trang tìm kiếm độc lập
- [x] Recent searches
- [x] Trending tags
- [x] Tìm theo displayName
- [x] Hiển thị avatar + stats
- [x] Navigate to profile

### Phase 2 (Đề Xuất)
- [ ] Lưu recent searches vào SharedPreferences
- [ ] Filter nâng cao (theo location, category)
- [ ] Tìm kiếm theo hashtag trong bài viết
- [ ] Autocomplete suggestions
- [ ] Voice search
- [ ] Tìm kiếm gần đây có timestamp
- [ ] Gợi ý dựa trên theo dõi của bạn bè

### Phase 3 (Nâng Cao)
- [ ] Elasticsearch/Algolia integration
- [ ] Fuzzy search (tìm gần đúng)
- [ ] Search analytics
- [ ] Personalized recommendations
- [ ] Search history sync across devices

## Testing Checklist

- [ ] Tìm kiếm với 0 ký tự → Hiển thị suggestions
- [ ] Tìm kiếm với 1 ký tự → Không search
- [ ] Tìm kiếm với 2+ ký tự → Auto search sau 500ms
- [ ] Tìm kiếm theo petName → Hiển thị kết quả đúng
- [ ] Tìm kiếm theo displayName → Hiển thị kết quả đúng
- [ ] Tìm kiếm theo breed → Hiển thị kết quả đúng
- [ ] Exact match → Hiển thị đầu tiên
- [ ] Click vào kết quả → Navigate đúng profile
- [ ] Click trending tag → Search tag đó
- [ ] Click recent search → Search lại
- [ ] Xóa recent search → Xóa thành công
- [ ] Clear all → Xóa tất cả recent
- [ ] Không có kết quả → Hiển thị empty state
- [ ] Loading → Hiển thị indicator
- [ ] Dark mode → UI đẹp và nhất quán

## Files Changed
1. `/lib/presentation/pages/social/social_search_page.dart` - NEW ✨
2. `/lib/presentation/pages/social/social_home_page.dart` - UPDATED
3. `/lib/data/repositories/social_repository_impl.dart` - UPDATED
4. `/lib/main.dart` - UPDATED (added route)
5. `/lib/core/localization/l10n/app_vi.arb` - UPDATED
6. `/lib/core/localization/l10n/app_en.arb` - UPDATED

## Support
Nếu có vấn đề, kiểm tra:
1. Route `/social/search` đã được thêm vào main.dart chưa?
2. Import `SocialSearchPage` đã đúng chưa?
3. Localization keys đã được generate chưa? (run `flutter gen-l10n`)
4. SocialBloc có xử lý SearchPets event không?
