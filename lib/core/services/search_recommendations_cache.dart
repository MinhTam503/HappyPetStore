import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';

class SearchRecommendationsCache {
  static const String _cacheKey = 'search_recommendations_cache';
  static const String _timestampKey = 'search_recommendations_timestamp';
  static const String _userIdKey = 'search_recommendations_user_id';
  static const Duration _cacheExpiry = Duration(minutes: 30); // Cache 30 phút

  /// Lưu gợi ý vào cache
  static Future<void> saveRecommendations({
    required String userId,
    required List<RecommendationItem> recommendations,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Chuyển đổi recommendations thành JSON
      final recommendationsJson = recommendations.map((item) => {
        'petId': item.petId,
        'name': item.name,
        'breed': item.breed,
        'type': item.type.toString().split('.').last,
        'category': item.category,
        'imageUrl': item.imageUrl,
        'price': item.price,
        'score': item.score,
        'reason': item.reason,
      }).toList();

      // Lưu dữ liệu
      await prefs.setString(_cacheKey, jsonEncode(recommendationsJson));
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_userIdKey, userId);
      
      print('✅ Cached ${recommendations.length} search recommendations for user $userId');
    } catch (e) {
      print('❌ Error saving recommendations cache: $e');
    }
  }

  /// Lấy gợi ý từ cache
  static Future<List<RecommendationItem>?> getRecommendations(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Kiểm tra user ID
      final cachedUserId = prefs.getString(_userIdKey);
      if (cachedUserId != userId) {
        print('👤 Different user, cache invalid');
        return null;
      }

      // Kiểm tra thời gian expire
      final timestamp = prefs.getInt(_timestampKey);
      if (timestamp == null) {
        print('⏰ No timestamp found in cache');
        return null;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      if (now.difference(cacheTime) > _cacheExpiry) {
        print('⏰ Cache expired (${now.difference(cacheTime).inMinutes} minutes old)');
        await clearCache(); // Xóa cache cũ
        return null;
      }

      // Lấy dữ liệu
      final recommendationsJson = prefs.getString(_cacheKey);
      if (recommendationsJson == null) {
        print('📭 No recommendations found in cache');
        return null;
      }

      final recommendationsList = jsonDecode(recommendationsJson) as List;
      final recommendations = recommendationsList.map((json) {
        return RecommendationItem(
          petId: json['petId'] ?? '',
          name: json['name'] ?? '',
          breed: json['breed'] ?? '',
          type: _parseRecommendationType(json['type']),
          category: json['category'] ?? '',
          imageUrl: json['imageUrl'] ?? '',
          price: (json['price'] ?? 0.0).toDouble(),
          score: (json['score'] ?? 0.0).toDouble(),
          reason: json['reason'] ?? '',
        );
      }).toList();

      print('📦 Loaded ${recommendations.length} recommendations from cache (${now.difference(cacheTime).inMinutes} minutes old)');
      return recommendations;
    } catch (e) {
      print('❌ Error loading recommendations cache: $e');
      return null;
    }
  }

  /// Kiểm tra cache có hợp lệ không
  static Future<bool> isCacheValid(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Kiểm tra user ID
      final cachedUserId = prefs.getString(_userIdKey);
      if (cachedUserId != userId) return false;

      // Kiểm tra thời gian
      final timestamp = prefs.getInt(_timestampKey);
      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      return now.difference(cacheTime) <= _cacheExpiry;
    } catch (e) {
      return false;
    }
  }

  /// Xóa cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_timestampKey);
      await prefs.remove(_userIdKey);
      print('🗑️ Search recommendations cache cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Lấy thời gian cache cuối cùng
  static Future<DateTime?> getLastCacheTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_timestampKey);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// Parse RecommendationType từ string
  static RecommendationType _parseRecommendationType(String? typeString) {
    switch (typeString?.toLowerCase()) {
      case 'contentbased':
        return RecommendationType.contentBased;
      case 'collaborative':
        return RecommendationType.collaborative;
      case 'trending':
        return RecommendationType.trending;
      case 'association':
        return RecommendationType.association;
      case 'hybrid':
        return RecommendationType.hybrid;
      case 'personalized':
        return RecommendationType.personalized;
      default:
        return RecommendationType.contentBased;
    }
  }
}