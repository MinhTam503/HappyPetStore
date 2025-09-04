import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/all_pet.dart';
import 'package:pet_shop/presentation/pages/mobile/detail_pet.dart';
import 'package:pet_shop/presentation/widgets/pet_items.dart';
import 'package:pet_shop/presentation/widgets/pet_items_all.dart';

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

  @override
  void initState() {
    super.initState();
    fetchData();
    fetchUserInfo();
    getTop5BestSellingBreeds();
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail != null) {
      context.read<FavBloc>().add(LoadFav(userEmail));
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

  Future<void> getTop5BestSellingBreeds() async {
    Map<String, int> breedSales = {};
    Set<String> neededProductIds = {};

    try {
      // Lấy tất cả orders hoàn thành
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection("orders")
          .where("statusOrder", isEqualTo: "Completed")
          .get();

      // Thu thập tất cả productIds
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = List<Map<String, dynamic>>.from(orderData["items"]);

        for (var item in items) {
          neededProductIds.add(item["productId"]);
        }
      }

      // Lấy tất cả thú cưng theo danh sách productId
      final petsSnapshot = await FirebaseFirestore.instance
          .collection("Pets")
          .where(FieldPath.documentId, whereIn: neededProductIds.toList())
          .get();

      Map<String, String> productIdToBreed = {
        for (var doc in petsSnapshot.docs) doc.id: doc.data()["breed"]
      };

      // Tính tổng số lượng theo breed
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = List<Map<String, dynamic>>.from(orderData["items"]);

        for (var item in items) {
          final String productId = item["productId"];
          final int quantity = item["quantity"];
          final String? breed = productIdToBreed[productId];

          if (breed != null) {
            breedSales[breed] = (breedSales[breed] ?? 0) + quantity;
          }
        }
      }

      // Lấy top 5 giống phổ biến
      final sortedBreeds = breedSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5Breeds = sortedBreeds.take(5).map((e) => e.key).toList();

      // Lấy thú cưng tương ứng với top 5 giống
      final topPetsSnapshot = await FirebaseFirestore.instance
          .collection("Pets")
          .where("breed", whereIn: top5Breeds)
          .get();

      if (!mounted) return;
      setState(() {
        top5BestSell = topPetsSnapshot.docs.map((doc) => doc.data()).toList();
      });
      print("Top 5 giống bán chạy nhất:");
      for (var pet in top5BestSell) {
        print("Tên: ${pet['name']}, Giống: ${pet['breed']}");
      }
      print("Lấy top 5 giống phổ biến thành công");
    } catch (e) {
      print("Lỗi khi lấy top giống phổ biến: $e");
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
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Row(
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
                            )
                          ]),
                    ),
                    const Spacer(),
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
            top5BestSell.isEmpty
                ? const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                : SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: SizedBox(
                        height: listH,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemExtent: cardW,
                          itemCount: top5BestSell.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  left: 15, top: 15, bottom: 15),
                              child: PetItems(
                                pet: top5BestSell[index],
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetailPet(
                                            grocery: top5BestSell[index]),
                                      ));
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        width: category == groceryCategory[index]['name'] ? 2 : 1,
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
                            fontWeight: category == groceryCategory[index]['name']
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
