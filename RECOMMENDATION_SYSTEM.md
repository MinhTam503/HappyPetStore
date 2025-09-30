# Hệ Thống Khuyến Nghị (Recommendation System)

## Tổng Quan

Hệ thống khuyến nghị được tích hợp vào ứng dụng Pet Shop sử dụng **Hybrid Recommendation System** kết hợp nhiều thuật toán để đưa ra gợi ý thú cưng phù hợp cho người dùng.

## Dữ Liệu Sử Dụng

### 1. **Dữ Liệu Người Dùng Hiện Có**
- ✅ **ViewedPets**: Lịch sử thú cưng đã xem (timestamp, category, breed, price)
- ✅ **SearchHistory**: Lịch sử tìm kiếm (query, timestamp, image search)
- ✅ **Favorites**: Thú cưng yêu thích (productId, name, category, breed)
- ✅ **Cart**: Giỏ hàng hiện tại
- ✅ **Orders**: Lịch sử mua hàng (từ orders_100.json và Firestore)
- ✅ **User Profile**: Thông tin cơ bản người dùng

### 2. **Dữ Liệu Tương Tác (User Interactions)**
```dart
enum InteractionType {
  view,       // Xem chi tiết (weight: 1.0)
  search,     // Tìm kiếm (weight: 1.5)
  favorite,   // Yêu thích (weight: 3.0)
  cart,       // Thêm vào giỏ (weight: 4.0)
  purchase,   // Mua hàng (weight: 5.0)
}
```

## Thuật Toán Sử Dụng

### 1. **Content-Based Filtering**
- Dựa trên thuộc tính thú cưng (category, breed, price)
- Tính toán similarity score theo sở thích người dùng
- Phù hợp cho người dùng mới hoặc ít tương tác

### 2. **Collaborative Filtering**
- Tìm người dùng có hành vi tương tự
- Gợi ý thú cưng mà người dùng tương tự đã thích
- Sử dụng User-User Collaborative Filtering

### 3. **Association Rules Mining**
- Sử dụng thuật toán Apriori có sẵn trong project
- Tìm mẫu "thường mua cùng nhau"
- Dựa trên lịch sử đơn hàng

### 4. **Trending/Popularity-Based**
- Thú cưng được tương tác nhiều nhất 30 ngày qua
- Tính score dựa trên số lượng và loại tương tác

### 5. **Hybrid Approach**
- Kết hợp tất cả thuật toán trên
- Weighted scoring system
- Đảm bảo đa dạng trong kết quả

## Cấu Trúc Code

### 1. **Domain Layer**
```
lib/domain/
├── entities/
│   └── recommendation_entities.dart    # UserProfile, RecommendationItem, etc.
├── repositories/
│   └── recommendation_repository.dart  # Abstract repository interface
└── usecases/
    └── recommendation_usecase.dart     # Business logic
```

### 2. **Data Layer**
```
lib/data/
└── repositories/
    └── recommendation_repository_impl.dart  # Firestore implementation
```

### 3. **Presentation Layer**
```
lib/presentation/
├── bloc/recommendation/
│   ├── recommendation_bloc.dart
│   ├── recommendation_event.dart
│   └── recommendation_state.dart
├── widgets/
│   └── recommendation_section.dart      # UI components
└── pages/mobile/recommendation/
    └── recommendation_demo_page.dart    # Demo page
```

### 4. **Core Services**
```
lib/core/
├── di/
│   └── recommendation_di.dart           # Dependency injection
└── services/
    └── recommendation_tracking_service.dart  # Auto tracking
```

## Tích Hợp vào Ứng Dụng

### 1. **Home Page**
```dart
// Tích hợp vào home_page.dart
const RecommendationSection(
  title: "Đề xuất cho bạn",
  type: RecommendationType.personalized,
  limit: 10,
),
```

### 2. **Tracking Tự Động**
```dart
// Trong DetailPet
void _trackPetView() async {
  await RecommendationTrackingService().trackPetView(petId);
}

// Trong CartBloc
void _trackAddToCart() async {
  await RecommendationTrackingService().trackAddToCart(petId);
}
```

### 3. **BLoC Integration**
```dart
// Trong main.dart
BlocProvider(create: (_) => getIt<RecommendationBloc>()),
```

## Loại Khuyến Nghị

