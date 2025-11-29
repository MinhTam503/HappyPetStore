import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:lottie/lottie.dart';
import 'package:pet_shop/core/utils/search_navigation_helper.dart';
import 'package:pet_shop/data/repositories/search_history_repository.dart';
import 'package:pet_shop/presentation/bloc/search/search_bloc.dart';
import 'package:pet_shop/presentation/bloc/search/search_event.dart';
import 'package:pet_shop/presentation/bloc/search/search_state.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_bloc.dart';
import 'package:pet_shop/domain/usecases/recommendation_usecase.dart';
import 'package:pet_shop/data/repositories/recommendation_repository_impl.dart';
import 'package:pet_shop/presentation/widgets/search_recommendations_section.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/services/settings_service.dart';
import 'package:pet_shop/presentation/widgets/common/history_disabled_message.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _NewSearchPageState();
}

class _NewSearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final UserManager _userManager = UserManager();
  final SettingsService _settingsService = SettingsService();
  late final SearchBloc _searchBloc;
  File? selectedImage;
  String? searchImagePath;
  // inline loader replaces overlay; no isLoading flag needed
  String? userId;
  bool _searchHistoryEnabled = true;

  @override
  void initState() {
    super.initState();
    _searchBloc = SearchBloc(
      searchHistoryRepo: SearchHistoryRepository(),
      firestore: FirebaseFirestore.instance,
    );
    _searchBloc.add(LoadSearchHistory());
    _initializeUser();
    _loadSettings();

    // Add search on text change
    _searchController.addListener(() {
      print('Search text changed: ${_searchController.text}');
      _searchBloc.add(SearchQueryChanged(_searchController.text));
    });

    // Test Firebase data
    _testFirebaseCategories();
  }

  Future<void> _initializeUser() async {
    try {
      await _userManager.initialize();
      if (_userManager.isLoggedIn && mounted) {
        setState(() {
          userId = _userManager.currentUserId;
        });
      }
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final searchHistoryEnabled = await _settingsService.getSearchHistoryEnabled();
      if (mounted) {
        setState(() {
          _searchHistoryEnabled = searchHistoryEnabled;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  void _testFirebaseCategories() async {
    try {
      print('\n=== Firebase Categories Test ===');

      // Test collection "Categories" (with s)
      try {
        final snapshot =
            await FirebaseFirestore.instance.collection('Category').get();
        print('Collection "Categories" has ${snapshot.docs.length} documents:');

        for (var doc in snapshot.docs) {
          final data = doc.data();
          print('- ID: ${doc.id}');
          print('  Name: "${data['name']}"');
          print('  Breeds: ${data['breeds']}');

          // Test search queries
          final categoryName = (data['name'] as String? ?? '').toLowerCase();
          print('  Testing queries:');
          print('    "chó" matches: ${categoryName.contains('chó')}');
          print('    "dogs" matches: ${categoryName.contains('dogs')}');
          print('    "do" matches: ${categoryName.contains('do')}');
          print('');
        }
      } catch (e) {
        print('Error with "Categories" collection: $e');
      }

      // Test collection "Category" (without s)
      try {
        final snapshot2 =
            await FirebaseFirestore.instance.collection('Category').get();
        print('Collection "Category" has ${snapshot2.docs.length} documents:');

        for (var doc in snapshot2.docs) {
          final data = doc.data();
          print('- ID: ${doc.id}');
          print('  Name: "${data['name']}"');
          print('  Breeds: ${data['breeds']}');
        }
      } catch (e) {
        print('Error with "Category" collection: $e');
      }

      print('=== End Test ===\n');
    } catch (e) {
      print('Error testing categories: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Load search history when returning to this page
    if (mounted) {
      _searchBloc.add(LoadSearchHistory());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchBloc.close();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _searchBloc),
        BlocProvider(
          create: (context) => RecommendationBloc(
            recommendationUseCase: RecommendationUseCase(
              RecommendationRepositoryImpl(
                firestore: FirebaseFirestore.instance,
                userManager: _userManager,
              ),
            ),
          ),
        ),
      ],
      child: BlocConsumer<SearchBloc, SearchState>(
        listener: (context, state) {
          if (state is SearchError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is SearchSuccess && state.searchResults.isNotEmpty) {
            // Điều hướng đến SearchResultsPage khi có kết quả
            String searchQuery = '';
            File? searchImage;
            
            if (selectedImage != null) {
              searchQuery = 'Tìm kiếm bằng hình ảnh';
              searchImage = selectedImage;
            } else {
              searchQuery = _searchController.text.trim();
            }
            
            // Use SearchNavigationHelper to avoid stack buildup
            SearchNavigationHelper.navigateToResults(
              context: context,
              searchQuery: searchQuery,
              results: state.searchResults,
              searchBloc: _searchBloc,
              originalSearchText: _searchController.text.trim(),
              searchImage: searchImage,
            );
          }
        },
        builder: (context, state) {
          print('Current state: $state');
          if (state is SearchSuccess) {
            print('Has suggestions: ${state.suggestions.length}');
            for (var suggestion in state.suggestions) {
              print(
                  'Suggestion: ${suggestion['name']} (${suggestion['type']})');
            }
          }

          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              title: Row(
                children: [
                  Expanded(
                    child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm thú cưng, giống, danh mục...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        suffixIcon: SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.camera_alt_outlined,
                                    color: Colors.grey[600]),
                                onPressed: () async {
                                  final image = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (image != null) {
                                    setState(() {
                                      selectedImage = File(image.path);
                                      searchImagePath = image.path;
                                    });

                                    _searchBloc
                                        .add(ImageSearchSubmitted(image.path));
                                  }

                                  _searchController.clear();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      onSubmitted: (query) =>
                          _searchBloc.add(SearchSubmitted(query)),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                                    .colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () {
                          _searchBloc.add(
                            SearchSubmitted(_searchController.text),
                          );
                          // Don't clear the text immediately
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: state is SearchLoading
                    ? Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                           
                          ),
                          child: Lottie.asset(
                            'assets/loading.json',
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : state is SearchSuccess
                    ? CustomScrollView(
                        slivers: [
                          // Hiển thị hình ảnh đã chọn cho tìm kiếm (chỉ khi chưa có kết quả)
                          if (selectedImage != null && state.searchResults.isEmpty)
                            SliverToBoxAdapter(
                              child: Container(
                                height: 200,
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.3),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: FileImage(selectedImage!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    // Header với title và nút xóa
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.7),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.image_search,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Tìm kiếm bằng hình ảnh',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  selectedImage = null;
                                                  searchImagePath = null;
                                                });
                                                // Reset search results
                                                _searchBloc
                                                    .add(LoadSearchHistory());
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.5),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Suggestions
                          if (state.suggestions.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Container(
                                margin: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.search,
                                              color: Colors.grey[600],
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Gợi ý tìm kiếm',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ...state.suggestions.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final s = entry.value;
                                      final type = s['type'] as String? ?? '';
                                      final display = s['displayName'] as String? ?? s['name'] as String? ?? '';

                                      Widget leading;
                                      Widget? subtitleWidget;
                                      VoidCallback? onTap;

                                      if (type == 'pet') {
                                        final imageUrl = s['imageUrl'] as String? ?? '';
                                        final breed = s['breed'] as String? ?? '';
                                        leading = ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imageUrl,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.pets, color: Colors.grey, size: 20),
                                            ),
                                          ),
                                        );
                                        subtitleWidget = Text(
                                          breed,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                        onTap = () {
                                          final searchQuery = s['name'] as String? ?? '';
                                          _searchController.text = searchQuery;
                                          _searchBloc.add(SearchSubmitted(searchQuery, isSuggestionTap: true));
                                        };
                                      } else if (type == 'breed') {
                                        leading = const SizedBox(width: 40, height: 40);
                                        subtitleWidget = null;
                                        onTap = () {
                                          final breed = s['name'] as String? ?? '';
                                          _searchController.text = breed;
                                          _searchBloc.add(FilterByBreed(breed));
                                        };
                                      } else if (type == 'category') {
                                        leading = const SizedBox(width: 40, height: 40);
                                        subtitleWidget = null;
                                        onTap = () {
                                          final categoryEn = s['name'] as String? ?? '';
                                          final categoryVi = s['displayName'] as String? ?? categoryEn;
                                          _searchController.text = categoryVi; // show VN label in input
                                          _searchBloc.add(ToggleCategory(categoryEn)); // use EN for query
                                        };
                                      } else {
                                        leading = const SizedBox(width: 40, height: 40);
                                        subtitleWidget = null;
                                        onTap = () {
                                          final searchQuery = s['name'] as String? ?? '';
                                          _searchController.text = searchQuery;
                                          _searchBloc.add(SearchSubmitted(searchQuery, isSuggestionTap: true));
                                        };
                                      }

                                      return Container(
                                        decoration: BoxDecoration(
                                          border: index < state.suggestions.length - 1
                                              ? Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2)))
                                              : null,
                                        ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          leading: leading,
                                          title: Text(
                                            display,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                          ),
                                          subtitle: subtitleWidget,
                                          trailing: Icon(Icons.north_west, color: Colors.grey[400], size: 16),
                                          onTap: onTap,
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),

                          // Search History or Disabled Message
                          if (state.searchResults.isEmpty &&
                              state.suggestions.isEmpty &&
                              selectedImage == null &&
                              _searchController.text.isEmpty)
                            ...[
                              // Show disabled message if search history is disabled
                              if (!_searchHistoryEnabled)
                                const SliverToBoxAdapter(
                                  child: HistoryDisabledMessage(
                                    messageKey: 'searchHistoryDisabledMessage',
                                    icon: Icons.search_off_outlined,
                                    iconColor: Colors.orange,
                                  ),
                                ),
                              // Show search history if enabled and has history  
                              if (_searchHistoryEnabled && 
                                  state.searchHistory.where((search) => !search.isImageSearch).isNotEmpty)
                                SliverToBoxAdapter(
                              child: Container(
                                margin: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.history,
                                              color: Colors.grey[600],
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Lịch sử tìm kiếm',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () {
                                              _searchBloc
                                                  .add(ClearSearchHistory());
                                              setState(() {
                                                _searchController.clear();
                                              });
                                            },
                                            child: Text(
                                              'Xóa tất cả',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red[400],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    // Chỉ hiển thị lịch sử tìm kiếm text
                                    ...state.searchHistory
                                        .where((search) => !search.isImageSearch)
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final search = entry.value;
                                      final textHistoryList = state.searchHistory.where((s) => !s.isImageSearch).toList();
                                      
                                      return Container(
                                        decoration: BoxDecoration(
                                          border: index < textHistoryList.length - 1
                                              ? Border(
                                                  bottom: BorderSide(
                                                      color: Colors.grey
                                                          .withOpacity(0.2)))
                                              : null,
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 4),
                                          leading: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.history,
                                              color: Colors.grey[600],
                                              size: 20,
                                            ),
                                          ),
                                          title: Text(
                                            search.query,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          subtitle: Text(
                                            _formatDate(search.searchedAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          trailing: Icon(
                                            Icons.north_west,
                                            color: Colors.grey[400],
                                            size: 16,
                                          ),
                                          onTap: () {
                                            _searchController.text =
                                                search.query;
                                            _searchBloc.add(
                                                SearchSubmitted(search.query));
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                            ],

                          // Search Recommendations Section
                          if (userId != null && selectedImage == null && _searchController.text.isEmpty)
                            SliverToBoxAdapter(
                              child: SearchRecommendationsSection(
                                userId: userId!,
                              ),
                            ),

                          // Empty State cho Image Search (khi chọn ảnh nhưng chưa có kết quả)
                          if (selectedImage != null && state.searchResults.isEmpty)
                            SliverToBoxAdapter(
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Đang chuẩn bị tìm kiếm',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Hệ thống đang xử lý hình ảnh của bạn',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    : const SizedBox(),
          );
        },
      ),
    );
  }
}