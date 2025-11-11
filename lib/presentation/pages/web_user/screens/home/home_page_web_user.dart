import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/web_user/widgets/pet_card_web_user.dart';
import 'package:url_launcher/url_launcher.dart';

/// Trang chủ dành cho Web User: hiển thị danh sách thú cưng + tìm kiếm + lọc + download app
class HomePageWebUser extends StatefulWidget {
  const HomePageWebUser({super.key});

  @override
  State<HomePageWebUser> createState() => _HomePageWebUserState();
}

class _HomePageWebUserState extends State<HomePageWebUser> {
  List<Map<String, dynamic>> _allPets = [];
  List<Map<String, dynamic>> _filteredPets = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _priceSortOrder = 'none'; // none | asc | desc
  final TextEditingController _searchController = TextEditingController();
  
  // Pagination
  int _currentPage = 0;
  static const int _itemsPerPage = 12;

  @override
  void initState() {
    super.initState();
    _fetchPets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPets() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Pets').get();
      final pets = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
      setState(() {
        _allPets = pets;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
      );
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> working = List.of(_allPets);

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      working = working.where((pet) {
        final name = pet['name']?.toString().toLowerCase() ?? '';
        final breed = pet['breed']?.toString().toLowerCase() ?? '';
        final category = pet['category']?.toString().toLowerCase() ?? '';
        return name.contains(query) || breed.contains(query) || category.contains(query);
      }).toList();
    }

    if (_selectedCategory != 'All') {
      working = working.where((pet) {
        final cat = pet['category']?.toString().toLowerCase() ?? '';
        return cat == _selectedCategory.toLowerCase();
      }).toList();
    }

    if (_priceSortOrder == 'asc') {
      working.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
    } else if (_priceSortOrder == 'desc') {
      working.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
    }

    setState(() {
      _filteredPets = working;
      _currentPage = 0; // reset page whenever filters/search change
    });
  }

  double _priceOf(Map<String, dynamic> pet) {
    final raw = pet['price'];
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0;
  }

  void _navigateToDetail(String petId) {
    // Use a named route so the browser URL reflects /home/pet/:id for deep linking
    Navigator.pushNamed(context, '/home/pet/$petId');
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở liên kết: $url')),
      );
    }
  }

  int _gridCount(double width) {
    if (width < 600) return 2; // phone
    if (width < 900) return 3; // small tablet
    if (width < 1200) return 4; // large tablet
    if (width < 1600) return 5; // desktop
    return 6; // wide desktop
  }

  double _gapForWidth(double width) {
    if (width < 600) return 12;
    if (width < 1024) return 14;
    return 16;
  }

  EdgeInsets _pagePadding(double width) {
    if (width < 600) return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    if (width < 1024) return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 20, vertical: 18);
  }

  double _aspectForCross(int cross) {
    switch (cross) {
      case 2:
        return 0.75;
      case 3:
        return 0.78;
      case 4:
        return 0.78;
      case 5:
        return 0.74;
      default:
        return 0.74;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cross = _gridCount(width);
    final gap = _gapForWidth(width);
    final pad = _pagePadding(width);
    final aspect = _aspectForCross(cross);
    
    // Pagination calculations
    final totalItems = _filteredPets.length;
    final totalPages = (totalItems / _itemsPerPage).ceil().clamp(0, 9999);
    final startIndex = (_currentPage * _itemsPerPage).clamp(0, totalItems);
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    final paginatedPets = totalItems == 0
        ? <Map<String, dynamic>>[]
        : _filteredPets.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Happy Pets',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                _DownloadButton(
                  icon: Icons.android,
                  label: 'Android',
                  onPressed: () => _launchURL('https://your-domain.com/app-release.apk'), // TODO replace
                ),
                const SizedBox(width: 8),
                _DownloadButton(
                  icon: Icons.apple,
                  label: 'iOS',
                  onPressed: () => _launchURL('https://apps.apple.com/app/your-app-id'), // TODO replace
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: SingleChildScrollView(
                    padding: pad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(),
                        SizedBox(height: gap),
                        _FilterBar(
                          selectedCategory: _selectedCategory,
                          onCategoryChanged: (v) {
                            _selectedCategory = v;
                            _applyFilters();
                          },
                          priceSortOrder: _priceSortOrder,
                          onPriceOrderChanged: (v) {
                            _priceSortOrder = v;
                            _applyFilters();
                          },
                        ),
                        _filteredPets.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(48.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Không tìm thấy thú cưng',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: paginatedPets.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  crossAxisSpacing: gap,
                                  mainAxisSpacing: gap,
                                  childAspectRatio: aspect,
                                ),
                                itemBuilder: (context, index) {
                                  final pet = paginatedPets[index];
                                  final petId = pet['id']?.toString() ?? '';
                                  return PetCardWebUser(
                                    pet: pet,
                                    onTap: () => _navigateToDetail(petId),
                                  );
                                },
                              ),
                        if (_filteredPets.isNotEmpty && totalPages > 1) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: _PaginationControls(
                                currentPage: _currentPage,
                                totalPages: totalPages,
                                onPrev: _currentPage > 0
                                    ? () => setState(() => _currentPage--)
                                    : null,
                                onNext: (_currentPage + 1) < totalPages
                                    ? () => setState(() => _currentPage++)
                                    : null,
                                onSelectPage: (p) => setState(() => _currentPage = p),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _applyFilters(),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm thú cưng...',
          prefixIcon: const Icon(Icons.search, color: primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int currentPage; // zero-based
  final int totalPages; // 0 means none
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<int>? onSelectPage;

  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    this.onPrev,
    this.onNext,
    this.onSelectPage,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPrev,
          tooltip: 'Trang trước',
          icon: const Icon(Icons.chevron_left),
          style: IconButton.styleFrom(
            backgroundColor: onPrev != null
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        // Page numbers (max 7)
        ...List.generate(totalPages > 7 ? 7 : totalPages, (index) {
          int pageNum;
          if (totalPages <= 7) {
            pageNum = index;
          } else {
            if (currentPage < 3) {
              pageNum = index;
            } else if (currentPage > totalPages - 4) {
              pageNum = totalPages - 7 + index;
            } else {
              pageNum = currentPage - 3 + index;
            }
          }

          if (pageNum >= totalPages) return const SizedBox.shrink();
          final isSelected = pageNum == currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: onSelectPage != null ? () => onSelectPage!(pageNum) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${pageNum + 1}',
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onNext,
          tooltip: 'Trang sau',
          icon: const Icon(Icons.chevron_right),
          style: IconButton.styleFrom(
            backgroundColor: onNext != null
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : null,
          ),
        ),
      ],
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _DownloadButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final String priceSortOrder;
  final ValueChanged<String> onPriceOrderChanged;

  const _FilterBar({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.priceSortOrder,
    required this.onPriceOrderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LabeledBox(
          label: 'Danh mục',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCategory,
              items: ['All', 'Dogs', 'Cats', 'Fish', 'Birds']
                  .map((cat) => DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      ))
                  .toList(),
              onChanged: (v) => onCategoryChanged(v ?? 'All'),
            ),
          ),
        ),
        _LabeledBox(
          label: 'Sắp xếp',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: priceSortOrder,
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Mặc định')),
                DropdownMenuItem(value: 'asc', child: Text('Giá tăng dần')),
                DropdownMenuItem(value: 'desc', child: Text('Giá giảm dần')),
              ],
              onChanged: (v) => onPriceOrderChanged(v ?? 'none'),
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledBox extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          child,
        ],
      ),
    );
  }
}
          
