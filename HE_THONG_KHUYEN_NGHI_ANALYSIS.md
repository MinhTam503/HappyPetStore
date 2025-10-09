UI Request → RecommendationBloc → RecommendationUseCase → RecommendationRepositoryImpl → Firebase
     ↑                                                                                        ↓
Cache Check ← SearchRecommendationsCache ← Background Refresh ← Algorithm Results
# Phân tích Chi tiết Hệ thống Khuyến nghị Pet Shop

## 📋 Tổng quan Hệ thống

Hệ thống khuyến nghị Pet Shop là một hệ thống phức tạp được xây dựng theo kiến trúc **Clean Architecture** với **6 thuật toán chính** và hệ thống cache thông minh. Hệ thống sử dụng **Firebase Firestore** làm cơ sở dữ liệu và **Flutter BLoC** để quản lý state.

---

## 🧠 6 Thuật toán Khuyến nghị Chính

### 1. **Content-Based Filtering** (Lọc dựa trên Nội dung)
- **Trọng số**: 40% trong hybrid algorithm
- **Nguyên lý**: Phân tích thuộc tính của thú cưng và sở thích người dùng
- **File chính**: `lib/data/repositories/recommendation_repository_impl.dart` (dòng 379-436)
- **Cách hoạt động**:
  - Phân tích lịch sử mua hàng, yêu thích, xem
  - So khớp category và breed preferences
  - Scoring dựa trên mức độ phù hợp (score: 0.9 cho category match)
- **Code implementation**:
```dart
Future<List<RecommendationItem>> getContentBasedRecommendations(String userId, {int? limit}) async {
  final userPreferences = await _analyzeUserPreferences(userId);
  
  if (userPreferences['favoriteCategories'].isNotEmpty) {
    final favoriteCategories = userPreferences['favoriteCategories'] as List<String>;
    
    for (String category in favoriteCategories.take(3)) {
      final snapshot = await firestore
          .collection('Pets')
          .where('category', isEqualTo: category)
          .get();
      
      // Create RecommendationItem with score 0.9 for category match
    }
  }
}
```

### 2. **Collaborative Filtering** (Lọc Cộng tác)
- **Trọng số**: 30% trong hybrid algorithm
- **Nguyên lý**: "Người có sở thích tương tự thích những thú cưng tương tự"
- **File chính**: `lib/data/repositories/recommendation_repository_impl.dart` (dòng 438-516)
- **Cách hoạt động**:
  - Tìm user có category preferences tương tự
  - Recommend pets popular trong nhóm user đó
  - Score: 0.8 cho collaborative recommendations
- **Code implementation**:
```dart
Future<List<RecommendationItem>> getCollaborativeRecommendations(String userId, {int? limit}) async {
  final userPreferences = await _analyzeUserPreferences(userId);
  final userFavoriteCategories = userPreferences['favoriteCategories'] as List<String>;
  
  for (String category in userFavoriteCategories.take(2)) {
    // Find pets that other users with similar preferences liked
    final isAlreadyViewed = await _isPetAlreadyInteractedWith(userId, doc.id);
    if (!isAlreadyViewed) {
      // Score: 0.8 for collaborative recommendations
    }
  }
}
```

### 3. **Trending Analysis** (Phân tích Xu hướng)
- **Trọng số**: 20% trong hybrid algorithm
- **Nguyên lý**: Khuyến nghị những thú cưng đang "hot trend"
- **File chính**: `lib/data/repositories/recommendation_repository_impl.dart` (dòng 518-559)
- **Cách hoạt động**:
  - Phân tích pets được xem/mua nhiều gần đây
  - Diverse trending từ nhiều categories
  - Score: 0.7 cho trending pets
- **Code implementation**:
```dart
Future<List<RecommendationItem>> getTrendingPets({int? limit}) async {
  final categories = ['Dogs', 'Cats', 'Birds', 'Fish'];
  final limitPerCategory = math.max(1, (limit ?? 20) ~/ categories.length);
  
  for (final category in categories) {
    final snapshot = await firestore
        .collection('Pets')
        .where('category', isEqualTo: category)
        .limit(limitPerCategory)
        .get();
    // Score: 0.7 for trending
  }
}
```

