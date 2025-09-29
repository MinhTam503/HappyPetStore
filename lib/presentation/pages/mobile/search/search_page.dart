import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/data/repositories/search_history_repository.dart';
import 'package:pet_shop/presentation/bloc/search/search_bloc.dart';
import 'package:pet_shop/presentation/bloc/search/search_event.dart';
import 'package:pet_shop/presentation/bloc/search/search_state.dart';
import 'package:pet_shop/presentation/pages/mobile/detail_pet.dart';
import 'package:pet_shop/presentation/widgets/pet_items_all.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _NewSearchPageState();
}

class _NewSearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late final SearchBloc _searchBloc;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    _searchBloc = SearchBloc(
      searchHistoryRepo: SearchHistoryRepository(),
      firestore: FirebaseFirestore.instance,
    );
    _searchBloc.add(LoadSearchHistory());

    // Add search on text change
    _searchController.addListener(() {
      print('Search text changed: ${_searchController.text}');
      _searchBloc.add(SearchQueryChanged(_searchController.text));
    });

    // Test Firebase data
    _testFirebaseCategories();
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
    return BlocProvider.value(
      value: _searchBloc,
      child: BlocConsumer<SearchBloc, SearchState>(
        listener: (context, state) {
          if (state is SearchError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
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
            backgroundColor: secondaryColor,
            appBar: AppBar(
              backgroundColor: secondaryColor,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    width: 300,
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
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 50,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () {
                          _searchBloc.add(
                            SearchSubmitted(_searchController.text),
                          );
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: state is SearchLoading
                ? const Center(child: CircularProgressIndicator())
                : state is SearchSuccess
                    ? CustomScrollView(
                        slivers: [
                          if (selectedImage != null)
                            SliverToBoxAdapter(
                              child: Container(
                                height: 200,
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(selectedImage!),
                                    fit: BoxFit.cover,
                                  ),
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
                                    ...state.suggestions
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final suggestion = entry.value;
                                      final type =
                                          suggestion['type'] as String? ?? '';
                                      final displayName =
                                          suggestion['displayName']
                                                  as String? ??
                                              suggestion['name'] as String? ??
                                              '';

                                      // Xác định icon và màu sắc dựa trên loại
                                      IconData icon;
                                      Color iconColor;
                                      String subtitle;

                                      switch (type) {
                                        case 'pet':
                                          icon = Icons.pets;
                                          iconColor = Colors.blue;
                                          subtitle = 'Thú cưng';
                                          break;
                                        case 'category':
                                          icon = Icons.category;
                                          iconColor = Colors.orange;
                                          subtitle = 'Danh mục';
                                          break;
                                        case 'breed':
                                          icon = Icons.auto_awesome;
                                          iconColor = Colors.green;
                                          subtitle = 'Giống';
                                          break;
                                        case 'pet_category':
                                          icon = Icons.pets;
                                          iconColor = Colors.purple;
                                          subtitle = 'Thú cưng';
                                          break;
                                        default:
                                          icon = Icons.search;
                                          iconColor = Colors.grey;
                                          subtitle = 'Khác';
                                      }

                                      return Container(
                                        decoration: BoxDecoration(
                                          border: index <
                                                  state.suggestions.length - 1
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
                                              color: iconColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(icon,
                                                color: iconColor, size: 20),
                                          ),
                                          title: Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          subtitle: Text(
                                            subtitle,
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
                                            if (type == 'category') {
                                              _searchBloc.add(ToggleCategory(
                                                  suggestion['name']
                                                          as String? ??
                                                      ''));
                                              _searchController.clear();
                                            } else if (type == 'breed') {
                                              // Tìm kiếm theo breed
                                              final searchQuery =
                                                  suggestion['name']
                                                          as String? ??
                                                      '';
                                              _searchController.text =
                                                  searchQuery;
                                              _searchBloc.add(SearchSubmitted(
                                                searchQuery,
                                                isSuggestionTap: true,
                                              ));
                                            } else {
                                              // Tìm kiếm theo tên thú cưng
                                              final searchQuery =
                                                  suggestion['name']
                                                          as String? ??
                                                      '';
                                              _searchController.text =
                                                  searchQuery;
                                              _searchBloc.add(SearchSubmitted(
                                                searchQuery,
                                                isSuggestionTap: true,
                                              ));
                                            }
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),

                          // Search History
                          if (state.searchResults.isEmpty &&
                              state.suggestions.isEmpty &&
                              state.searchHistory.isNotEmpty)
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
                                    ...state.searchHistory
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final search = entry.value;
                                      return Container(
                                        decoration: BoxDecoration(
                                          border: index <
                                                  state.searchHistory.length - 1
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
                                              color: search.isImageSearch
                                                  ? Colors.purple
                                                      .withOpacity(0.1)
                                                  : Colors.grey
                                                      .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              search.isImageSearch
                                                  ? Icons.image_search
                                                  : Icons.history,
                                              color: search.isImageSearch
                                                  ? Colors.purple
                                                  : Colors.grey[600],
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
                                          trailing: search.isImageSearch &&
                                                  search.imageUrl != null
                                              ? Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                          search.imageUrl!),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                )
                                              : Icon(
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

                          // Search Results
                          if (state.searchResults.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final pet = state.searchResults[index];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                DetailPet(pet: pet),
                                          ),
                                        );
                                      },
                                      child: PetItemsAll(pet: pet),
                                    );
                                  },
                                  childCount: state.searchResults.length,
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