### 1. **RecommendationType.personalized**
- Kết hợp tất cả thuật toán
- Cá nhân hóa cao nhất
- Ưu tiên cho trang chủ

### 2. **RecommendationType.contentBased**
- "Có thể bạn sẽ thích"
- Dựa trên sở thích hiện tại

### 3. **RecommendationType.collaborative**
- "Người dùng tương tự cũng thích"
- Khám phá sở thích mới

### 4. **RecommendationType.trending**
- "Thú cưng thịnh hành"
- Hot trends hiện tại

### 5. **RecommendationType.association**
- "Thường mua cùng nhau"
- Cross-selling

## Cách Sử Dụng

### 1. **Khởi Tạo trong main.dart**
```dart
// Initialize recommendation system
await setupRecommendationDI();
await RecommendationTrackingService().initialize();
```

### 2. **Sử dụng Widget**
```dart
RecommendationSection(
  title: "Your Title",
  type: RecommendationType.personalized,
  limit: 10,
  showViewAll: true,
)
```

### 3. **Track Interactions**
```dart
// Automatic tracking
await recommendationTracker.trackPetView(petId);
await recommendationTracker.trackFavorite(petId);
await recommendationTracker.trackAddToCart(petId);
await recommendationTracker.trackPurchase(petId);
```

### 4. **Programmatic Access**
```dart
// Get recommendations programmatically
final recommendations = await recommendationTracker
    .getPersonalizedRecommendations(limit: 10);

final trending = await recommendationTracker
    .getRecommendationsByType(RecommendationType.trending);
```

## Hiệu Suất & Tối Ưu

### 1. **Caching**
- User profiles được cache trong Firestore
- Recommendations được refresh theo session

### 2. **Lazy Loading**
- Recommendations load theo nhu cầu
- Pagination cho danh sách dài

### 3. **Background Processing**
- Tracking interactions không block UI
- Batch processing cho multiple interactions

## Firestore Collections

### 1. **user_profiles**
```json
{
  "userId": "string",
  "preferredCategories": ["dogs", "cats"],
  "preferredBreeds": ["Golden Retriever", "Persian"],
  "categoryWeights": {"dogs": 5.0, "cats": 3.0},
  "breedWeights": {"Golden Retriever": 8.0},
  "averageSpending": 1500000.0,
  "lastActivity": "2025-09-30T10:00:00Z"
}
```

### 2. **user_interactions**
```json
{
  "userId": "string",
  "petId": "string",
  "type": "view|search|favorite|cart|purchase",
  "timestamp": "2025-09-30T10:00:00Z",
  "weight": 1.0,
  "metadata": {"category": "dogs", "breed": "Golden Retriever"}
}
```

## Testing

### 1. **Demo Page**
- Truy cập `RecommendationDemoPage` để test
- 4 tabs: Cá nhân, Thịnh hành, Tương tự, Phân tích

### 2. **Manual Testing**
```dart
// Test individual components
final recommendations = await repository.getContentBasedRecommendations(userId);
final similarUsers = await repository.findSimilarUsers(userId);
```

## Mở Rộng Tương Lai

### 1. **Deep Learning**
- Tích hợp TensorFlow Lite
- Neural collaborative filtering
- Image-based recommendations

### 2. **Real-time Updates**
- WebSocket cho recommendations real-time
- Live trending updates

### 3. **A/B Testing**
- Multiple recommendation strategies
- Performance comparison

### 4. **Advanced Analytics**
- Click-through rates
- Conversion tracking
- Recommendation effectiveness metrics

## Troubleshooting

### 1. **No Recommendations**
- Kiểm tra user đã đăng nhập
- Verify user có interaction data
- Check Firestore permissions

### 2. **Poor Recommendations**
- Cần thêm interaction data
- Điều chỉnh algorithm weights
- Check user profile generation

### 3. **Performance Issues**
- Enable Firestore indexes
- Implement caching
- Optimize query limits

## Dependencies

```yaml
dependencies:
  get_it: ^7.6.4          # Dependency injection
  cloud_firestore: ^5.6.5 # Database
  flutter_bloc: ^9.1.0    # State management
  equatable: ^2.0.7       # Value equality
```

Hệ thống khuyến nghị này cung cấp một giải pháp toàn diện cho việc gợi ý thú cưng, tích hợp sâu vào kiến trúc BLoC và Clean Architecture hiện có của ứng dụng.