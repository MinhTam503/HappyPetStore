# Tổng Quan Hệ Thống Khuyến Nghị (Recommendation) – HappyPetStore

Tài liệu này mô tả mục tiêu, kiến trúc, luồng dữ liệu, thuật toán, cấu hình và cách vận hành hệ thống khuyến nghị nội dung (Content-Based Filtering) của HappyPetStore.

## Mục Tiêu
- Tăng khả năng khám phá thú cưng phù hợp với sở thích người dùng.
- Đáp ứng nhanh, tận dụng cache và có fallback an toàn khi dữ liệu khan hiếm.
- Dễ quan sát, dễ vận hành và mở rộng.

## Kiến Trúc Tổng Quan
- Ứng dụng Flutter (mobile/web) điều phối khuyến nghị qua các Service và BLoC được tiêm bằng DI.
- Nguồn dữ liệu: Firestore + cache nhẹ (SharedPreferences/in-memory).
- Xử lý: Content-Based Filtering dựa trên đặc trưng của thú cưng (breed, category, tags, price, availability) + kết hợp độ phổ biến (popularity) và tính gần đây (recency).
- Phân phối: `RecommendationBloc` phát trạng thái; UI lắng nghe và render danh sách.

### Thành Phần Chính (tham chiếu code)
- `lib/core/di/recommendation_di.dart`: Khởi tạo DI cho stack khuyến nghị.
- `lib/core/services/recommendation_tracking_service.dart`: Theo dõi sự kiện phiên (xem, click) để cải thiện gợi ý.
- `lib/core/services/search_recommendations_manager.dart`: Quản lý chu kỳ làm mới tự động; hợp nhất dữ liệu từ cache & Firestore.
- `lib/presentation/bloc/recommendation/recommendation_bloc.dart`: Phát kết quả khuyến nghị tới UI.
- `lib/data/repositories/viewed_pets/recent_pets_repository_impl.dart`: Lưu dấu vết “đã xem gần đây” để làm hạt giống khởi tạo.
- `lib/presentation/bloc/viewedPets/recent_pets_bloc.dart`: Xuất danh sách đã xem gần đây.

## Nguồn Dữ Liệu
- Firestore:
  - `Pets`: Danh mục thú cưng với thuộc tính (giống/breed, danh mục/category, tags, giá, trạng thái).
  - `users/*`: Tuỳ chọn và hoạt động của người dùng (nếu có).
- Cache cục bộ:
  - Recent views (SharedPreferences/Firestore sync qua `RecentPetsRepositoryImpl`).
  - Cache phiên trong các manager để tối ưu hiệu năng.

## Thuật Toán – Content-Based Filtering
- Trích xuất đặc trưng từ mỗi pet (vector hoá các trường: breed, category, tags, tầm giá, availability).
- Tính độ tương đồng (ví dụ: Cosine similarity/Jaccard cho tags, khoảng cách giá). 
- Xếp hạng theo điểm tổng hợp: similarity + boosts (recency, popularity).
- Áp bộ lọc:
  - Chỉ gợi ý pet `isAvailable == true`.
  - Ẩn pet đang reserved/sold.
  - Tuỳ chọn ràng buộc theo tầm giá, danh mục.

## Luồng Xử Lý
1. Khởi động ứng dụng → `setupRecommendationDI()` tạo DI cho khuyến nghị.
2. `RecommendationTrackingService().initialize()` bật theo dõi phiên.
3. `SearchRecommendationsManager().initialize()` đăng ký timer tự refresh (10 phút).
4. `RecommendationBloc` lấy dữ liệu, tính điểm và phát trạng thái:
   - Loading → Results → Empty → Error (kèm fallback an toàn).
5. UI subscribe và render card/danh sách.

