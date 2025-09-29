# Tìm Kiếm Thú Cưng - Tương tự Shopee

## Tổng quan
Chức năng tìm kiếm thú cưng được thiết kế tương tự như Shopee, cung cấp gợi ý theo thời gian thực khi người dùng nhập từ khóa.

## Tính năng chính

### 1. Gợi ý theo thời gian thực (Real-time Suggestions)
- **Debounce**: 500ms để tránh query quá nhiều
- **Tự động gợi ý**: Hiển thị gợi ý khi người dùng gõ từ khóa
- **Giới hạn**: Tối đa 10 gợi ý mỗi lần

### 2. Các loại gợi ý
- **🐾 Thú cưng**: Tìm theo tên thú cưng (ví dụ: "Cá vàng")
- **📂 Danh mục**: Tìm theo loại thú cưng (ví dụ: "Dogs", "Fish")  
- **⭐ Giống**: Tìm theo giống thú cưng (ví dụ: "Golden Retriever", "Poodle")
- **🔍 Thú cưng theo danh mục**: Thú cưng thuộc danh mục cụ thể

### 3. Thuật toán tìm kiếm

#### Gợi ý (Search Suggestions)
```dart
// Tìm trong collection Pets
- Tên thú cưng chứa từ khóa
- Breed chứa từ khóa  
- Category chứa từ khóa

// Tìm trong collection Categories
- Tên category chứa từ khóa
- Breeds array chứa từ khóa
```

#### Tìm kiếm chính (Main Search)
```dart
// 1. Tìm kiếm theo searchKeywords (nhanh)
collection('Pets').where('searchKeywords', arrayContains: query)

// 2. Tìm kiếm fallback (toàn diện)
- Tên thú cưng chứa từ khóa
- Breed chứa từ khóa
- Category chứa từ khóa
```

### 4. Độ ưu tiên kết quả
1. **Tên thú cưng**: Khớp với tên có độ ưu tiên cao nhất
2. **Breed**: Khớp với giống có độ ưu tiên trung bình
3. **Category**: Khớp với danh mục có độ ưu tiên thấp nhất

### 5. Lịch sử tìm kiếm
- **Lưu trữ**: Firestore collection `SearchHistory`
- **Hiển thị**: Danh sách các từ khóa đã tìm gần đây
- **Thời gian**: Hiển thị thời gian tương đối (ví dụ: "2 giờ trước")

## Cấu trúc dữ liệu

### Collection: Pets
```json
{
  "name": "Cá vàng",
  "breed": "Golden Fish", 
  "category": "Fish",
  "searchKeywords": [
    "cá", "vàng", "cá vàng",
    "golden", "fish", "golden fish",
    "fish", "cá"
  ]
}
```

### Collection: Categories
```json
{
  "name": "Dogs",
  "breeds": [
    "Phốc sóc",
    "Poodle", 
    "Chihuahua",
    "Husky",
    "Golden Retriever"
  ]
}
```

### Collection: SearchHistory
```json
{
  "query": "golden",
  "searchedAt": "2024-01-15T10:30:00Z",
  "searchedAtMillis": 1705312200000,
  "isImageSearch": false,
  "imageUrl": null
}
```

## Cách sử dụng

### 1. Setup SearchKeywords (Một lần duy nhất)
```bash
# Chạy script để tạo Firebase function
dart run bin/update_search_keywords.dart

# Deploy Firebase function để cập nhật searchKeywords
node firebase_update_keywords.js
```

### 2. Sử dụng trong ứng dụng
```dart
// Khởi tạo SearchBloc
final searchBloc = SearchBloc(
  searchHistoryRepo: SearchHistoryRepository(),
  firestore: FirebaseFirestore.instance,
);

// Load lịch sử tìm kiếm
searchBloc.add(LoadSearchHistory());

// Lắng nghe thay đổi query (có debounce)
searchController.addListener(() {
  searchBloc.add(SearchQueryChanged(searchController.text));
});

// Submit search
searchBloc.add(SearchSubmitted(query));
```

### 3. UI Components

#### Search AppBar
```dart
AppBar(
  title: TextField(
    controller: searchController,
    decoration: InputDecoration(
      hintText: 'Tìm kiếm thú cưng...',
      suffixIcon: Row(
        children: [
          IconButton(
            icon: Icon(Icons.image_search),
            onPressed: () => // Image search
          ),
          IconButton(
            icon: Icon(Icons.search), 
            onPressed: () => // Text search
          ),
        ],
      ),
    ),
  ),
)
```

#### Suggestions List
```dart
Card(
  child: Column(
    children: [
      Text('Gợi ý'),
      ...suggestions.map((suggestion) => ListTile(
        leading: Icon(_getIconForType(suggestion['type'])),
        title: Text(suggestion['displayName']),
        subtitle: Text(_getSubtitleForType(suggestion['type'])),
        onTap: () => _handleSuggestionTap(suggestion),
      )),
    ],
  ),
)
```

## Test Cases

### Gợi ý (Suggestions)
- Gõ "cá" → Hiển thị pets có tên chứa "cá"
- Gõ "golden" → Hiển thị pets có breed chứa "golden"  
- Gõ "dog" → Hiển thị category "Dogs" và pets thuộc category "Dogs"
- Gõ "poodle" → Hiển thị breed "Poodle" từ Categories

### Tìm kiếm (Search)
- Search "cá vàng" → Tìm pets có tên "Cá vàng"
- Search "golden" → Tìm pets có breed chứa "Golden"
- Search "dogs" → Tìm tất cả pets thuộc category "Dogs"

### Lịch sử (History)
- Tìm kiếm được lưu vào SearchHistory
- Hiển thị 10 query gần nhất
- Có thể xóa tất cả lịch sử

## Performance

### Optimizations
1. **Debounce**: 500ms giảm số lượng query
2. **Limit**: Giới hạn suggestions (10), history (10)
3. **SearchKeywords**: Index cho tìm kiếm nhanh
4. **Caching**: BLoC state management cache kết quả

### Firestore Indexes
```javascript
// Composite indexes cần tạo
collection('Pets') {
  searchKeywords: 'array-contains',
  name: 'ascending'
}

collection('SearchHistory') {
  searchedAtMillis: 'descending'  
}
```

## Troubleshooting

### Không có gợi ý
- Kiểm tra searchKeywords đã được tạo chưa
- Verify Firestore rules cho phép read
- Check console logs cho errors

### Gợi ý không chính xác  
- Cập nhật searchKeywords với script
- Thêm từ đồng nghĩa tiếng Việt
- Điều chỉnh thuật toán matching

### Performance chậm
- Tăng debounce time
- Giảm limit suggestions
- Thêm Firestore indexes

## Kế hoạch phát triển

### Phase 2
- [ ] Fuzzy search (tìm kiếm gần đúng)
- [ ] Search theo giá, tuổi, cân nặng
- [ ] Voice search
- [ ] Search history analytics

### Phase 3  
- [ ] AI-powered suggestions
- [ ] Search result ranking ML
- [ ] Advanced filters
- [ ] Search autocomplete API