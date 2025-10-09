# Phân tích Hệ thống Khuyến nghị Pet Shop

## Tổng quan Kiến trúc

Hệ thống khuyến nghị Pet Shop được xây dựng theo kiến trúc **Clean Architecture** với 6 thuật toán khuyến nghị chính và hệ thống cache thông minh.

## 1. Các thuật toán Khuyến nghị

### 1.1. Content-Based Filtering (Lọc dựa trên Nội dung)
- **Nguyên lý**: Phân tích thuộc tính của thú cưng và sở thích người dùng
- **Trọng số**: 40% trong hybrid algorithm
- **Cách thức hoạt động**:
  - Phân tích lịch sử mua hàng, yêu thích, xem
  - So khớp category và breed preferences
  - Scoring dựa trên mức độ phù hợp
- **Ưu điểm**: Không cần data từ user khác, giải thích được
- **Nhược điểm**: Limited diversity, cold start problem

### 1.2. Collaborative Filtering (Lọc Cộng tác)
- **Nguyên lý**: "Người có sở thích tương tự thích những thú cưng tương tự"
- **Trọng số**: 30% trong hybrid algorithm
- **Cách thức hoạt động**:
  - Tìm user có category preferences tương tự
  - Recommend pets popular trong nhóm user đó
  - Popularity scoring dựa trên interaction
- **Ưu điểm**: Diversity cao, serendipity discovery
- **Nhược điểm**: Cold start, popularity bias

### 1.3. Trending Analysis (Phân tích Xu hướng)
- **Nguyên lý**: Khuyến nghị những thú cưng đang "hot trend"
- **Trọng số**: 20% trong hybrid algorithm
- **Cách thức hoạt động**:
  - Phân tích pets được xem/mua nhiều gần đây
  - Recency multiplier (30 ngày: 2x, 90 ngày: 1.5x)
  - Diverse trending từ nhiều categories
- **Ưu điểm**: Bắt kịp xu hướng, fresh content
- **Nhược điểm**: Có thể thiếu personalization

### 1.4. Association Rules (Luật Kết hợp)
- **Nguyên lý**: "Khách hàng mua X thường mua Y"
- **Trọng số**: 10% trong hybrid algorithm
- **Thuật toán**: Apriori Algorithm
- **Cách thức hoạt động**:
  - Phân tích patterns trong order history
  - Min support = 0.01, Min confidence = 0.3
  - Gợi ý breeds thường được mua cùng nhau
- **Ưu điểm**: Cross-selling tốt, business value cao
- **Nhược điểm**: Cần nhiều transaction data

### 1.5. Hybrid Approach (Phương pháp Kết hợp)
- **Nguyên lý**: Kết hợp weighted của tất cả algorithms
- **Cách thức hoạt động**:
  - Content-based: 40%
  - Collaborative: 30%
  - Trending: 20%
  - Association: 10%
  - Deduplication và score normalization
- **Ưu điểm**: Tận dụng ưu điểm của tất cả methods
- **Nhược điểm**: Complexity cao, tuning khó

### 1.6. Personalized Recommendations (Khuyến nghị Cá nhân hóa)
- **Nguyên lý**: Multi-phase targeting với BREED-FIRST approach
- **Phases**:
  - **Phase 1**: Breed-specific targeting (scores 0.85-0.95)
  - **Phase 2**: Category-level fallback (scores 0.45-0.65)
  - **Phase 3**: General discovery (score 0.6)

## 2. Hệ thống Scoring và Weighting

### 2.1. Interaction Weights
```dart
enum InteractionType {
  view,       // Weight: 1.0
  search,     // Weight: 1.5
  favorite,   // Weight: 3.0
  cart,       // Weight: 4.0
  purchase,   // Weight: 5.0
}
```

### 2.2. Recency Multipliers
- **0-30 ngày**: 2.0x (rất gần đây)
- **30-90 ngày**: 1.5x (gần đây)
- **>90 ngày**: 1.0x (cũ)

### 2.3. Dynamic Thresholds
- **Breed threshold**: 60% của top breed score
- **Category threshold**: Dựa trên số breed matches
- **Quality threshold**: Minimum score để qualify

## 3. Kiến trúc Dữ liệu

### 3.1. Data Sources Priority
1. **Orders** (Highest - 5.0): Purchase history, strongest signal
2. **Favorites** (High - 3.0): Explicit user preference
3. **Search History** (Medium - 1.5): User intent
4. **Viewed Pets** (Low - 1.0): Browse behavior

### 3.2. Firestore Collections
- `Pets`: Thông tin thú cưng (name, category, breed, price, imageUrl)
- `orders`: Lịch sử mua hàng với timestamp
- `ViewedPets/{userId}/pets`: Lịch sử xem
- `UserFav/{userId}/favorites`: Danh sách yêu thích
- `SearchHistory/{userId}/searches`: Lịch sử tìm kiếm