### 4. **Association Rules** (Luật Kết hợp - Apriori Algorithm)
- **Trọng số**: 10% trong hybrid algorithm
- **Nguyên lý**: "Khách hàng mua X thường mua Y"
- **File chính**: 
  - `lib/domain/usecases/apriori_usecase.dart` (toàn bộ file)
  - `lib/data/repositories/apriori_repository_impl.dart`
- **Thuật toán**: Apriori Algorithm với min support = 0.01, min confidence = 0.3
- **Cách hoạt động**:
```dart
Map<String, Map<String, BreedAssociation>> analyzeBreedAssociations(
  List<BreedTransaction> transactions, {
  double minSupport = 0.1,
  double minConfidence = 0.3,
}) {
  // 1. Đếm tần suất xuất hiện của từng breed
  for (var transaction in transactions) {
    for (var breed in transaction.breeds) {
      breedCounts[breed] = (breedCounts[breed] ?? 0) + 1;
    }
  }
  
  // 2. Đếm tần suất xuất hiện của từng cặp breeds
  for (var transaction in transactions) {
    for (int i = 0; i < transaction.breeds.length; i++) {
      for (int j = i + 1; j < transaction.breeds.length; j++) {
        // Count breed pairs
      }
    }
  }
  
  // 3. Tính confidence: P(B|A) = count(A,B) / count(A)
  double confidenceAB = pairCount / (breedCounts[breedA] ?? 1);
}
```

### 5. **Hybrid Approach** (Phương pháp Kết hợp)
- **File chính**: `lib/domain/usecases/recommendation_usecase.dart` (dòng 30-80)
- **Nguyên lý**: Kết hợp weighted của tất cả algorithms
- **Cách hoạt động**:
```dart
Future<List<RecommendationItem>> getHybridRecommendations({
  required String userId,
  int limit = 10,
}) async {
  // Get different types of recommendations with weights
  final contentBased = await _repository.getContentBasedRecommendations(
    userId, limit: (limit * 0.4).round(), // 40%
  );
  
  final collaborative = await _repository.getCollaborativeRecommendations(
    userId, limit: (limit * 0.3).round(), // 30%
  );
  
  final trending = await _repository.getTrendingPets(
    limit: (limit * 0.2).round(), // 20%
  );
  
  final association = await _repository.getAssociationRecommendations(
    userId, limit: (limit * 0.1).round(), // 10%
  );

  // Combine and deduplicate
  final allRecommendations = <RecommendationItem>[];
  final seenPetIds = <String>{};
  // Priority-based combination...
}
```

### 6. **Personalized Recommendations** (Khuyến nghị Cá nhân hóa - BREED-FIRST Targeting)
- **File chính**: `lib/data/repositories/recommendation_repository_impl.dart` (dòng 35-280)
- **Nguyên lý**: Multi-phase targeting với BREED-FIRST approach
- **3 Phase Algorithm**:

#### **PHASE 1: BREED-SPECIFIC TARGETING**
```dart
// Calculate dynamic breed threshold - 60% of top breed score
final topBreedScore = breedScores.values.isNotEmpty ? 
    breedScores.values.reduce((a, b) => a > b ? a : b) : 0;
final threshold = (topBreedScore * 0.6).round();

final qualifiedBreeds = favoriteBreeds.where((breed) {
  final score = breedScores[breed] ?? 0;
  return score >= threshold;
}).take(5).toList(); // Max 5 breeds

// High scores (0.85-0.95) for exact breed matches
final recommendationScore = breedScore > 15 ? 0.98 : 
                          breedScore > 10 ? 0.92 : 
                          breedScore > 5 ? 0.85 : 0.75;
```

#### **PHASE 2: CATEGORY-LEVEL FALLBACK**
```dart
// Lower scores (0.45-0.65) than breed-specific
final recommendationScore = score > 20 ? 0.65 : 
                          score > 10 ? 0.55 : 
                          score > 5 ? 0.45 : 0.35;
```

#### **PHASE 3: GENERAL RECOMMENDATIONS**
```dart
// Diverse category coverage (Dogs, Cats, Birds, Fish)
final categories = ['Dogs', 'Cats', 'Birds', 'Fish'];
// Score: 0.6 for general recommendations
```

---

## 🗂️ Kiến trúc File và Luồng chạy

