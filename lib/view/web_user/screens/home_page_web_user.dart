import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/view/mobile/detail_pet.dart';
import 'package:pet_shop/view/web_user/widgets/all_pet_item_web.dart';
import 'package:pet_shop/widgets/my_search_bar.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';

class HomePageWebUser extends StatefulWidget {
  const HomePageWebUser({super.key});

  @override
  State<HomePageWebUser> createState() => _AllPetState();
}

class _AllPetState extends State<HomePageWebUser> {
  String category = '';
  List<Map<String, dynamic>> groceryItems = [];
  List<Map<String, dynamic>> filterItems = [];
  bool _isLoading = true;
  String selectedCategoryFilter = 'All';
  String priceSortOrder = 'none'; // 'asc', 'desc', 'none'

  @override
  void initState() {
    super.initState();
    fetchAllProduct();
    final userEmail = FirebaseAuth.instance.currentUser?.email;
  }

  Future<void> fetchAllProduct() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection("Pets").get();

      setState(() {
        groceryItems = snapshot.docs.map((doc) {
          final data = doc.data();
          // GẮN doc.id để dùng về sau (add-to-cart, detail...)
          return {
            ...data,
            'productId': doc.id,
            'id': doc.id, // optional fallback
          };
        }).toList();

        filterItems = groceryItems;
        _isLoading = false;
      });
    } catch (e) {
      print(e.toString());
    } finally {
      _isLoading = false;
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
      final uri = Uri.parse('http://10.0.2.2:5000/search');
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
          SnackBar(content: Text('Lỗi server: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
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
    if (priceSortOrder == 'asc') {
      filtered.sort((a, b) => double.parse(a['weight'].toString())
          .compareTo(double.parse(b['weight'].toString())));
    } else if (priceSortOrder == 'desc') {
      filtered.sort((a, b) => double.parse(b['weight'].toString())
          .compareTo(double.parse(a['weight'].toString())));
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
    final int cross = _gridCountForWidth(width);
    final double gap = _spacingForWidth(width);
    final EdgeInsets pagePad = _paddingForWidth(width);
    final double aspect = _aspectForCrossCount(cross); // tỷ lệ card theo cột

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "Happy Pets",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, "/cart");
                },
                icon: Icon(Icons.shopping_cart_outlined, size: 30)),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SingleChildScrollView(
                    padding: pagePad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search
                        MySearchBar(
                          onSearch: searchFilterItems,
                          onImageSearch: searchByImage,
                        ),
                        SizedBox(height: gap),

                        // Filter bar (tự wrap)
                        _FilterBar(
                          selectedCategory: selectedCategoryFilter,
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: gap,
                            mainAxisSpacing: gap,
                            childAspectRatio: aspect,
                          ),
                          itemBuilder: (context, index) {
                            final pet = filterItems[index];
                            return GestureDetector(
                              onTap: () {
                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //     builder: (context) =>
                                //         DetailPet(grocery: pet),
                                //   ),
                                // );
                              },
                              child: AllPetItemWeb(pet: pet),
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

  const _FilterBar({
    super.key,
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
        // Category
        _LabeledBox(
          label: "Danh mục",
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

  const _LabeledBox({super.key, required this.label, required this.child});

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
