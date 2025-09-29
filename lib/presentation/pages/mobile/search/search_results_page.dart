import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/presentation/bloc/search/search_bloc.dart';
import 'package:pet_shop/presentation/bloc/search/search_state.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';
import 'package:pet_shop/presentation/pages/mobile/search/search_page.dart';
import 'package:pet_shop/presentation/widgets/pet_items_all.dart';
import 'dart:io';

class SearchResultsPage extends StatefulWidget {
  final String searchQuery;
  final List<Map<String, dynamic>>? initialResults;
  final File? searchImage;
  final SearchBloc searchBloc;

  const SearchResultsPage({
    super.key,
    required this.searchQuery,
    this.initialResults,
    this.searchImage,
    required this.searchBloc,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late List<Map<String, dynamic>> results;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    results = widget.initialResults ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.searchBloc,
      child: BlocListener<SearchBloc, SearchState>(
        listener: (context, state) {
          if (state is SearchLoading) {
            if (!isLoading) {
              setState(() => isLoading = true);
              DialogHelper.showLoadingDialog(context, message: 'Đang tìm kiếm...');
            }
          } else {
            if (isLoading) {
              setState(() => isLoading = false);
              DialogHelper.hideLoadingDialog(context);
            }
            
            if (state is SearchError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            } else if (state is SearchSuccess) {
              setState(() {
                results = state.searchResults;
              });
            }
          }
        },
        child: Scaffold(
          backgroundColor: secondaryColor,
          appBar: AppBar(
            backgroundColor: secondaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                // Clear navigation stack và về SearchPage
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const SearchPage(),
                  ),
                  (route) => false, // Remove all previous routes
                );
              },
            ),
            title: GestureDetector(
              onTap: () {
                // Quay lại SearchPage khi tap vào search bar - clear stack
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const SearchPage(),
                  ),
                  (route) => false, // Remove all previous routes
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.searchImage != null 
                            ? 'Tìm kiếm bằng hình ảnh'
                            : widget.searchQuery.isNotEmpty 
                                ? widget.searchQuery 
                                : 'Tìm kiếm thú cưng...',
                        style: TextStyle(
                          color: widget.searchQuery.isNotEmpty || widget.searchImage != null
                              ? Colors.black
                              : Colors.grey[600],
                          fontSize: 16,
                          fontWeight: widget.searchQuery.isNotEmpty || widget.searchImage != null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.searchImage != null)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          image: DecorationImage(
                            image: FileImage(widget.searchImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              // Nút xóa kết quả tìm kiếm
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () {
                  setState(() {
                    results.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa kết quả tìm kiếm'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Header thông tin kết quả với hình ảnh tìm kiếm nếu có
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    // Thông tin kết quả
                    Row(
                      children: [
                        Icon(
                          widget.searchImage != null ? Icons.image_search : Icons.pets, 
                          color: widget.searchImage != null ? Colors.purple : primaryColor, 
                          size: 20
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            results.isEmpty
                                ? widget.searchImage != null 
                                    ? 'Không tìm thấy thú cưng tương tự'
                                    : 'Không tìm thấy kết quả'
                                : widget.searchImage != null 
                                    ? 'Tìm thấy ${results.length} thú cưng tương tự'
                                    : 'Tìm thấy ${results.length} thú cưng',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (widget.searchImage != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.purple, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'AI Search',
                                  style: TextStyle(
                                    color: Colors.purple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    
                    // Hiển thị hình ảnh tìm kiếm nếu có
                    if (widget.searchImage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 120,
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
                                  image: FileImage(widget.searchImage!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // Overlay với text
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.image_search,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Hình ảnh tìm kiếm',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        results.isNotEmpty ? '${results.length} kết quả' : 'Không có kết quả',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
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
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Kết quả tìm kiếm
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.searchImage != null ? Icons.image_search_outlined : Icons.search_off,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.searchImage != null 
                                  ? 'Không tìm thấy thú cưng tương tự'
                                  : 'Không tìm thấy kết quả',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.searchImage != null
                                  ? 'Thử chọn hình ảnh rõ nét hơn\nhoặc chụp ở góc độ khác'
                                  : 'Thử từ khóa khác hoặc tìm kiếm bằng hình ảnh',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => const SearchPage(),
                                  ),
                                  (route) => false, // Remove all previous routes
                                );
                              },
                              icon: const Icon(Icons.search),
                              label: const Text('Tìm kiếm mới'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          final pet = results[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailPet(pet: pet),
                                ),
                              );
                            },
                            child: PetItemsAll(pet: pet),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}