### 📁 Cấu trúc thư mục chính:
```
lib/
├── presentation/
│   ├── bloc/recommendation/          # BLoC pattern cho state management
│   ├── pages/mobile/recommendation/  # UI pages
│   └── widgets/                      # Recommendation widgets
├── domain/
│   ├── entities/                     # Data models
│   ├── repositories/                 # Abstract interfaces
│   └── usecases/                     # Business logic
├── data/repositories/                # Implementation của algorithms
├── core/
│   ├── services/                     # Cache và utilities
│   └── di/                          # Dependency injection
└── services/                        # Logging services
```

### 🔄 Luồng chạy chi tiết:

#### **1. Khởi tạo (Initialization)**
```
main.dart → dependency injection → RecommendationBloc initialization
```
- **File**: `lib/core/di/recommendation_di.dart`
- **Setup**: Repository, UseCase, BLoC dependencies

#### **2. UI Request Flow**
```
User Interface → RecommendationBloc → RecommendationUseCase → RecommendationRepositoryImpl → Firebase
```

**Files trong luồng**:
1. **UI Layer**: 
   - `lib/presentation/pages/mobile/recommendation/recommendation_demo_page.dart`
   - `lib/presentation/widgets/recommendation_section.dart`
   - `lib/presentation/widgets/search_recommendations_section.dart`

2. **BLoC Layer**: 
   - `lib/presentation/bloc/recommendation/recommendation_bloc.dart`
   - Events: `lib/presentation/bloc/recommendation/recommendation_event.dart`
   - States: `lib/presentation/bloc/recommendation/recommendation_state.dart`

3. **Domain Layer**:
   - `lib/domain/usecases/recommendation_usecase.dart`
   - `lib/domain/repositories/recommendation_repository.dart`

4. **Data Layer**:
   - `lib/data/repositories/recommendation_repository_impl.dart`

#### **3. Algorithm Execution Flow**

**Bước 1: User Preference Analysis**
```dart
// File: recommendation_repository_impl.dart - method _analyzeUserPreferences()
1. Lấy dữ liệu từ Firebase:
   - Orders (weight: 5.0) - Highest priority
   - ViewedPets (weight: 1.0)  
   - Favorites (weight: 3.0)
   - SearchHistory (weight: 1.5)

2. Tính toán recency multiplier:
   - 0-30 ngày: 2.0x
   - 30-90 ngày: 1.5x
   - >90 ngày: 1.0x

3. Generate category & breed scores
```

**Bước 2: Algorithm Selection & Execution**
```dart
// File: recommendation_usecase.dart
switch (type) {
  case RecommendationType.contentBased:
    return await _repository.getContentBasedRecommendations(userId, limit: limit);
  case RecommendationType.collaborative:
    return await _repository.getCollaborativeRecommendations(userId, limit: limit);
  case RecommendationType.trending:
    return await _repository.getTrendingPets(limit: limit);
  case RecommendationType.association:
    return await _repository.getAssociationRecommendations(userId, limit: limit);
  case RecommendationType.hybrid:
    return await getHybridRecommendations(userId: userId, limit: limit);
  case RecommendationType.personalized:
    final response = await getPersonalizedRecommendations(userId: userId, limit: limit);
    return response.items;
}
```

**Bước 3: Cache Management**
```dart
// File: lib/core/services/search_recommendations_cache.dart
1. Check cache validity (1 hour expiry)
2. Return cached results if valid
3. Fetch fresh data if cache expired
4. Update cache with new results
```

#### **4. Detailed Algorithm Flow**

**Content-Based Algorithm**:
```
Input: userId
↓
_analyzeUserPreferences(userId) → Firebase queries (orders, favorites, viewed, search)
↓
Extract favoriteCategories & categoryScores
↓
For each category: Query Firebase.collection('Pets').where('category', '==', category)
↓
Create RecommendationItem with score 0.9
↓
Output: List<RecommendationItem>
```

