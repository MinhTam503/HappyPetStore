import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/utils/responsive_utils.dart';
import 'package:pet_shop/view/mobile/all_pet.dart';
import 'package:pet_shop/view/mobile/detail_pet.dart';
import 'package:pet_shop/view/web_user/widgets/pet_items_all_web_user.dart';
import 'package:pet_shop/view/web_user/widgets/pet_items_web_user.dart';

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' as math;
import '../../../../bloc/favBloc/fav_bloc.dart';
import '../../../../bloc/favBloc/fav_event.dart';

class HomePageWebUser extends StatefulWidget {
  const HomePageWebUser({super.key});

  @override
  State<HomePageWebUser> createState() => _HomePageState();
}

class _HomePageState extends State<HomePageWebUser> {
  String category = '';
  List<Map<String, dynamic>> petItems = [];
  List<Map<String, dynamic>> groceryCategory = [];
  List<Map<String, dynamic>> top5BestSell = [];
  bool _isLoading = true;
  String userName = "Người dùng";
  List<Map<String, dynamic>> groceryItems = [];
  List<Map<String, dynamic>> filterItems = [];
  late final ScrollController _scrollCtrl;
  @override
  void initState() {
    super.initState();
    fetchData();
    fetchUserInfo();
    getTop5BestSellingBreeds();
    _scrollCtrl = ScrollController();
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
            : "Tam\n";
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
    setState(() {
      _isLoading = false;
    });
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
    setState(() {
      _isLoading = true;
    });
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
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> addOrders() async {
    // Đọc file JSON
    final String response =
        await rootBundle.loadString('assets/orders_100.json');
    final List<dynamic> orders = json.decode(response);

    // Tham chiếu đến collection 'orders'
    CollectionReference ordersCollection =
        FirebaseFirestore.instance.collection('orders');

    for (var order in orders) {
      String idOrder = order['orderId']; // Lấy idOrder từ dữ liệu
      await ordersCollection
          .doc(idOrder)
          .set(order); // Sử dụng set để tạo document với idOrder
      print('Đã thêm đơn hàng với ID: $idOrder');
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
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final gridCount = gridCountForWidth(width);
    final gap = responsiveSpacing(context);
    final pagePad = responsivePagePadding(context);

    return Scaffold(
      backgroundColor: secondaryColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: pageMaxWidth(context)),
            child: Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: kIsWeb,
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: pagePad,
                      child: Row(
                        children: [
                          Text(
                            "Happy Pet",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: primaryColor,
                                  fontFamily: "Inter",
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          // CartIcon có thể đặt ở đây nếu cần
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // Sticky Category
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CategoryHeaderDelegate(
                      groceryCategory: groceryCategory,
                      category: category,
                      onCategoryTap: (selected) =>
                          filterProductByCategory(selected),
                      horizontalPadding: pagePad.horizontal / 2,
                      minHeight: isDesktop(context) ? 116 : 96,
                      maxHeight: isDesktop(context) ? 116 : 96,
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: gap)),

                  // Thú cưng phổ biến
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: pagePad,
                      child: Row(
                        children: [
                          Text(
                            "Thú cưng phổ biến",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const AllPet()),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  "See All",
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const Icon(Icons.keyboard_arrow_right),
                              ],
                            ),
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
                            padding: EdgeInsets.only(right: pagePad.right),
                            child: SizedBox(
                              height: isDesktop(context) ? 260 : 220,
                              child: ListView.separated(
                                padding: EdgeInsets.only(left: pagePad.left),
                                scrollDirection: Axis.horizontal,
                                itemCount: top5BestSell.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(width: gap),
                                itemBuilder: (context, index) =>
                                    GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailPet(
                                          grocery: top5BestSell[index]),
                                    ),
                                  ),
                                  child:
                                      PetItemsWebUser(pet: top5BestSell[index]),
                                ),
                              ),
                            ),
                          ),
                        ),

                  // Tất cả thú cưng
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: pagePad.copyWith(top: gap),
                      child: Row(
                        children: [
                          Text(
                            "Tất cả thú cưng",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const AllPet()),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  "See All",
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const Icon(Icons.keyboard_arrow_right),
                              ],
                            ),
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
                                "No product available in this category",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                              pagePad.left, gap, pagePad.right, gap),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        DetailPet(grocery: petItems[index]),
                                  ),
                                ),
                                child: PetItemsAllWebUser(pet: petItems[index]),
                              ),
                              childCount: petItems.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridCount, // <— responsive
                              mainAxisSpacing: gap,
                              crossAxisSpacing: gap,
                              childAspectRatio:
                                  isDesktop(context) ? 0.76 : 0.74,
                            ),
                          ),
                        ),

                  SliverToBoxAdapter(child: SizedBox(height: gap)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<Map<String, dynamic>> groceryCategory;
  final String category;
  final ValueChanged<String> onCategoryTap;
  final double horizontalPadding;
  final double minHeight;
  final double maxHeight;

  _CategoryHeaderDelegate({
    required this.groceryCategory,
    required this.category,
    required this.onCategoryTap,
    required this.horizontalPadding,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: Container(
        color: secondaryColor,
        padding: EdgeInsets.only(left: horizontalPadding, top: 6, bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(groceryCategory.length, (index) {
                    final isActive = category == groceryCategory[index]['name'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            onCategoryTap(groceryCategory[index]["name"]),
                        child: Container(
                          width: isDesktop(context) ? 110 : 92,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(width: isActive ? 2 : 1),
                            color: isActive ? primaryColor : secondaryColor,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: isDesktop(context) ? 46 : 40,
                                width: isDesktop(context) ? 46 : 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      isActive ? primaryColor : secondaryColor,
                                  image: DecorationImage(
                                    fit: BoxFit.scaleDown,
                                    image: NetworkImage(
                                        groceryCategory[index]['imageUrl']),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                groceryCategory[index]['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: isDesktop(context) ? 13 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(maxHeight, minHeight);

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate old) {
    return old.minHeight != minHeight ||
        old.maxHeight != maxHeight ||
        old.category != category ||
        old.groceryCategory.length != groceryCategory.length ||
        old.horizontalPadding != horizontalPadding;
  }
}
