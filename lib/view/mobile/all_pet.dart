import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/view/mobile/detail_pet.dart';
import 'package:pet_shop/widgets/my_search_bar.dart';
import 'package:pet_shop/widgets/pet_items_all.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';

import '../../bloc/favBloc/fav_bloc.dart';
import '../../bloc/favBloc/fav_event.dart';

class AllPet extends StatefulWidget {
  const AllPet({super.key});

  @override
  State<AllPet> createState() => _AllPetState();
}

class _AllPetState extends State<AllPet> {
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
      if (userEmail != null) {
        context.read<FavBloc>().add(LoadFav(userEmail));
      }
  }

  Future<void> fetchAllProduct() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection("Pets").get();

      setState(() {
        groceryItems = snapshot.docs.map((docs) => docs.data()).toList();

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
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        if (data['similar_images'] != null && data['similar_images'].isNotEmpty) {
          // Lấy danh sách tên file
          List<String> fileNames = (data['similar_images'] as List)
              .map((img) => path.basename(img['image_path'] as String))
              .toList();
          // Lọc danh sách thú cưng có imageUrl chứa tên file
          final pets = groceryItems.where((item) =>
            fileNames.any((fileName) => (item['imageUrl'] as String).contains(fileName))
          ).toList();
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
      filtered = filtered.where((item) =>
        (item['category']?.toString() ?? '').toLowerCase() == selectedCategoryFilter.toLowerCase()
      ).toList();
    }
    // Sắp xếp theo giá
    if (priceSortOrder == 'asc') {
      filtered.sort((a, b) => double.parse(a['weight'].toString()).compareTo(double.parse(b['weight'].toString())));
    } else if (priceSortOrder == 'desc') {
      filtered.sort((a, b) => double.parse(b['weight'].toString()).compareTo(double.parse(a['weight'].toString())));
    }
    setState(() {
      filterItems = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        title: const Text(
          "All Pets  ",
          style: TextStyle(color: Colors.black,fontWeight: FontWeight.w500),
        ),
        actions: [
          // Dropdown lọc theo category
          DropdownButton<String>(
            value: selectedCategoryFilter,
            items: ['All', 'Dogs', 'Cats', 'Fish', 'Birds']
                .map((cat) => DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    ))
                .toList(),
            onChanged: (value) {
              selectedCategoryFilter = value!;
              filterAndSortItems();
            },
            underline: Container(),
            style: const TextStyle(color: Colors.black, fontSize: 16),
          ),
          const SizedBox(width: 10),
          // Dropdown sắp xếp giá
          DropdownButton<String>(
            value: priceSortOrder,
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Giá')),
              DropdownMenuItem(value: 'asc', child: Text('Giá tăng dần')),
              DropdownMenuItem(value: 'desc', child: Text('Giá giảm dần')),
            ],
            onChanged: (value) {
              priceSortOrder = value!;
              filterAndSortItems();
            },
            underline: Container(),
            style: const TextStyle(color: Colors.black, fontSize: 16),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MySearchBar(
                        onSearch: searchFilterItems,
                        onImageSearch: searchByImage,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      SizedBox(
                        width: double.maxFinite,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filterItems.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            childAspectRatio: 0.865,
                          ),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailPet(grocery: filterItems[index]),
                                  ),
                                );
                              },
                              child: PetItemsAll(
                                pet: filterItems[index],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class PetSearchResultScreen extends StatelessWidget {
  final List<Map<String, dynamic>> pets;
  const PetSearchResultScreen({super.key, required this.pets});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả tìm kiếm')),
      body: pets.isEmpty
          ? const Center(child: Text('Không tìm thấy thú cưng phù hợp!'))
          : GridView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: pets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.865,
              ),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailPet(grocery: pets[index]),
                      ),
                    );
                  },
                  child: PetItemsAll(pet: pets[index]),
                );
              },
            ),
    );
  }
}
