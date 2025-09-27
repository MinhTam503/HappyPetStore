import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/all_pet.dart';
import 'package:pet_shop/presentation/pages/mobile/detail_pet.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';
import 'package:pet_shop/presentation/pages/notification/nofi_screen.dart';
import 'package:pet_shop/presentation/widgets/my_search_bar.dart';
import 'package:pet_shop/presentation/widgets/pet_items_all.dart';
import 'package:pet_shop/presentation/widgets/popular_pet_items.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_bloc.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_event.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_state.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:path/path.dart' as path;
import '../../../bloc/favBloc/fav_bloc.dart';
import '../../../bloc/favBloc/fav_event.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String category = '';
  List<Map<String, dynamic>> petItems = [];
  List<Map<String, dynamic>> groceryCategory = [];
  List<Map<String, dynamic>> top5BestSell = [];
  String userName = "Người dùng";
  List<Map<String, dynamic>> groceryItems = [];
  List<Map<String, dynamic>> filterItems = [];
  @override
  void initState() {
    super.initState();
    fetchData();
    fetchUserInfo();
    // Popular breeds
    context.read<PopularBloc>().add(const LoadPopularBreeds());
    _loadUserFavorites();
  }

  void _loadUserFavorites() async {
    UserManager userManager = UserManager();
    final userIdentifier = await userManager.getUserIdentifier();
    if (userIdentifier != null) {
      context.read<FavBloc>().add(LoadFav(userIdentifier));
    }
  }

  Future<void> fetchUserInfo() async {
    Map<String, dynamic>? userInfo = await authService.value.getUserInfo();
    if (!mounted) return;
    if (userInfo != null) {
      setState(() {
        userName = userInfo['displayName']?.isNotEmpty == true
            ? userInfo['displayName']
            : "Bạn";
      });
    }
  }

  Future<void> fetchData() async {
    await fetchCategory();
    if (groceryCategory.isNotEmpty) {
      category = groceryCategory[0]["name"];
      await filterProductByCategory(category);
    }
    if (!mounted) return;
  }

  Future<void> fetchCategory() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection("Category").get();
      if (!mounted) return;
      setState(() {
        groceryCategory = snapshot.docs.map((docs) => docs.data()).toList();
      });
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> filterProductByCategory(String selectedCategory) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection("Pets")
          .where("category", isEqualTo: selectedCategory)
          .get();
      if (!mounted) return;
      setState(() {
        category = selectedCategory;
        petItems = snapshot.docs.map((docs) => docs.data()).toList();
      });
    } catch (e) {
      print(e.toString());
    }
  }

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

  // Popular Breeds logic moved into PopularBloc
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
          SnackBar(content: Text('Lỗi server: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW * 0.45).clamp(150.0, 220.0);
    final imageH = cardW * 3 / 4;
    final listH = imageH + 120;

    return Scaffold(
      backgroundColor: secondaryColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 23),
                          children: [
                            const TextSpan(text: "Xin chào, "),
                            TextSpan(
                              text: "$userName\n",
                              style: const TextStyle(color: primaryColor),
                            ),
                            const TextSpan(
                              text: "Chào bạn đến với Happy Pets Shop!",
                              style: TextStyle(
                                  fontSize: 17, color: Colors.black38),
                            ),
                          ]),
                    ),
                    const Spacer(),
                    GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BottomNavigator(
                                initialIndex: 1,
                              ),
                            ),
                          );
                        },
                        child: const Icon(Icons.favorite_border, size: 28)),
                    const SizedBox(
                      width: 5,
                    ),
                    Stack(children: [
                      GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NofiScreen(),
                              ),
                            );
                          },
                          child:
                              const Icon(Icons.notifications_none, size: 30)),
                      Positioned(
                        right: 0,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '3',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Text(
                  "Hãy tìm người bạn đồng hành hoàn hảo cho gia đình bạn",
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.black,
                    height: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: MySearchBar(
                  onSearch: searchFilterItems,
                  onImageSearch: searchByImage,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 25),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 10),
            ),
            // Sticky Category
            SliverPersistentHeader(
              pinned: true,
              delegate: _CategoryHeaderDelegate(
                groceryCategory: groceryCategory,
                category: category,
                onCategoryTap: (selected) {
                  filterProductByCategory(selected);
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            // Thú cưng phổ biến
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    const Text(
                      "Thú cưng phổ biến",
                      style:
                          TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AllPet(),
                          ),
                        );
                      },
                      child: const Text(
                        "Xem tất cả",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_right,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
            BlocBuilder<PopularBloc, PopularState>(
              builder: (context, popState) {
                if (popState is PopularLoading || popState is PopularInitial) {
                  return const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (popState is PopularError) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          popState.message,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  );
                }
                if (popState is PopularLoaded) {
                  final pets = popState.pets;
                  if (pets.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: Center(child: Text('Chưa có dữ liệu phổ biến')),
                      ),
                    );
                  }

                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: SizedBox(
                        height: listH,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemExtent: cardW,
                          itemCount: pets.length,
                          itemBuilder: (context, index) {
                            final pet = pets[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                  left: 15, top: 15, bottom: 15),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetailPet(
                                        grocery: pet,
                                      ),
                                    ),
                                  );
                                },
                                child: PopularPetItems(pet: pet),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),

            // Tất cả thú cưng
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    const Text(
                      "Tất cả thú cưng",
                      style:
                          TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AllPet(),
                          ),
                        );
                      },
                      child: const Text(
                        "Xem tất cả",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_right,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
            petItems.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          "Không có thú cưng nào trong danh mục này",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.only(
                        left: 15, right: 15, top: 10, bottom: 5),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          DetailPet(grocery: petItems[index])));
                            },
                            child: PetItemsAll(
                              pet: petItems[index],
                            ),
                          );
                        },
                        childCount: petItems.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

// Sticky Category Header Delegate
class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<Map<String, dynamic>> groceryCategory;
  final String category;
  final Function(String) onCategoryTap;

  _CategoryHeaderDelegate({
    required this.groceryCategory,
    required this.category,
    required this.onCategoryTap,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: maxExtent,
      color: secondaryColor,
      padding: const EdgeInsets.only(top: 5, bottom: 10),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              groceryCategory.length,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => onCategoryTap(groceryCategory[index]["name"]),
                  child: Container(
                    width: 90,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        width:
                            category == groceryCategory[index]['name'] ? 2 : 1,
                      ),
                      color: category == groceryCategory[index]['name']
                          ? primaryColor
                          : secondaryColor,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: category == groceryCategory[index]['name']
                                ? primaryColor
                                : secondaryColor,
                            image: DecorationImage(
                              fit: BoxFit.scaleDown,
                              image: NetworkImage(
                                groceryCategory[index]['imageUrl'],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          groceryCategory[index]['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                category == groceryCategory[index]['name']
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 90;

  @override
  double get minExtent => 90;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
