import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/services/settings_service.dart';
import 'package:pet_shop/data/models/search_history_model.dart';

class SearchHistoryRepository {
  final FirebaseFirestore _firestore;
  final UserManager _userManager;
  final SettingsService _settingsService;

  SearchHistoryRepository({
    FirebaseFirestore? firestore,
    UserManager? userManager,
    SettingsService? settingsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _userManager = userManager ?? UserManager(),
        _settingsService = settingsService ?? SettingsService();

  Future<void> addSearchQuery(String query, {bool isImageSearch = false, String? imageUrl}) async {
    try {
      // Check if search history is enabled
      final isHistoryEnabled = await _settingsService.getSearchHistoryEnabled();
      if (!isHistoryEnabled) {
        print('Search history is disabled, skipping save');
        return;
      }

      await _userManager.initialize();
      final userId = await _userManager.getUserIdentifier();
      
      if (userId == null) return;

      final queryLower = query.toLowerCase().trim();
      
      // Kiểm tra xem query đã tồn tại chưa
      final existingSnapshot = await _firestore
          .collection('SearchHistory')
          .doc(userId)
          .collection('searches')
          .where('queryLower', isEqualTo: queryLower)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        // Nếu đã tồn tại, chỉ cập nhật thời gian
        final docRef = existingSnapshot.docs.first.reference;
        await docRef.update({
          'searchedAt': FieldValue.serverTimestamp(),
          'searchedAtMillis': DateTime.now().millisecondsSinceEpoch,
        });
        print('Updated existing search query: $query');
      } else {
        // Nếu chưa tồn tại, tạo mới
        final searchHistory = SearchHistoryModel(
          query: query,
          searchedAt: DateTime.now(),
          isImageSearch: isImageSearch,
          imageUrl: imageUrl,
        );

        await _firestore
            .collection('SearchHistory')
            .doc(userId)
            .collection('searches')
            .add({
          ...searchHistory.toFirestore(),
          'queryLower': queryLower, // Thêm field để query dễ dàng
        });
        print('Added new search query: $query');
      }
    } catch (e) {
      print('Error saving search history: $e');
    }
  }

  Future<List<SearchHistoryModel>> getSearchHistory({int limit = 10}) async {
    try {
      final userId = await _userManager.getUserIdentifier();
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('SearchHistory')
          .doc(userId)
          .collection('searches')
          .orderBy('searchedAtMillis', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SearchHistoryModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting search history: $e');
      return [];
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      final userId = await _userManager.getUserIdentifier();
      if (userId == null) return;

      final snapshot = await _firestore
          .collection('SearchHistory')
          .doc(userId)
          .collection('searches')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }
}