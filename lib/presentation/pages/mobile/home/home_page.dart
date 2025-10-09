import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/localization_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/search/search_page.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';
import 'package:pet_shop/presentation/widgets/common/app_drawer.dart';
import 'package:pet_shop/presentation/widgets/common/tab_indicator.dart';
import 'package:pet_shop/presentation/widgets/home/categories_section.dart';
import 'package:pet_shop/presentation/widgets/home/for_you_tab.dart';
import 'package:pet_shop/presentation/widgets/home/popular_tab.dart';
import 'package:pet_shop/presentation/widgets/home/all_pets_tab.dart';
import 'package:pet_shop/presentation/widgets/notification_button.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_bloc.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_event.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_bloc.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_event.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import '../../../bloc/favBloc/fav_bloc.dart';
import '../../../bloc/favBloc/fav_event.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> categories = [];
  String userName = "Người dùng"; // Default fallback
  String? userId;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UserManager userManager = UserManager();

  late TabController _tabController;
  int _selectedTabIndex = 0;
  // Scroll + dynamic search appearance
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _searchSectionKey = GlobalKey();
  double _searchRevealOffset = -1; // measured offset at which to show inline search
  bool _showSearchInAppBar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listener cho index changes
    _tabController.addListener(() {
      if (_selectedTabIndex != _tabController.index) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    
    // Animation listener để catch swipe gestures
    _tabController.animation?.addListener(() {
      final animationValue = _tabController.animation?.value ?? 0;
      final newIndex = animationValue.round();
      if (_selectedTabIndex != newIndex) {
        setState(() {
          _selectedTabIndex = newIndex;
        });
      }
    });

    // Scroll listener for search reveal
    _scrollController.addListener(_onScroll);
    // Measure search bar position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateSearchOffset());

    _initializeData();
  }

  void _initializeData() {
    fetchUserInfo();
    fetchCategories();
    context.read<PopularBloc>().add(const LoadPopularBreeds());
    _loadUserFavorites();
    _loadUnreadCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> fetchUserInfo() async {
    Map<String, dynamic>? userInfo = await authService.value.getUserInfo();
    if (!mounted) return;
    if (userInfo != null) {
      setState(() {
        userName = userInfo['displayName']?.isNotEmpty == true
            ? userInfo['displayName']
            : LocalizationHelper.getLocalizedText(context, 'you');
        userId = FirebaseAuth.instance.currentUser?.uid;
      });
    }
  }

  Future<void> fetchCategories() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection("Category").get();
      if (!mounted) return;
      setState(() {
        categories = snapshot.docs.map((doc) {
          final data = doc.data();
          return data;
        }).toList();
      });
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: secondaryColor,
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 50,
      body: SafeArea(
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // App Bar - Floating và Pinned  
              SliverAppBar(
                floating: true,
                pinned: true,
                snap: true,
                backgroundColor: secondaryColor,
                elevation: 0,
                toolbarHeight: 55,
                expandedHeight: 55,
                automaticallyImplyLeading: false,
                flexibleSpace: _buildAppBarWithSearch(l10n),
              ),

              // Hero Section
              SliverToBoxAdapter(
                child: _buildHeroSection(l10n),
              ),

              // Search Bar ở Hero Section (reference for reveal)
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _searchSectionKey,
                  child: _buildSearchBar(l10n),
                ),
              ),

              // Categories Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: CategoriesSection(categories: categories),
                ),
              ),

              // Tabs - Pinned at top when scrolling
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabHeaderDelegate(
                  child: _buildTabBar(l10n),
                  selectedIndex: _selectedTabIndex,
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: const [
              ForYouTab(),
              PopularTab(),
              AllPetsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarWithSearch(AppLocalizations? l10n) {
    return Container(
      color: secondaryColor,
      padding: const EdgeInsets.only(top: 12, right: 10, bottom: 10, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drawer icon - luôn ở bên trái cùng
          SizedBox.square(
            dimension: 28,
            child: IconButton(
              icon: const Icon(Icons.menu, color: primaryColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 28,
              splashRadius: 20,
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          
          // Search bar inline xuất hiện khi phần search gốc đã bị scroll qua
          if (_showSearchInAppBar) 
            Expanded(
              child: Container(
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          spreadRadius: 1,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            LocalizationHelper.getLocalizedText(context, 'searchPetsPlaceholder'),
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Nếu chưa show inline search => Spacer đẩy icons sang phải
          if (!_showSearchInAppBar) const Spacer(),
          
          // Right icons - luôn ở bên phải cùng
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
              FutureBuilder<String?>(
                future: userManager.getUserIdentifier(),
                builder: (context, snapshot) {
                  final uid = snapshot.data;
                  return SizedBox.square(
                    dimension: 28,
                    child: uid != null
                        ? NotificationButton(userId: uid)
                        : const Icon(Icons.notifications_none, size: 28),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 23,
              ),
              children: [
                TextSpan(text: "${LocalizationHelper.getLocalizedText(context, 'hello')}, "),
                TextSpan(
                  text: "$userName\n",
                  style: const TextStyle(color: primaryColor),
                ),
                TextSpan(
                  text: l10n?.welcomeToHappyPets ??
                      LocalizationHelper.getLocalizedText(context, 'welcomeToHappyPets'),
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          const SizedBox(height: 10),
          Text(
            l10n?.findPerfectCompanion ??
                LocalizationHelper.getLocalizedText(context, 'findPerfectCompanion'),
            style: const TextStyle(
              fontSize: 28,
              color: Colors.black,
              height: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations? l10n) {
    return Container(
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
              SizedBox(
                width: 300,
                child: Text(
                  l10n?.searchPetsPlaceholder ?? LocalizationHelper.getLocalizedText(context, 'searchPetsPlaceholder'),
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.blue,
                  size: 25,
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations? l10n) {
    return Container(
      color: secondaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            TabIndicator(
              title: l10n?.forYou ?? 'Dành cho bạn',
              isSelected: _selectedTabIndex == 0,
              onTap: () => _tabController.animateTo(0),
            ),
            TabIndicator(
              title: l10n?.popular ?? 'Phổ biến',
              isSelected: _selectedTabIndex == 1,
              onTap: () => _tabController.animateTo(1),
            ),
            TabIndicator(
              title: l10n?.allPets ?? 'Tất cả',
              isSelected: _selectedTabIndex == 2,
              onTap: () => _tabController.animateTo(2),
            ),
          ],
        ),
      ),
    );
  }

  void _calculateSearchOffset() {
    final ctx = _searchSectionKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    // When the original search bar top goes under the toolbar, show inline search
    _searchRevealOffset = pos.dy - kToolbarHeight;
    _onScroll();
  }

  void _onScroll() {
    if (_searchRevealOffset < 0) return; // not measured yet
    final offset = _scrollController.position.pixels;
    final shouldShow = offset >= _searchRevealOffset;
    if (shouldShow != _showSearchInAppBar) {
      setState(() => _showSearchInAppBar = shouldShow);
    }
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final int selectedIndex;

  _TabHeaderDelegate({required this.child, required this.selectedIndex});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: secondaryColor,
      child: child,
    );
  }

  @override
  double get maxExtent => 48.0;

  @override
  double get minExtent => 48.0;

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex;
  }
}
