import 'dart:async';
import 'package:pet_shop/core/services/search_recommendations_cache.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/domain/usecases/recommendation_usecase.dart';
import 'package:pet_shop/data/repositories/recommendation_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/config/recommendation_config.dart';

/// Service để quản lý cache gợi ý tìm kiếm với auto-refresh
class SearchRecommendationsManager {
  static final SearchRecommendationsManager _instance = SearchRecommendationsManager._internal();
  factory SearchRecommendationsManager() => _instance;
  SearchRecommendationsManager._internal();

  Timer? _refreshTimer;
  bool _isInitialized = false;
  late UserManager _userManager;
  late RecommendationUseCase _recommendationUseCase;

  /// Khởi tạo service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _userManager = UserManager();
    _recommendationUseCase = RecommendationUseCase(
      RecommendationRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        userManager: _userManager,
      ),
    );

    // Bắt đầu auto-refresh timer (mỗi 1 giờ)
    _startAutoRefresh();

    // Load ngay khi khởi tạo nếu user đã đăng nhập
    await _loadInitialRecommendations();

    _isInitialized = true;
    print('🔄 SearchRecommendationsManager initialized');
  }

  /// Bắt đầu timer auto-refresh
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _refreshRecommendations();
    });
    print('⏰ Auto-refresh timer started (every 10 minutes)');
  }

  /// Load gợi ý ban đầu
  Future<void> _loadInitialRecommendations() async {
    try {
      await _userManager.initialize();
      if (_userManager.isLoggedIn) {
        final userId = _userManager.currentUserId;
        if (userId != null) {
          // Kiểm tra cache có hợp lệ không
          final isCacheValid = await SearchRecommendationsCache.isCacheValid(userId);
          if (!isCacheValid) {
            print('📭 No valid cache found, loading fresh recommendations');
            await _loadAndCacheRecommendations(userId);
          } else {
            print('📦 Valid cache found, no need to refresh');
          }
        }
      }
    } catch (e) {
      print('❌ Error loading initial recommendations: $e');
    }
  }

  /// Refresh gợi ý (called by timer hoặc manual)
  Future<void> _refreshRecommendations() async {
    try {
      await _userManager.initialize();
      if (_userManager.isLoggedIn) {
        final userId = _userManager.currentUserId;
        if (userId != null) {
          print('🔄 Auto-refreshing recommendations for user $userId');
          await _loadAndCacheRecommendations(userId);
        }
      }
    } catch (e) {
      print('❌ Error refreshing recommendations: $e');
    }
  }

  /// Load từ server và cache
  Future<void> _loadAndCacheRecommendations(String userId) async {
    try {
      final response = await _recommendationUseCase.getPersonalizedRecommendations(
        userId: userId,
        limit: RecommendationConfig.defaultLimit,
      );

      if (response.items.isNotEmpty) {
        await SearchRecommendationsCache.saveRecommendations(
          userId: userId,
          recommendations: response.items,
        );
        print('✅ Refreshed and cached ${response.items.length} recommendations');
      }
    } catch (e) {
      print('❌ Error loading recommendations from server: $e');
    }
  }

  /// Manually refresh recommendations (public method)
  Future<void> refreshNow() async {
    print('🔄 Manual refresh triggered');
    await _refreshRecommendations();
  }

  /// Force clear cache và reload
  Future<void> forceClearAndReload() async {
    try {
      await SearchRecommendationsCache.clearCache();
      await _loadInitialRecommendations();
      print('🗑️ Cache cleared and reloaded');
    } catch (e) {
      print('❌ Error force clearing cache: $e');
    }
  }

  /// Get cache status information
  Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      await _userManager.initialize();
      if (!_userManager.isLoggedIn || _userManager.currentUserId == null) {
        return {
          'hasCache': false,
          'isValid': false,
          'lastCacheTime': null,
          'reason': 'User not logged in',
        };
      }

      final userId = _userManager.currentUserId!;
      final isValid = await SearchRecommendationsCache.isCacheValid(userId);
      final lastCacheTime = await SearchRecommendationsCache.getLastCacheTime();
      final cachedRecommendations = await SearchRecommendationsCache.getRecommendations(userId);

      return {
        'hasCache': cachedRecommendations != null,
        'isValid': isValid,
        'lastCacheTime': lastCacheTime,
        'cacheCount': cachedRecommendations?.length ?? 0,
        'userId': userId,
      };
    } catch (e) {
      return {
        'hasCache': false,
        'isValid': false,
        'lastCacheTime': null,
        'error': e.toString(),
      };
    }
  }

  /// Dispose service
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isInitialized = false;
    print('🔄 SearchRecommendationsManager disposed');
  }
}

/// Extension để dễ dàng sử dụng trong app
extension SearchRecommendationsManagerExtension on SearchRecommendationsManager {
  /// Debug method để xem trạng thái cache
  Future<void> printCacheStatus() async {
    final status = await getCacheStatus();
    print('📊 Cache Status:');
    print('  - Has Cache: ${status['hasCache']}');
    print('  - Is Valid: ${status['isValid']}');
    print('  - Cache Count: ${status['cacheCount']}');
    print('  - Last Cache Time: ${status['lastCacheTime']}');
    print('  - User ID: ${status['userId'] ?? 'N/A'}');
    if (status['error'] != null) {
      print('  - Error: ${status['error']}');
    }
  }
}