**BREED-FIRST Personalized Algorithm**:
```
Input: userId, limit
↓
_analyzeUserPreferences(userId) → Get breedScores & categoryScores
↓
PHASE 1: Calculate dynamic threshold (60% of top breed score)
↓
For qualified breeds: Query pets with exact breed match
↓ 
Add pets with high scores (0.85-0.95)
↓
PHASE 2: If insufficient results, add category-level matches
↓
Add pets with medium scores (0.45-0.65)  
↓
PHASE 3: Add general recommendations from diverse categories
↓
Add pets with score 0.6
↓
Output: Limited & ranked RecommendationItem list
```

**Apriori Association Algorithm**:
```
Input: inputBreeds
↓
repository.getBreedTransactions() → Firebase orders analysis
↓
analyzeBreedAssociations() → Calculate breed pair frequencies
↓
Apply minSupport (0.01) & minConfidence (0.3) filters
↓
Generate BreedAssociation rules
↓
suggestBreedsFromMultiple() → Score & rank breed suggestions
↓
repository.getPetsByBreeds() → Get actual pets
↓
Output: List<SuggestedPet> with confidence scores
```

---

## 🎯 Interaction Weights & Scoring System

### Interaction Types:
```dart
enum InteractionType {
  view,       // Weight: 1.0
  search,     // Weight: 1.5
  favorite,   // Weight: 3.0
  cart,       // Weight: 4.0
  purchase,   // Weight: 5.0
}
```

### Scoring Formulas:

**Breed-specific targeting**:
```dart
final recommendationScore = breedScore > 15 ? 0.98 : // Very high preference
                          breedScore > 10 ? 0.92 : // High preference  
                          breedScore > 5 ? 0.85 :  // Medium preference
                          0.75; // Lower preference
```

**Category-level fallback**:
```dart
final recommendationScore = score > 20 ? 0.65 : 
                          score > 10 ? 0.55 : 
                          score > 5 ? 0.45 : 
                          0.35;
```

**Recency Multiplier**:
```dart
final recencyMultiplier = daysSinceOrder <= 30 ? 2.0 : 
                        daysSinceOrder <= 90 ? 1.5 : 1.0;
```

---

## 💾 Cache System Architecture

### Cache Implementation:
- **File**: `lib/core/services/search_recommendations_cache.dart`
- **Storage**: SharedPreferences
- **Expiry**: 1 giờ auto-expiry
- **Strategy**: Cache-first loading
- **Background Service**: `lib/core/services/search_recommendations_manager.dart`

### Cache Flow:
```
User Request → SearchRecommendationsCache.getRecommendations()
↓
Check isCacheValid() → Compare with 1-hour expiry
↓
If valid: Return cached JSON data
↓
If invalid: Trigger fresh data fetch → Update cache → Return new data
```

### Auto-refresh Background Service:
```dart
// File: search_recommendations_manager.dart
Timer.periodic(Duration(hours: 1), (timer) {
  _refreshRecommendations(); // Background cache refresh
});
```

---

## 📊 Logging & Monitoring System

### Comprehensive Logging:
- **File**: `lib/services/recommendation_logger.dart`
- **Features**:
  - Algorithm execution tracking
  - Performance metrics
  - User preference analysis
  - Score distribution logging

### Logging Methods:
```dart
// Session tracking
RecommendationLogger.logSessionStart()
RecommendationLogger.logAlgorithmExecution()
RecommendationLogger.logHybridCombination()
RecommendationLogger.logSessionComplete()

// Performance monitoring  
RecommendationLogger.logDataFetching()
RecommendationLogger.logPerformance()

// Analysis export
RecommendationLogger.saveToWorkspace()
RecommendationLogger.createAnalysisFile()
```

---

## 🔄 BLoC State Management Pattern

### States:
```dart
// File: recommendation_state.dart
abstract class RecommendationState
class RecommendationInitial extends RecommendationState
class RecommendationLoading extends RecommendationState  
class RecommendationLoaded extends RecommendationState
class RecommendationError extends RecommendationState
```

### Events:
```dart
// File: recommendation_event.dart
class LoadRecommendations extends RecommendationEvent
class LoadRecommendationsByType extends RecommendationEvent
class LoadHybridRecommendations extends RecommendationEvent
class LoadPersonalizedRecommendations extends RecommendationEvent
class LoadSearchRecommendations extends RecommendationEvent
class TrackUserInteraction extends RecommendationEvent
```

