import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stream_transform/stream_transform.dart'; // <-- add
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pet_shop/data/repositories/search_history_repository.dart';
import 'package:pet_shop/presentation/bloc/search/search_event.dart';
import 'package:pet_shop/presentation/bloc/search/search_state.dart';
import 'package:pet_shop/core/services/user_manager.dart';

// Debounce + restartable: hủy xử lý cũ khi có event mới trong thời gian debounce
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchHistoryRepository _searchHistoryRepo;
  final FirebaseFirestore _firestore;

  SearchBloc({
    required SearchHistoryRepository searchHistoryRepo,
    required FirebaseFirestore firestore,
  })  : _searchHistoryRepo = searchHistoryRepo,
        _firestore = firestore,
        super(SearchInitial()) {
    // Áp dụng debounce 100ms cho SearchQueryChanged (REDUCED for testing)
    on<SearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: debounceRestartable(const Duration(milliseconds: 100)),
    );

    on<SearchSubmitted>(_onSearchSubmitted);
    on<LoadSearchHistory>(_onLoadSearchHistory);
    on<ClearSearchHistory>(_onClearSearchHistory);
    on<ToggleCategory>(_onToggleCategory);
    on<ImageSearchSubmitted>(_onImageSearchSubmitted);
  }

  // ---- helper emit kèm history ----
  Future<void> _emitWithHistory({
    required Emitter<SearchState> emit,
    required List<Map<String, dynamic>> searchResults,
    required List<Map<String, dynamic>> suggestions,
    String? selectedCategory,
  }) async {
    final history = await _searchHistoryRepo.getSearchHistory();
    if (emit.isDone) return; // đảm bảo handler chưa kết thúc
    
    print('_emitWithHistory called:');
    print('  - searchResults: ${searchResults.length}');
    print('  - suggestions: ${suggestions.length}');
    print('  - selectedCategory: $selectedCategory');
    
    if (state is SearchSuccess) {
      emit((state as SearchSuccess).copyWith(
        searchResults: searchResults,
        suggestions: suggestions,
        searchHistory: history,
        selectedCategory: selectedCategory,
      ));
    } else {
      emit(SearchSuccess(
        searchResults: searchResults,
        suggestions: suggestions,
        searchHistory: history,
        selectedCategory: selectedCategory,
      ));
    }
    
    print('Trạng thái đã được phát ra thành công');
  }

  // ---- USER PREFERENCE METHODS ----
  Future<Map<String, double>> _getQuickBreedScores() async {
    try {
      final userId = await UserManager().getUserIdForOperations();
      if (userId == null) return {};

      print('🎯 Getting user preference scores for search suggestions...');

      // Get user favorites
      final favorites = await _firestore
          .collection('UserFav')
          .where('userId', isEqualTo: userId)
          .get();
          
      // Get viewed pets (recent 50 to avoid performance issues)
      final viewedPets = await _firestore
          .collection('ViewedPets')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      Map<String, int> breedCounts = {};
      
      // Count breed frequencies from favorites (weight: 3x)
      for (final doc in favorites.docs) {
        final breed = doc.data()['breed'] as String?;
        if (breed != null && breed.isNotEmpty) {
          breedCounts[breed] = (breedCounts[breed] ?? 0) + 3; // Favorites weight more
        }
      }
      
      // Count breed frequencies from viewed pets (weight: 1x)
      for (final doc in viewedPets.docs) {
        final breed = doc.data()['breed'] as String?;
        if (breed != null && breed.isNotEmpty) {
          breedCounts[breed] = (breedCounts[breed] ?? 0) + 1;
        }
      }
      
      if (breedCounts.isEmpty) {
        print('⚠️ No breed preferences found for user');
        // 🎯 FOR TESTING: Add mock preferences for "Chim chào mào"
        print('🧪 Adding test preference for Chim chào mào...');
        return {'Chim chào mào': 100.0, 'Chim hoạ mi': 60.0, 'Chim yến phụng': 30.0};
      }
      
      // Convert to scores (normalize to 0-100)
      final maxCount = breedCounts.values.reduce((a, b) => a > b ? a : b);
      final breedScores = breedCounts.map((breed, count) => 
          MapEntry(breed, (count / maxCount) * 100));
      
      print('🎯 User breed preferences calculated:');
      final sortedBreeds = breedScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedBreeds.take(5)) {
        print('  - ${entry.key}: ${entry.value.toStringAsFixed(1)}%');
      }
      
      return breedScores;
    } catch (e) {
      print('❌ Error getting user preferences: $e');
      return {};
    }
  }

  double _getBreedPreferenceScore(String breed, Map<String, double> breedScores) {
    return breedScores[breed] ?? 0.0;
  }

  // ---- handlers ----
  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    print('🔍 SEARCH QUERY CHANGED: "${event.query}"');
    final raw = event.query.trim();
    print('🔍 Raw query after trim: "$raw"');

    // Rỗng -> trả về lịch sử
    if (raw.isEmpty) {
      final history = await _searchHistoryRepo.getSearchHistory();
      if (emit.isDone) return;
      emit(SearchSuccess(
        searchResults: const [],
        suggestions: const [],
        searchHistory: history,
      ));
      return;
    }

    try {
      final queryLower = raw.toLowerCase();
      print('Searching for query: $queryLower');

      // Mapping từ đồng nghĩa tiếng Việt sang tiếng Anh
      final synonymMapping = {
        'chó': ['dogs', 'dog'],
        'cún': ['dogs', 'dog'],
        'mèo': ['cats', 'cat'],
        'cá': ['fish'],
        'chim': ['birds', 'bird'],
      };

      // Tạo danh sách các query để tìm kiếm (bao gồm cả từ đồng nghĩa)
      final searchQueries = <String>[queryLower];
      for (var entry in synonymMapping.entries) {
        if (queryLower.contains(entry.key)) {
          searchQueries.addAll(entry.value);
          print('Added synonyms for "${entry.key}": ${entry.value}');
        }
      }
      // Ngược lại, nếu query tiếng Anh thì thêm từ tiếng Việt
      for (var entry in synonymMapping.entries) {
        for (var synonym in entry.value) {
          if (queryLower.contains(synonym)) {
            searchQueries.add(entry.key);
            print('Added Vietnamese synonym for "$synonym": ${entry.key}');
          }
        }
      }

      print('Final search queries: $searchQueries');
      print('🔍 STARTING SEARCH SUGGESTIONS GENERATION...');

      final suggestions = <Map<String, dynamic>>[];

      // 1. Tìm kiếm pets theo tên
      final petsQuery = await _firestore.collection('Pets').get();

      for (var doc in petsQuery.docs) {
        final data = doc.data();
        final petName = (data['name'] as String? ?? '').toLowerCase();
        final petBreed = (data['breed'] as String? ?? '').toLowerCase();
        final petCategory = (data['category'] as String? ?? '').toLowerCase();

        // Kiểm tra với tất cả các query
        bool nameMatch = searchQueries.any((q) => petName.contains(q));
        bool breedMatch = searchQueries.any((q) => petBreed.contains(q));
        bool categoryMatch = searchQueries.any((q) => petCategory.contains(q));

        // Kiểm tra tên pet có chứa từ khóa tìm kiếm không
        if (nameMatch && !suggestions.any((s) => s['id'] == doc.id)) {
          suggestions.add({
            ...data,
            'type': 'pet',
            'id': doc.id,
            'displayName': data['name'],
            'matchType': 'name',
          });
        }
        // Kiểm tra breed có chứa từ khóa tìm kiếm không
        else if (breedMatch && !suggestions.any((s) => s['id'] == doc.id)) {
          suggestions.add({
            ...data,
            'type': 'breed',
            'id': doc.id,
            'displayName': '${data['name']} (${data['breed']})',
            'matchType': 'breed',
          });
        }
        // Kiểm tra category có chứa từ khóa tìm kiếm không
        else if (categoryMatch && !suggestions.any((s) => s['id'] == doc.id)) {
          suggestions.add({
            ...data,
            'type': 'pet_category',
            'id': doc.id,
            'displayName': '${data['name']} (${data['category']})',
            'matchType': 'category',
          });
        }
      }

      // 2. Tìm kiếm categories
      final categoriesQuery = await _firestore.collection('Category').get();

      print('Found ${categoriesQuery.docs.length} categories in database');

      for (var doc in categoriesQuery.docs) {
        final data = doc.data();
        final categoryName = (data['name'] as String? ?? '').toLowerCase();

        print(
            'Checking category: "$categoryName" against queries: $searchQueries');

        // Kiểm tra với tất cả các query
        bool categoryMatches =
            searchQueries.any((q) => categoryName.contains(q));

        if (categoryMatches) {
          print('✅ Category "$categoryName" matches one of the queries');

          bool alreadyExists = suggestions.any((s) =>
              s['type'] == 'category' &&
              s['name']?.toString().toLowerCase() == categoryName);

          if (!alreadyExists) {
            suggestions.add({
              ...data,
              'type': 'category',
              'id': doc.id,
              'displayName': data['name'],
              'matchType': 'category',
            });
            print('Added category suggestion: ${data['name']}');
          } else {
            print('Category already exists in suggestions');
          }
        }

        // 3. Tìm kiếm trong breeds của category
        final breeds = data['breeds'] as List<dynamic>? ?? [];
        print('Category ${data['name']} has ${breeds.length} breeds: $breeds');

        for (var breed in breeds) {
          final breedName = (breed as String? ?? '').toLowerCase();
          bool breedMatches = searchQueries.any((q) => breedName.contains(q));

          if (breedMatches) {
            print('✅ Breed "$breedName" matches one of the queries');

            bool alreadyExists = suggestions.any((s) =>
                s['type'] == 'breed' &&
                (s['displayName']
                        ?.toString()
                        .toLowerCase()
                        .contains(breedName) ??
                    false));

            if (!alreadyExists) {
              suggestions.add({
                'name': breed,
                'category': data['name'],
                'type': 'breed',
                'id': '${doc.id}_$breed',
                'displayName': '$breed (${data['name']})',
                'matchType': 'breed',
              });
              print('Added breed suggestion: $breed (${data['name']})');
            }
          }
        }
      }

      // 🎯 NEW: Get user preference scores for smart sorting
      print('🔍 About to get user breed scores for search suggestions...');
      final userBreedScores = await _getQuickBreedScores();
      print('🔍 Got ${userBreedScores.length} breed scores: $userBreedScores');

      // Sắp xếp suggestions theo độ ưu tiên: tên trước, category sau, breed cuối
      // 🎯 ENHANCED: Với breed suggestions, ưu tiên theo user preferences
      print('🔍 Starting to sort ${suggestions.length} suggestions...');
      suggestions.sort((a, b) {
        const priority = {'name': 0, 'category': 1, 'breed': 2};
        final aPriority = priority[a['matchType']] ?? 3;
        final bPriority = priority[b['matchType']] ?? 3;
        
        // 1. First sort by match type priority  
        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }
        
        // 2. Within same type, especially for breeds, sort by user preference score
        if (a['matchType'] == 'breed' && b['matchType'] == 'breed') {
          final aScore = _getBreedPreferenceScore(a['name'], userBreedScores);
          final bScore = _getBreedPreferenceScore(b['name'], userBreedScores);
          
          print('🔍 Comparing breeds: ${a['name']} (${aScore.toStringAsFixed(1)}) vs ${b['name']} (${bScore.toStringAsFixed(1)})');
          
          if (aScore != bScore) {
            print('🎯 Sorting breeds: ${a['name']} (${aScore.toStringAsFixed(1)}) vs ${b['name']} (${bScore.toStringAsFixed(1)})');
            return bScore.compareTo(aScore); // Higher preference score first
          }
        }
        
        // 3. Keep original order for same priority and score
        return 0;
      });

      // Giới hạn số lượng gợi ý
      final limitedSuggestions = suggestions.take(10).toList();

      print('🎯 SMART SEARCH SUGGESTIONS RESULT:');
      print('Found ${limitedSuggestions.length} total suggestions');
      for (var suggestion in limitedSuggestions) {
        final breedScore = suggestion['matchType'] == 'breed' 
            ? _getBreedPreferenceScore(suggestion['name'], userBreedScores)
            : 0.0;
        final scoreText = suggestion['matchType'] == 'breed' 
            ? ' (preference: ${breedScore.toStringAsFixed(1)}%)'
            : '';
        print('  ${suggestion['displayName']} (${suggestion['type']})$scoreText');
      }

      await _emitWithHistory(
        emit: emit,
        searchResults: state is SearchSuccess
            ? (state as SearchSuccess).searchResults
            : const [],
        suggestions: limitedSuggestions,
        selectedCategory: state is SearchSuccess
            ? (state as SearchSuccess).selectedCategory
            : null,
      );
    } catch (e) {
      print('Lỗi tìm kiếm: $e');
      if (!emit.isDone) emit(SearchError(e.toString()));
    }
  }

  Future<void> _onSearchSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    final raw = event.query.trim();
    if (raw.isEmpty) return;

    emit(SearchLoading());

    try {
      print('\n=== SEARCH SUBMITTED ===');
      print('Raw query: "$raw"');
      print('Is suggestion tap: ${event.isSuggestionTap}');

      // Always save to search history, regardless of source
      await _searchHistoryRepo.addSearchQuery(raw);
      print('✅ Search history saved: "$raw"');

      final queryLower = raw.toLowerCase();
      print('Query lowercase: "$queryLower"');

      // Mapping từ đồng nghĩa với nhiều từ khóa hơn
      final synonymMapping = {
        'chó': ['dogs', 'dog'],
        'cún': ['dogs', 'dog'],
        'mèo': ['cats', 'cat'],
        'cá': ['fish'],
        'chim': ['birds', 'bird'],
        'thỏ': ['rabbit', 'bunny'],
        'hamster': ['hamster'],
        'chuột hamster': ['hamster'],
        'poodle': ['poodle'],
        'golden retriever': ['golden retriever'],
        'husky': ['husky'],
        'chihuahua': ['chihuahua'],
        'phốc sóc': ['phốc sóc'],
        'bacgie': ['bacgie'],
      };

      // Tạo danh sách các query để tìm kiếm (bao gồm cả từ đồng nghĩa)
      final searchQueries = <String>[queryLower];

      // Thêm từ đồng nghĩa tiếng Anh nếu query là tiếng Việt
      for (var entry in synonymMapping.entries) {
        if (queryLower.contains(entry.key)) {
          searchQueries.addAll(entry.value);
          print('Added English synonyms for "${entry.key}": ${entry.value}');
        }
      }

      // Thêm từ tiếng Việt nếu query là tiếng Anh
      for (var entry in synonymMapping.entries) {
        for (var synonym in entry.value) {
          if (queryLower.contains(synonym.toLowerCase())) {
            searchQueries.add(entry.key);
            print('Added Vietnamese synonym for "$synonym": ${entry.key}');
          }
        }
      }

      print('Final search queries: $searchQueries');

      // Tìm kiếm
      final results = <Map<String, dynamic>>[];

      // Tìm kiếm trong collection Pets
      print('\n=== Searching in Pets collection ===');
      final allPetsSnapshot = await _firestore.collection('Pets').get();
      print('Found ${allPetsSnapshot.docs.length} pets in database');

      for (var doc in allPetsSnapshot.docs) {
        final data = doc.data();
        final petName = (data['name'] as String? ?? '').toLowerCase();
        final petBreed = (data['breed'] as String? ?? '').toLowerCase();
        final petCategory = (data['category'] as String? ?? '').toLowerCase();

        print('Checking pet: "${data['name']}"');
        print('  - Name: "$petName"');
        print('  - Breed: "$petBreed"');
        print('  - Category: "$petCategory"');

        // Kiểm tra match với tất cả search queries (case insensitive)
        bool nameMatch = searchQueries.any((q) => petName.contains(q));
        bool breedMatch = searchQueries.any((q) => petBreed.contains(q));
        bool categoryMatch = searchQueries.any((q) => petCategory.contains(q));

        print('  - Name match: $nameMatch (queries: $searchQueries)');
        print('  - Breed match: $breedMatch');
        print('  - Category match: $categoryMatch');

        if (nameMatch || breedMatch || categoryMatch) {
          results.add(data);
          print('  ✅ ADDED to results');
        } else {
          print('  ❌ Not added');
        }
      }

      print('\n=== Search completed ===');
      print('Total results found: ${results.length}');

      for (var result in results) {
        print(
            'Result: ${result['name']} (${result['breed']}) - ${result['category']}');
      }

      // Sắp xếp kết quả theo độ liên quan
      results.sort((a, b) {
        final aName = (a['name'] as String? ?? '').toLowerCase();
        final bName = (b['name'] as String? ?? '').toLowerCase();
        final aBreed = (a['breed'] as String? ?? '').toLowerCase();
        final bBreed = (b['breed'] as String? ?? '').toLowerCase();
        final aCategory = (a['category'] as String? ?? '').toLowerCase();
        final bCategory = (b['category'] as String? ?? '').toLowerCase();

        // Kiểm tra match với tất cả search queries (case insensitive)
        bool aNameMatch = searchQueries.any((q) => aName.contains(q));
        bool bNameMatch = searchQueries.any((q) => bName.contains(q));
        bool aBreedMatch = searchQueries.any((q) => aBreed.contains(q));
        bool bBreedMatch = searchQueries.any((q) => bBreed.contains(q));
        bool aCategoryMatch = searchQueries.any((q) => aCategory.contains(q));
        bool bCategoryMatch = searchQueries.any((q) => bCategory.contains(q));

        // Ưu tiên tên chứa query
        if (aNameMatch && !bNameMatch) return -1;
        if (!aNameMatch && bNameMatch) return 1;

        // Sau đó ưu tiên breed chứa query
        if (aBreedMatch && !bBreedMatch) return -1;
        if (!aBreedMatch && bBreedMatch) return 1;

        // Cuối cùng ưu tiên category chứa query
        if (aCategoryMatch && !bCategoryMatch) return -1;
        if (!aCategoryMatch && bCategoryMatch) return 1;

        return 0;
      });

      print('\n=== Emitting results ===');
      print('Emitting ${results.length} results');

      await _emitWithHistory(
        emit: emit,
        searchResults: results,
        suggestions: const [],
        selectedCategory: state is SearchSuccess
            ? (state as SearchSuccess).selectedCategory
            : null,
      );

      print('=== SEARCH SUBMITTED COMPLETED ===\n');
    } catch (e) {
      print('Lỗi submit tìm kiếm: $e');
      if (!emit.isDone) emit(SearchError(e.toString()));
    }
  }

  Future<void> _onLoadSearchHistory(
    LoadSearchHistory event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final history = await _searchHistoryRepo.getSearchHistory();
      if (emit.isDone) return;

      if (state is SearchSuccess) {
        emit((state as SearchSuccess).copyWith(searchHistory: history));
      } else {
        emit(SearchSuccess(
          searchResults: const [],
          suggestions: const [],
          searchHistory: history,
        ));
      }
    } catch (e) {
      if (!emit.isDone) emit(SearchError(e.toString()));
    }
  }

  Future<void> _onClearSearchHistory(
    ClearSearchHistory event,
    Emitter<SearchState> emit,
  ) async {
    try {
      await _searchHistoryRepo.clearSearchHistory();
      if (emit.isDone) return;

      if (state is SearchSuccess) {
        emit((state as SearchSuccess).copyWith(searchHistory: const []));
      }
    } catch (e) {
      if (!emit.isDone) emit(SearchError(e.toString()));
    }
  }

  Future<void> _onToggleCategory(
    ToggleCategory event,
    Emitter<SearchState> emit,
  ) async {
    if (state is! SearchSuccess) return;

    emit(SearchLoading());
    
    try {
      print('\n=== TOGGLE CATEGORY ===');
      print('Looking for category: "${event.category}"');
      
      final snapshot = await _firestore
          .collection('Pets')
          .where('category', isEqualTo: event.category)
          .get();

      print('Found ${snapshot.docs.length} pets with exact category match');
      
      // Nếu không tìm thấy exact match, thử tìm case-insensitive
      if (snapshot.docs.isEmpty) {
        print('No exact match, trying case-insensitive search...');
        final allPetsSnapshot = await _firestore.collection('Pets').get();
        final results = <Map<String, dynamic>>[];
        
        for (var doc in allPetsSnapshot.docs) {
          final data = doc.data();
          final petCategory = (data['category'] as String? ?? '').toLowerCase();
          final searchCategory = event.category.toLowerCase();
          
          if (petCategory == searchCategory || petCategory.contains(searchCategory)) {
            results.add(data);
          }
        }
        
        print('Found ${results.length} pets with case-insensitive match');
        
        await _emitWithHistory(
          emit: emit,
          searchResults: results,
          suggestions: const [],
          selectedCategory: event.category,
        );
      } else {
        final results = snapshot.docs.map((d) => d.data()).toList();
        
        await _emitWithHistory(
          emit: emit,
          searchResults: results,
          suggestions: const [],
          selectedCategory: event.category,
        );
      }
      
      print('=== TOGGLE CATEGORY COMPLETED ===\n');
      
    } catch (e) {
      print('Lỗi chuyển đổi danh mục: $e');
      if (!emit.isDone) emit(SearchError(e.toString()));
    }
  }

  Future<void> _onImageSearchSubmitted(
    ImageSearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    final imagePath = event.imagePath;
    if (imagePath.isEmpty) return;

    emit(SearchLoading());

    try {
      // Lưu lịch sử tìm kiếm hình ảnh
      await _searchHistoryRepo.addSearchQuery(
        'Tìm kiếm bằng hình ảnh',
        isImageSearch: true,
        imageUrl: imagePath,
      );

      // Gọi API tìm kiếm hình ảnh
      final uri = Uri.parse('https://train-pet-image.onrender.com/search');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));

      var response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);

        if (data['similar_images'] != null &&
            data['similar_images'].isNotEmpty) {
          // Lấy danh sách tên file từ kết quả API
          List<String> fileNames = (data['similar_images'] as List)
              .map((img) => path.basename(img['image_path'] as String))
              .toList();

          print('Found similar images: $fileNames');

          // Lấy tất cả pets từ Firestore
          final allPetsSnapshot = await _firestore.collection('Pets').get();
          final allPets = allPetsSnapshot.docs.map((d) => d.data()).toList();

          // Lọc pets có imageUrl chứa tên file tương tự
          final results = allPets.where((item) {
            final imageUrl = item['imageUrl'] as String? ?? '';
            return fileNames.any((fileName) => imageUrl.contains(fileName));
          }).toList();

          print('Found ${results.length} matching pets');

          await _emitWithHistory(
            emit: emit,
            searchResults: results,
            suggestions: const [],
            selectedCategory: null,
          );
        } else {
          // Không tìm thấy kết quả
          await _emitWithHistory(
            emit: emit,
            searchResults: const [],
            suggestions: const [],
            selectedCategory: null,
          );
        }
      } else {
        if (!emit.isDone)
          emit(SearchError('Lỗi máy chủ: ${response.statusCode}'));
      }
    } catch (e) {
      print('Lỗi tìm kiếm hình ảnh: $e');
      if (!emit.isDone) emit(SearchError('Lỗi tìm kiếm hình ảnh: $e'));
    }
  }
}