## 4. Cache System Architecture

### 4.1. SearchRecommendationsCache
- **Storage**: SharedPreferences
- **Expiry**: 1 giờ auto-expiry
- **Serialization**: JSON format
- **Strategy**: Cache-first loading

### 4.2. SearchRecommendationsManager
- **Background service**: Timer.periodic mỗi 1 giờ
- **Auto-refresh**: Transparent background updates
- **Error handling**: Graceful degradation

### 4.3. Cache Flow
```
User Request → Check Cache → 
  Valid Cache: Return cached results
  Invalid Cache: Fetch fresh → Update cache → Return results
```

## 5. Performance Optimizations

### 5.1. Query Optimizations
- Firestore limit() để tránh over-fetching
- where() clauses cho targeted queries
- orderBy() với indexes cho performance

### 5.2. Memory Management
- Unique pet ID tracking để avoid duplicates
- Limited result sets (default 10-20 items)
- Lazy loading cho large datasets

### 5.3. Background Processing
- Async/await cho non-blocking operations
- Background cache refresh
- Error handling với fallbacks

## 6. Logging và Monitoring

### 6.1. RecommendationLogger
- **Comprehensive tracking**: Algorithm execution times
- **Performance metrics**: Response times, result counts
- **Algorithm analysis**: Score distributions, type breakdowns
- **Workspace integration**: Save logs to project files

### 6.2. Debug Information
- User preference analysis
- Algorithm execution flow
- Score calculation details
- Performance bottlenecks

## 7. Algorithm Flow Detail

### 7.1. BREED-FIRST Targeting Algorithm
```
1. Analyze user preferences:
   - Orders (highest priority)
   - Favorites
   - Viewed pets
   - Search history

2. Calculate dynamic thresholds:
   - Top breed score identification
   - 60% threshold calculation
   - Qualified breeds selection (max 5)

3. PHASE 1 - Breed-specific targeting:
   - For each qualified breed
   - Score: 0.85-0.95 (very high)
   - Reason: "Phù hợp với sở thích về [breed]"

4. PHASE 2 - Category-level fallback:
   - If < 2 good breed matches
   - Score: 0.45-0.65 (medium)
   - Reason: "Khám phá thêm trong danh mục [category]"

5. PHASE 3 - General recommendations:
   - Diverse categories (Dogs, Cats, Birds, Fish)
   - Score: 0.6 (good)
   - Reason: "Khám phá thú cưng mới"
```

### 7.2. Hybrid Combination Algorithm
```
1. Execute all algorithms in parallel:
   - Content-based (40% weight)
   - Collaborative (30% weight)
   - Trending (20% weight)
   - Association (10% weight)

2. Combine results:
   - Weighted score calculation
   - Duplicate removal by petId
   - Score normalization

3. Final ranking:
   - Sort by combined score
   - Limit to requested count
   - Return ranked list
```

## 8. Business Logic

### 8.1. Personalization Strategy
- **New users**: Trending + General recommendations
- **Active users**: Content-based + Collaborative
- **Power users**: All algorithms with full weighting

### 8.2. Diversity Mechanisms
- Category distribution balancing
- Breed variety enforcement
- Score-based ranking để avoid monotony

### 8.3. Business Metrics
- **Click-through rate**: Tỷ lệ click vào recommendations
- **Conversion rate**: Tỷ lệ mua từ recommendations
- **Engagement**: Time spent với recommended pets
- **Discovery**: New category/breed exploration

## 9. Scalability Considerations

### 9.1. Current Architecture
- Firebase Firestore: NoSQL horizontal scaling
- Flutter BLoC: Reactive state management
- Cache layer: Reduce server load

### 9.2. Future Enhancements
- **Machine Learning**: TensorFlow Lite models
- **Real-time**: Stream-based recommendations
- **A/B Testing**: Algorithm comparison
- **Advanced Analytics**: User behavior insights

## 10. Security và Privacy

### 10.1. Data Protection
- User data anonymization
- GDPR compliance considerations
- Secure Firebase rules

### 10.2. Recommendation Privacy
- No cross-user data exposure
- Aggregated analytics only
- User control over recommendations

## Kết luận

Hệ thống khuyến nghị Pet Shop implement một architecture phức tạp và hiện đại với:

1. **6 thuật toán** khuyến nghị được tối ưu hóa
2. **Multi-phase targeting** với BREED-FIRST approach
3. **Intelligent caching** với auto-refresh
4. **Comprehensive logging** cho monitoring và debugging
5. **Clean Architecture** để maintainability và scalability

Hệ thống có khả năng **personalization cao**, **performance tốt** nhờ cache, và **monitoring comprehensive** để continuous improvement.