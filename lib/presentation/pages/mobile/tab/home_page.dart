import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/all_pet.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';
import 'package:pet_shop/presentation/pages/mobile/search/search_page.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';
import 'package:pet_shop/presentation/widgets/common/app_drawer.dart';
import 'package:pet_shop/presentation/widgets/notification_button.dart';
import 'package:pet_shop/presentation/widgets/pet_items_all.dart';
import 'package:pet_shop/presentation/widgets/popular_pet_items.dart';
import 'package:pet_shop/presentation/widgets/simple_recommendation_section.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_bloc.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_event.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_state.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_bloc.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_event.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_bloc.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_event.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_state.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/presentation/pages/mobile/analytics/recommendation_analytics_page.dart';
import 'package:pet_shop/demo/sample_interactions_demo_page.dart';
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
  String? userId;
  List<Map<String, dynamic>> groceryItems = [];
  List<Map<String, dynamic>> filterItems = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UserManager userManager = UserManager();

  @override
  void initState() {
    super.initState();
    fetchData();
    fetchUserInfo();
    // Popular breeds
    context.read<PopularBloc>().add(const LoadPopularBreeds());
    _loadUserFavorites();
    _loadUnreadCount();
    _loadRecommendations();
  }

  // Add lifecycle method to refresh unread count when returning to screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUnreadCount();
  }

  void _loadUnreadCount() async {
    final userIdentifier = await userManager.getUserIdentifier();
    if (userIdentifier != null) {
      context.read<NotificationBloc>().add(LoadUnreadCount(userIdentifier));
    }
  }

  void _loadUserFavorites() async {
    final userIdentifier = await userManager.getUserIdentifier();
    if (userIdentifier != null) {
      context.read<FavBloc>().add(LoadFav(userIdentifier));
    }
  }

  void _loadRecommendations() async {
    final userIdentifier = await userManager.getUserIdentifier();
    if (userIdentifier != null) {
      context
          .read<RecommendationBloc>()
          .add(LoadRecommendations(userId: userIdentifier));
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
        userId = FirebaseAuth.instance.currentUser?.uid;
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

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW * 0.45).clamp(150.0, 220.0);
    final imageH = cardW * 3 / 4;
    final listH = imageH + 120;

    return Scaffold(
      backgroundColor: secondaryColor,
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 60,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                  padding:
                      const EdgeInsets.only(top: 12, right: 10, bottom: 10),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // căn giữa theo trục dọc
                    children: [
                      const SizedBox(width: 8),
                      SizedBox.square(
                        dimension: 28,
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: primaryColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 28,
                          splashRadius: 20,
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text.rich(
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
                            ],
                          ),
                          maxLines: 2, // tránh quá dài
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      ),

                      // Cụm action có kích thước nhỏ, cố định
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const BottomNavigator(initialIndex: 1),
                                ),
                              );
                            },
                            child: const Icon(Icons.favorite_border, size: 28),
                          ),
                          const SizedBox(width: 8),

                          // Debug: Analytics button (chỉ hiển thị trong development)
                          if (const bool.fromEnvironment('dart.vm.product') ==
                              false)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RecommendationAnalyticsPage(),
                                  ),
                                );
                              },
                              child: const Icon(Icons.analytics,
                                  size: 28, color: Colors.blue),
                            ),
                          const SizedBox(width: 8),

                          // Ép NotificationButton về kích thước 28x28 để thẳng hàng với icon tim
                          FutureBuilder<String?>(
                            future: userManager.getUserIdentifier(),
                            builder: (context, snapshot) {
                              final uid = snapshot.data;
                              return SizedBox.square(
                                dimension: 28,
                                child: uid != null
                                    ? NotificationButton(userId: uid)
                                    : const Icon(Icons.notifications_none,
                                        size: 28),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  )),
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
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          spreadRadius: 3,
                          offset: Offset(0, 5),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 300,
                          child: Text(
                            "Tìm kiếm thú cưng", // Nội dung hiển thị
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          child: const Icon(Icons.camera_alt,
                              color: Colors.blue, size: 25),
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                  ),
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
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Recommendation System
            SliverToBoxAdapter(
              child: BlocBuilder<RecommendationBloc, RecommendationState>(
                builder: (context, state) {
                  print('🔍 Current RecommendationState: $state');

                  if (state is RecommendationLoading) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            child: Text(
                              "Khuyến nghị cho bạn",
                              style: TextStyle(
                                  fontSize: 23, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ),
                    );
                  } else if (state is RecommendationLoaded) {
                    print(
                        '📋 RecommendationLoaded with ${state.recommendations.length} items');
                    return _buildRecommendationSection(state.recommendations);
                  } else if (state is RecommendationEmpty) {
                    print(
                        '⚠️ RecommendationEmpty state - trying to show simple section');
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const SimpleRecommendationSection(
                            title: "Khuyến nghị đơn giản cho bạn",
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _loadRecommendations(),
                            child: const Text('Tải khuyến nghị'),
                          ),
                        ],
                      ),
                    );
                  } else if (state is RecommendationError) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'Lỗi tải khuyến nghị: ${state.message}',
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _loadRecommendations(),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    // For Initial or any other state
                    print(
                        '🔄 Default state ($state) - showing simple recommendations');
                    return const SimpleRecommendationSection(
                      title: "Khuyến nghị đơn giản cho bạn",
                    );
                  }
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
                                        pet: pet,
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

            // // Recommendation sections
            // const SliverToBoxAdapter(child: SizedBox(height: 30)),
            // SliverToBoxAdapter(
            //   child: RecommendationSection(
            //     title: "Đề xuất cho bạn",
            //     type: RecommendationType.personalized,
            //     limit: 10,
            //   ),
            // ),
            // const SliverToBoxAdapter(child: SizedBox(height: 20)),
            // SliverToBoxAdapter(
            //   child: RecommendationSection(
            //     title: "Thú cưng thịnh hành",
            //     type: RecommendationType.trending,
            //     limit: 8,
            //   ),
            // ),
            // const SliverToBoxAdapter(child: SizedBox(height: 20)),
            // SliverToBoxAdapter(
            //   child: RecommendationSection(
            //     title: "Có thể bạn sẽ thích",
            //     type: RecommendationType.contentBased,
            //     limit: 8,
            //   ),
            // ),

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
                                          DetailPet(pet: petItems[index])));
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SampleInteractionsDemo(),
            ),
          );
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create Sample Interactions',
      ),
    );
  }

  Widget _buildRecommendationSection(List<dynamic> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            "Khuyến nghị cho bạn",
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final item = recommendations[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailPet(
                            pet: {
                              'id': item.petId,
                              'name': item.name,
                              'category': item.category,
                              'breed': item.breed,
                              'price': item.price,
                              'image': item.imageUrl,
                            },
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pet Image
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: Image.network(
                            item.imageUrl,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 120,
                                color: Colors.grey[300],
                                child: const Icon(Icons.pets, size: 40),
                              );
                            },
                          ),
                        ),
                        // Pet Info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.breed,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                Text(
                                  item.price.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 14,
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
              );
            },
          ),
        ),
      ],
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
