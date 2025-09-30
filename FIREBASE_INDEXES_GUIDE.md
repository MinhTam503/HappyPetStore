# Hướng Dẫn Tạo Firebase Composite Indexes

## Tại Sao Cần Composite Indexes?

Hệ thống khuyến nghị cần thực hiện các truy vấn phức tạp với nhiều điều kiện sắp xếp để:
- Lấy lịch sử tương tác theo user và thời gian
- Phân tích trending pets theo views và timestamp
- Tối ưu performance cho recommendation algorithms

## Cách Tạo Indexes

### Phương Pháp 1: Tự Động (Khuyến Nghị)

1. **Kích hoạt RecommendationBloc trong ứng dụng:**
   ```dart
   // Trong home_page.dart, thay thế SimpleRecommendationSection bằng:
   BlocBuilder<RecommendationBloc, RecommendationState>(
     builder: (context, state) {
       // ... xử lý states
     },
   )
   ```

2. **Chạy ứng dụng và trigger recommendations:**
   - Firebase sẽ tự động detect missing indexes
   - Kiểm tra console logs để thấy index creation links

3. **Click vào links trong Firebase Console:**
   - Firebase sẽ cung cấp direct links để tạo indexes
   - Một click là xong!

### Phương Pháp 2: Thủ Công

1. **Truy cập Firebase Console:**
   - Mở https://console.firebase.google.com
   - Chọn project pet-shop của bạn
   - Vào Firestore Database > Indexes

2. **Tạo Composite Index cho user_interactions:**
   ```
   Collection ID: user_interactions
   
   Index 1:
   - Field: userId (Ascending)
   - Field: timestamp (Descending)
   
   Index 2:
   - Field: petId (Ascending) 
   - Field: timestamp (Descending)
   
   Index 3:
   - Field: userId (Ascending)
   - Field: interactionType (Ascending)
   - Field: timestamp (Descending)
   ```

3. **Tạo Index cho pets collection:**
   ```
   Collection ID: pets
   
   Index:
   - Field: views (Descending)
   - Field: timestamp (Descending)
   ```

### Phương Pháp 3: Firebase CLI

```bash
# Cài đặt Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Khởi tạo firestore trong project
cd /path/to/your/project
firebase init firestore

# Tạo file firestore.indexes.json
```

**File firestore.indexes.json:**
```json
{
  "indexes": [
    {
      "collectionGroup": "user_interactions",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "timestamp",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "user_interactions", 
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "petId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "timestamp", 
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "user_interactions",
      "queryScope": "COLLECTION", 
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "interactionType",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "timestamp",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "pets",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "views",
          "order": "DESCENDING"
        },
        {
          "fieldPath": "timestamp",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

```bash
# Deploy indexes
firebase deploy --only firestore:indexes
```

## Kiểm Tra Index Status

1. **Trong Firebase Console:**
   - Firestore Database > Indexes
   - Status sẽ hiển thị "Building" → "Enabled"

2. **Trong ứng dụng:**
   ```dart
   // Sau khi indexes được tạo, test trong ứng dụng:
   // 1. Vào Detail Pet để tạo interactions
   // 2. Quay lại Home để xem recommendations
   // 3. Kiểm tra console logs
   ```

## Sau Khi Tạo Indexes

1. **Cập nhật UI trong home_page.dart:**
   ```dart
   // Thay thế SimpleRecommendationSection bằng full BLoC version:
   BlocBuilder<RecommendationBloc, RecommendationState>(
     builder: (context, state) {
       if (state is RecommendationLoading) {
         return Container(
           padding: EdgeInsets.all(16),
           child: Center(child: CircularProgressIndicator()),
         );
       } else if (state is RecommendationLoaded) {
         return RecommendationSection(
           recommendations: state.recommendations,
         );
       } else if (state is RecommendationError) {
         return Container(
           padding: EdgeInsets.all(16),
           child: Text('Lỗi: ${state.message}'),
         );
       }
       return Container(
         padding: EdgeInsets.all(16),
         child: Text('Đang tải khuyến nghị...'),
       );
     },
   )
   ```

2. **Trigger recommendation loading:**
   ```dart
   // Trong initState của HomePage:
   @override
   void initState() {
     super.initState();
     // Load recommendations
     context.read<RecommendationBloc>().add(
       LoadRecommendations(),
     );
   }
   ```

## Troubleshooting

### Lỗi: "The query requires an index"
- **Giải pháp:** Tạo composite index theo hướng dẫn trên
- **Tạm thời:** Sử dụng SimpleRecommendationSection

### Index building quá lâu
- **Nguyên nhân:** Dữ liệu lớn hoặc traffic cao
- **Giải pháp:** Đợi, thường mất 5-30 phút

### Console không hiển thị index links
- **Kiểm tra:** Firebase project settings
- **Thử:** Method 2 (thủ công) hoặc Method 3 (CLI)

## Tối Ưu Performance

1. **Sau khi có indexes:**
   - Query time giảm từ seconds xuống milliseconds
   - Recommendation loading < 1s
   - Better user experience

2. **Monitoring:**
   - Firebase Console > Performance
   - Watch query performance metrics
   - Monitor recommendation usage patterns

## Kết Luận

Composite indexes là bước cuối cùng để kích hoạt hệ thống khuyến nghị hoàn chỉnh. Sau khi tạo xong:

✅ **Hybrid recommendation algorithm hoạt động đầy đủ**
✅ **Real-time user interaction tracking**  
✅ **Optimized query performance**
✅ **Complete BLoC integration**
✅ **Production-ready recommendation system**

**Thời gian tạo index:** 5-30 phút (tùy dữ liệu)
**Tác động:** Chuyển từ fallback sang full recommendation system
**Performance gain:** 10-100x faster queries