import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';
import 'package:pet_shop/presentation/widgets/pet_items_all.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/search/search_page.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:pet_shop/core/services/user_manager.dart';

import '../../../bloc/favBloc/fav_bloc.dart';
import '../../../bloc/favBloc/fav_event.dart';

class AllPet extends StatefulWidget {
  const AllPet({super.key});

  @override
  State<AllPet> createState() => _AllPetState();
}

class _AllPetState extends State<AllPet> {
  String category = '';
  List<Map<String, dynamic>> groceryItems = [];
  List<Map<String, dynamic>> filterItems = [];
  String selectedCategoryFilter = 'All';
  String priceSortOrder = 'none'; // 'asc', 'desc', 'none'
  List<String> availableCategories = ['All']; // Will be loaded dynamically
  bool _categoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    fetchAllProduct();
    _loadUserFavorites();
  }
  
  Future<void> _loadCategories() async {
    if (_categoriesLoaded) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Category')
          .get();
      
      if (mounted) {
        setState(() {
          availableCategories = ['All'];
          availableCategories.addAll(
            snapshot.docs.map((doc) => doc.data()['name'] as String? ?? '').where((name) => name.isNotEmpty)
          );
          _categoriesLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      // Keep default categories if load fails
      if (mounted) {
        setState(() {
          availableCategories = ['All', 'Dogs', 'Cats', 'Fish', 'Birds'];
          _categoriesLoaded = true;
        });
      }
    }
  }

  void _loadUserFavorites() async {
    UserManager userManager = UserManager();
    final userIdentifier = await userManager.getUserIdentifier();
    if (userIdentifier != null) {
      context.read<FavBloc>().add(LoadFav(userIdentifier));
    }
  }

  Future<void> fetchAllProduct() async {

    try {
      // Ensure overlay is shown after first frame so Overlay.of(context) is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) DialogHelper.showLoadingDialog(context, message: 'Đang tải dữ liệu...');
      });
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection("Pets").get();

      setState(() {
        groceryItems = snapshot.docs.map((docs) {
          final data = docs.data();
          data['id'] = docs.id;
          return data;
        }).where((pet) {
          // Only show available pets (not sold)
          final isAvailable = pet['isAvailable'] ?? true;
          final status = pet['status']?.toString().toLowerCase() ?? '';
          return isAvailable && status != 'sold';
        }).toList();
        filterItems = groceryItems;
      });
    } catch (e) {
      print(e.toString());
    } finally {
      if (mounted) DialogHelper.hideLoadingDialog(context);
    }
  }

// method to filter items based on search query

  void searchFilterItems(String query) {
    if (query.isEmpty) {
      setState(() {
        filterItems = groceryItems; // show all items if query is empty
      });
    } else {
      setState(() {
        filterItems = groceryItems.where((item) {
          return item['name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList(); //filter items based of query
      });
    }
  }

  Future<void> searchByImage(File imageFile) async {
    try {
      DialogHelper.showLoadingDialog(context, message: 'Đang tìm ảnh tương tự...');
      // final uri = Uri.parse('http://10.0.2.2:5000/search');
      final uri = Uri.parse('https://train-pet-image.onrender.com/search');
      var request = http.MultipartRequest('POST', uri);
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        if (data['similar_images'] != null &&
            data['similar_images'].isNotEmpty) {
          // Lấy danh sách tên file
          List<String> fileNames = (data['similar_images'] as List)
              .map((img) => path.basename(img['image_path'] as String))
              .toList();
          // Lọc danh sách thú cưng có imageUrl chứa tên file
          final pets = groceryItems
              .where((item) => fileNames.any((fileName) =>
                  (item['imageUrl'] as String).contains(fileName)))
              .toList();
          setState(() {
            filterItems = pets;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy ảnh tương tự!')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi server: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      DialogHelper.hideLoadingDialog(context);
    }
  }

  void filterAndSortItems() {
    List<Map<String, dynamic>> filtered = groceryItems;
    // Lọc theo category
    if (selectedCategoryFilter != 'All') {
      filtered = filtered
          .where((item) =>
              (item['category']?.toString() ?? '').toLowerCase() ==
              selectedCategoryFilter.toLowerCase())
          .toList();
    }
    // Sắp xếp theo giá
    if (priceSortOrder == 'asc' || priceSortOrder == 'desc') {
      num parsePrice(Map<String, dynamic> item) {
        final raw = item['price'];
        if (raw == null) return 0;
        if (raw is num) return raw;
        if (raw is String) {
          final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
          return num.tryParse(cleaned) ?? 0;
        }
        return 0;
      }

      filtered.sort((a, b) {
        final pa = parsePrice(a);
        final pb = parsePrice(b);
        return priceSortOrder == 'asc' ? pa.compareTo(pb) : pb.compareTo(pa);
      });
    }
    setState(() {
      filterItems = filtered;
    });
  }

  int _gridCountForWidth(double w) {
    if (w < 600) return 2; // phone
    if (w < 900) return 3; // small tablet
    if (w < 1200) return 4; // large tablet / small desktop
    if (w < 1600) return 5; // desktop
    return 6; // wide desktop
  }

  double _spacingForWidth(double w) {
    if (w < 600) return 12;
    if (w < 1024) return 14;
    return 16;
  }

  EdgeInsets _paddingForWidth(double w) {
    if (w < 600)
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    if (w < 1024)
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 20, vertical: 18);
  }

  double _aspectForCrossCount(int cross) {
    switch (cross) {
      case 2:
        return 0.80; 
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
    final int cross = _gridCountForWidth(width);
    final double gap = _spacingForWidth(width);
    final EdgeInsets pagePad = _paddingForWidth(width);
    final double aspect = _aspectForCrossCount(cross); // tỷ lệ card theo cột

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        title: const Text(
          "All Pets",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: pagePad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Text(
                            'Tìm kiếm thú cưng...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.image_search, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: gap),

                  // Filter bar (tự wrap)
                  _FilterBar(
                    selectedCategory: selectedCategoryFilter,
                    availableCategories: availableCategories,
                    onCategoryChanged: (v) {
                      setState(() {
                        selectedCategoryFilter = v;
                        filterAndSortItems();
                      });
                    },
                    priceSortOrder: priceSortOrder,
                    onPriceOrderChanged: (v) {
                      setState(() {
                        priceSortOrder = v;
                        filterAndSortItems();
                      });
                    },
                  ),
                  SizedBox(height: gap),

                  // Grid responsive
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filterItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      crossAxisSpacing: gap,
                      mainAxisSpacing: gap,
                      childAspectRatio: aspect,
                    ),
                    itemBuilder: (context, index) {
                      final pet = filterItems[index];
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
                ],
              ),
            ),
          ),
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
  final List<String> availableCategories;

  const _FilterBar({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.priceSortOrder,
    required this.onPriceOrderChanged,
    required this.availableCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Category
        _LabeledBox(
          label: "Danh mục",
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCategory,
              items: availableCategories
                  .map((cat) => DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      ))
                  .toList(),
              onChanged: (v) => onCategoryChanged(v ?? 'All'),
            ),
          ),
        ),

        // Price order
        _LabeledBox(
          label: "Sắp xếp",
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