### BLoC Flow:
```
UI Widget → Dispatch Event → RecommendationBloc
↓
BLoC calls RecommendationUseCase methods
↓
UseCase calls Repository implementation
↓
Repository queries Firebase & applies algorithms
↓
Results flow back: Repository → UseCase → BLoC
↓
BLoC emits new state → UI rebuilds with new data
```

---

## 🗄️ Firebase Firestore Collections

### Data Structure:
```
Firestore Database:
├── Pets/                    # Pet details (name, category, breed, price, imageUrl)
├── orders/                  # Purchase history với timestamp & items
├── ViewedPets/{userId}/pets # User browse history
├── favorites/               # User favorite pets list
└── SearchHistory/{userId}/  # User search queries với timestamps
```

### Query Examples:
```dart
// Get user orders for preference analysis
firestore.collection('orders')
  .where('userId', isEqualTo: userId)
  .orderBy('timestamp', descending: true)
  .limit(10).get()

// Get pets by category for content-based
firestore.collection('Pets')
  .where('category', isEqualTo: category)
  .get()

// Get pets by breed for BREED-FIRST targeting  
firestore.collection('Pets')
  .where('breed', isEqualTo: breed)
  .get()
```

---

## 🚀 Performance Optimizations

### Query Optimizations:
- **Firestore limits**: Avoid over-fetching với limit() clauses
- **Targeted queries**: where() clauses với proper indexing
- **Lazy loading**: Load only needed data

### Memory Management:
- **Deduplication**: Unique pet ID tracking
- **Limited results**: Default 10-20 items như Netflix/Amazon
- **Background processing**: Async/await cho non-blocking operations

### Error Handling:
- **Graceful degradation**: Fallback mechanisms
- **Try-catch wrapping**: Comprehensive error handling
- **Default recommendations**: Backup when algorithms fail

---

## 🎯 Real-world Algorithm Features

### Industry-standard Approaches:
1. **Limited results**: 10-20 items như Netflix, Amazon
2. **Multi-algorithm combination**: Weighted hybrid approach
3. **Cache-first loading**: Instant UI response
4. **Background refresh**: Transparent updates
5. **Diversity mechanisms**: Category distribution balancing

### Business Logic:
- **New users**: Trending + General recommendations
- **Active users**: Content-based + Collaborative  
- **Power users**: Full hybrid algorithm với personalization

---

## 📈 Metrics & Analytics

### Trackable Metrics:
- **Click-through rate**: UI interaction tracking
- **Algorithm performance**: Execution time monitoring
- **User engagement**: Preference analysis depth
- **Cache efficiency**: Hit/miss ratio tracking

### Performance Monitoring:
```dart
// Real-time performance tracking
final startTime = DateTime.now();
// Algorithm execution...
final endTime = DateTime.now();
final processingTime = endTime.difference(startTime).inMilliseconds;

await RecommendationLogger.logPerformance({
  'Processing Time': '${processingTime}ms',
  'Total Recommendations': items.length,
  'User Has Preferences': favoriteCategories.isNotEmpty,
});
```

---

## 🔮 Kết luận

Hệ thống khuyến nghị Pet Shop implement một architecture hiện đại và phức tạp với:

### ✅ **Điểm mạnh**:
1. **6 thuật toán** được tối ưu hóa cho domain cụ thể
2. **BREED-FIRST approach** với dynamic thresholds
3. **Clean Architecture** đảm bảo maintainability
4. **Intelligent caching** với auto-refresh
5. **Comprehensive logging** cho debugging & optimization
6. **Industry-standard patterns** (BLoC, Dependency Injection)
7. **Real-time performance monitoring**

### 🎯 **Technical Highlights**:
- **Multi-phase targeting algorithm** với 3 phases
- **Weighted hybrid combination** của 6 algorithms
- **Firebase integration** với optimized queries
- **Cache system** với 1-hour auto-expiry
- **Background services** cho seamless UX
- **Comprehensive error handling** và fallback mechanisms

### 📊 **Scalability Ready**:
- **Horizontal scaling** với Firebase Firestore
- **Microservices architecture** separation
- **Performance monitoring** cho optimization
- **A/B testing framework** ready
- **Machine learning integration** potential

Hệ thống này đại diện cho một implementation **production-ready** của recommendation system với **khả năng mở rộng cao** và **performance tốt**.