### Sự kiện & Trạng thái (RecommendationBloc)
- Sự kiện:
  - `LoadRecommendations(userId, types?, limit?)`: tải tổng hợp (ưu tiên cá nhân hoá, cho phép lọc theo `RecommendationType`).
  - `LoadRecommendationsByType(userId, type, limit?)`: tải theo loại riêng (ví dụ `RecommendationType.contentBased`).
  - `LoadPersonalizedRecommendations(userId, limit?)`: khuyến nghị cá nhân hoá (kết hợp đặc trưng + hành vi người dùng).
  - `LoadHybridRecommendations(userId, limit?)`: khuyến nghị kết hợp (content-based + tín hiệu phụ trợ khi có).
  - `LoadSearchRecommendations(userId, searchQuery?, limit?)`: gợi ý phục vụ tìm kiếm, hiện tại ưu tiên content-based.
  - `TrackUserInteraction(userId, petId, type, metadata?)`: ghi nhận tương tác (view/click) để cải thiện hồ sơ.
  - `LoadUserProfile(userId)`: tải hồ sơ người dùng + phân tích hành vi.
  - `LoadSimilarUsers(userId, limit?)`: tìm người dùng tương tự (phục vụ mở rộng khuyến nghị).
  - `RefreshRecommendations(userId)`: làm mới bằng cách kích hoạt lại cá nhân hoá.
- Trạng thái:
  - `RecommendationInitial`, `RecommendationLoading`, `RecommendationLoaded` (kèm `recommendationsByType`, `message`),
  - `RecommendationEmpty` (mặc định thông điệp tiếng Việt), `RecommendationError`,
  - `UserProfileLoaded` (kèm `behaviorAnalysis`), `SimilarUsersLoaded`, `InteractionTracked` (tuỳ chọn).

## Cấu Hình
- Ngưỡng và tham số (ví dụ):
  - `similarityThreshold`: điểm tương đồng tối thiểu.
  - `maxRecommendations`: số lượng gợi ý tối đa mỗi phiên.
  - Trọng số cho recency/popularity.
- Thời gian:
  - Tự động refresh mỗi 10 phút (có log console).

## API (Flutter)
- Khởi tạo:
  ```dart
  await setupRecommendationDI();
  await RecommendationTrackingService().initialize();
  await SearchRecommendationsManager().initialize();
  ```
- Bloc:
  ```dart
  final bloc = getIt<RecommendationBloc>();
  bloc.stream.listen((state) {
    // xử lý RecommendationLoaded([...]) hoặc các trạng thái khác
  });
  ```
- Theo dõi sự kiện:
  ```dart
  RecommendationTrackingService().trackView(petId);
  RecommendationTrackingService().trackClick(petId);
  ```

## Quan Sát & Log
- Log khởi động:
  - "🎯 Recommendation system initialized successfully"
  - Thông báo timer auto-refresh.
- Lưu ý web:
  - Có thể gặp `MissingPluginException` (path_provider) trên web; logger sẽ tự bỏ qua.

## Fallback & Độ Bền Vững
- Dữ liệu thưa: fallback sang danh sách phổ biến (popular).
- Cache lỗi/hết hạn: làm mới từ Firestore, hạn chế tác vụ nặng khi bộ nhớ thấp.
- Giới hạn nền tảng web: bỏ qua ghi file log.

## Khắc Phục Sự Cố
- Zone mismatch khi khởi động:
  - Đảm bảo `WidgetsFlutterBinding.ensureInitialized()` và `runApp()` cùng zone.
- `MissingPluginException: getApplicationDocumentsDirectory` (web):
  - Hành vi mong đợi; bọc an toàn hoặc vô hiệu ghi file.
- Loading dài:
  - Kiểm tra rules/index Firestore và mạng.
  - Xem `RecommendationBloc` để đảm bảo có fallback.

## Định Hướng Nâng Cấp
- Kết hợp Collaborative Filtering (embedding người dùng).
- Tín hiệu thời gian thực (wishlist, cart event, likes).
- Pipeline tổng hợp server-side ban đêm.
- A/B testing cho biến thể xếp hạng.

## Bản Đồ File & Lớp
- DI: `lib/core/di/recommendation_di.dart`
- Bloc: `lib/presentation/bloc/recommendation/recommendation_bloc.dart`
- Manager: `lib/core/services/search_recommendations_manager.dart`
- Tracking: `lib/core/services/recommendation_tracking_service.dart`
- Recent Views: `lib/data/repositories/viewed_pets/recent_pets_repository_impl.dart`

## Bảo Mật & Quyền Riêng Tư
- Chỉ theo dõi hoạt động không nhạy cảm (view/click).
- Tuân thủ luật bảo mật Firebase; quản lý user ID an toàn.
- Không lưu PII ngoài hồ sơ người dùng Firestore.

---
Nếu cần phụ lục kỹ thuật (ví dụ code, công thức tính similarity, cách vector hoá đặc trưng), tôi có thể bổ sung theo yêu cầu.
