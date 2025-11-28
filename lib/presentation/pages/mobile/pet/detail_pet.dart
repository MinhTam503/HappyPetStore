import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/recommendation_tracking_service.dart';
import 'package:pet_shop/data/models/viewed_pet_model.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_bloc.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_event.dart';
import 'package:pet_shop/presentation/pages/mobile/infoStore/StoreInfoScreen.dart';
import 'package:pet_shop/presentation/pages/mobile/chat/chat_page.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/pet_try_on_page.dart';
import '../../../bloc/favBloc/fav_bloc.dart';
import '../../../bloc/favBloc/fav_event.dart';
import '../../../bloc/favBloc/fav_state.dart';
import '../../../widgets/pet_items_all.dart';
// import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_event.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_state.dart';
import 'package:pet_shop/core/utils/gender_localizer.dart';

class DetailPet extends StatefulWidget {
  final Map<String, dynamic> pet;

  const DetailPet({super.key, required this.pet});

  @override
  State<DetailPet> createState() => _DetailPetState();
}

class _DetailPetState extends State<DetailPet> {
  bool isExpand = false;
  List<Map<String, dynamic>> petItems = [];
  final UserManager userManager = UserManager();
  List<Map<String, dynamic>> similarPets = [];

  @override
  void initState() {
    super.initState();
    fetchPetData();
    final pet = widget.pet;

    // Track pet view for recommendation system
    _trackPetView();

    // Dispatch event to BLoC to handle both local state and Firestore
    context.read<RecentPetsBloc>().add(AddViewedPet(ViewedPetModel(
          id: pet['id'],
          name: pet['name'],
          imageUrl: pet["imageUrl"],
          category: pet['category'],
          breed: pet['breed'],
          price: pet['price'],
          viewedAt: DateTime.now(),
          isAvailable: pet['isAvailable'],
          status: pet['status'],
        )));
  }

  void _trackPetView() async {
    try {
      final petId = widget.pet['id'] ?? widget.pet['productId'] ?? '';
      if (petId.isNotEmpty) {
        await RecommendationTrackingService().trackPetView(
          petId,
          metadata: {
            'category': widget.pet['category'],
            'breed': widget.pet['breed'],
            'price': widget.pet['price'],
          },
        );
      }
    } catch (e) {
      print('Error tracking pet view: $e');
    }
  }

  void _trackAddToCart(String petId) async {
    try {
      await RecommendationTrackingService().trackAddToCart(
        petId,
        metadata: {
          'category': widget.pet['category'],
          'breed': widget.pet['breed'],
          'price': widget.pet['price'],
        },
      );
    } catch (e) {
      print('Error tracking add to cart: $e');
    }
  }

  void _trackFavorite(String petId) async {
    try {
      await RecommendationTrackingService().trackFavorite(
        petId,
        metadata: {
          'category': widget.pet['category'],
          'breed': widget.pet['breed'],
          'price': widget.pet['price'],
        },
      );
    } catch (e) {
      print('Error tracking favorite: $e');
    }
  }

  Future<void> fetchPetData() async {
    try {
      final current = widget.pet;
      final category = current['category'];
      final breed = current['breed'];
      // Query tất cả pet cùng category (không filter breed ở query để có cả 2 nhóm)
      final snapshot = await FirebaseFirestore.instance
          .collection("Pets")
          .where('category', isEqualTo: category)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> sameBreed = [];
      final List<Map<String, dynamic>> sameCategoryOtherBreed = [];

      for (final doc in snapshot.docs) {
        if (doc.id == current['id']) continue; // skip chính nó
        final data = doc.data();
        data['id'] = doc.id;
        final docBreed = data['breed'];
        if (breed != null &&
            breed.toString().isNotEmpty &&
            docBreed != null &&
            docBreed == breed) {
          sameBreed.add(data);
        } else {
          sameCategoryOtherBreed.add(data);
        }
      }

      // Kết quả: ưu tiên cùng breed trước, sau đó các pet khác cùng category
      final combined = <Map<String, dynamic>>[
        ...sameBreed,
        ...sameCategoryOtherBreed
      ];

      setState(() {
        similarPets = combined.take(20).toList();
      });
    } catch (e) {
      print('Lỗi khi tải dữ liệu: $e');
    }
  }

  Future<void> _addToCart() async {
    try {
      // Kiểm tra đăng nhập sử dụng UserManager (hỗ trợ tất cả phương thức đăng nhập)
      final userIdentifier = await userManager.getUserIdentifier();
      if (userIdentifier == null) {
        _showMessage(AppLocalizations.of(context)?.loginRequiredAddToCart ??
            'Vui lòng đăng nhập để thêm vào giỏ hàng');
        return;
      }

      // Kiểm tra thông tin người dùng đầy đủ cho checkout
      final hasCompleteInfo = await userManager.hasCompleteUserInfo();
      if (!hasCompleteInfo) {
        _showMessage('Vui lòng cập nhật đầy đủ thông tin tài khoản');
        return;
      }

      // Chuẩn bị dữ liệu giỏ hàng
      final data = widget.pet;
      
      // Normalize gender to standard 'male' or 'female' for storage
      final rawGender = data['sex'] ?? data['gender'] ?? 'male';
      final normalizedGender = GenderLocalizer.normalizeGenderForStorage(rawGender.toString());
      
      final cartItem = {
        'productId': data['id'] ?? data['productId'] ?? '',
        'name': data['name'] ?? '',
        'imageUrl': data['imageUrl'] ?? '',
        'price': data['price'] ?? 0,
        'breed': data['breed'] ?? '',
        'age': data['age'] ?? '',
        'weight': data['weight'] ?? '',
        'gender': normalizedGender, // Store as 'male' or 'female'
        'color': data['color'] ?? '',
        'description':
            data['about'] ?? data['breed'] ?? 'Sản phẩm gợi ý từ hệ thống',
        'category': data['category'] ?? 'Pet',
        'quantity': 1,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
        // also provide consistent fields used elsewhere
        'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Thêm vào giỏ hàng sử dụng BLoC
      context.read<CartBloc>().add(AddToCart(userIdentifier, cartItem));

      // Track add to cart for recommendation system
      _trackAddToCart(cartItem['productId']);

      // Không hiển thị message thủ công - để BlocListener xử lý
    } catch (e) {
      _showMessage('Có lỗi xảy ra: ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.pet;
    final l10n = AppLocalizations.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: BlocListener<CartBloc, CartState>(
        listener: (context, state) {
          if (state is CartError) {
            _showMessage('Lỗi giỏ hàng: ${state.message}');
          }
          // Loại bỏ việc hiển thị message thành công để tránh duplicate
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: screenHeight * 0.4,
              pinned: true,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.black,
                  ),
                ),
              ),
              actions: [
                BlocBuilder<FavBloc, FavState>(
                  builder: (context, favState) {
                    bool isFavorite = false;
                    if (favState is FavLoaded) {
                      isFavorite = favState.items
                          .any((it) => it['productId'] == data['id']);
                    }
                    return IconButton(
                      onPressed: () async {
                        UserManager userManager = UserManager();
                        await userManager.initialize();
                        final userIdentifier =
                            await userManager.getUserIdForOperations();
                        print(
                            "💖 DetailPet: Using userId for favorites: $userIdentifier");

                        if (userIdentifier != null) {
                          if (!isFavorite) {
                            context
                                .read<FavBloc>()
                                .add(AddToFav(userIdentifier, {
                                  'productId': data['id'],
                                  'name': data["name"],
                                  'imageUrl': data["imageUrl"],
                                  'price': data['price'],
                                }));
                            // Track favorite action
                            _trackFavorite(data['id']);
                          } else {
                            context
                                .read<FavBloc>()
                                .add(RemoveFromFav(userIdentifier, data['id']));
                          }
                        } else {
                          print(
                              "❌ DetailPet: No userId found for favorites operation");
                        }
                      },
                      icon: Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.black,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PetTryOnPage(pet: data),
                      ),
                    );
                  },
                  icon: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.view_in_ar,
                      color: Colors.black,
                    ),
                  ),
                  tooltip: 'Thử trong phòng',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(data['imageUrl'] ?? ''),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tên và giá
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data['name'] ?? (l10n?.noName ?? 'Không có tên'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          CurrencyHelper.formatVND(data['price'] ?? 0),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Thông tin cơ bản
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n?.basicInfo ?? 'Thông tin cơ bản',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                                l10n?.breed ?? 'Giống',
                                data['breed']?.toString() ??
                                    (l10n?.unknown ?? 'Không xác định')),
                            _buildInfoRow(
                                l10n?.age ?? 'Tuổi',
                                data['age']?.toString() ??
                                    (l10n?.unknown ?? 'Không xác định')),
                            _buildInfoRow(
                                l10n?.weight ?? 'Cân nặng',
                                (data['weight'] != null
                                    ? "${data['weight']} kg"
                                    : (l10n?.unknown ?? 'Không xác định'))),
                            _buildInfoRow(
                                l10n?.gender ?? 'Giới tính',
                                GenderLocalizer.getLocalizedGender(
                                  l10n!,
                                  data['category']?.toString(),
                                  (data['sex'] ?? data['gender'])?.toString()
                                )),
                            _buildColorInfoRow(l10n?.color ?? 'Màu sắc',
                                data['color'] ?? 'colorMixed'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mô tả
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n?.description ?? 'Mô tả',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isExpand
                                  ? (data['about'] ??
                                      (l10n?.noDescription ?? 'Không có mô tả'))
                                  : (data['about'] ??
                                                  (l10n?.noDescription ??
                                                      'Không có mô tả'))
                                              .length >
                                          100
                                      ? '${(data['about'] ?? (l10n?.noDescription ?? 'Không có mô tả')).substring(0, 100)}...'
                                      : (data['about'] ??
                                          (l10n?.noDescription ??
                                              'Không có mô tả')),
                              style: const TextStyle(fontSize: 16),
                            ),
                            if ((data['about'] ?? '').length > 100)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    isExpand = !isExpand;
                                  });
                                },
                                child: Text(isExpand
                                    ? (l10n?.showLess ?? 'Thu gọn')
                                    : (l10n?.readMore ?? 'Xem thêm')),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Thông tin cửa hàng
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.store, color: Theme.of(context).colorScheme.primary),
                        title: const Text('Thông tin cửa hàng'),
                        subtitle: const Text('Xem chi tiết về cửa hàng'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StoreInfoScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (similarPets.isNotEmpty) ...[
                      Text(
                        l10n?.similarProducts ?? 'Sản phẩm tương tự',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 22),
                      GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: similarPets.length,
                        itemBuilder: (context, index) {
                          final item = similarPets[index];
                          return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DetailPet(pet: item),
                                    ));
                              },
                              child: PetItemsAll(pet: item));
                        },
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      Text(
                        l10n?.noSimilarProducts ??
                            'Không tìm thấy sản phẩm tương tự',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 60), // Space for bottom button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    // side: const BorderSide(color: primaryColor),
                  ),
                  elevation: 4,
                  minimumSize: const Size.fromHeight(65),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.message, color: Theme.of(context).colorScheme.primary, size: 24),
                    Text(
                      'Liên hệ',
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: primaryColor),
                  ),
                  elevation: 4,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                    Text(
                      (AppLocalizations.of(context)?.addToCart ??
                          'Thêm vào giỏ hàng'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorInfoRow(String label, String colorKey) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _getColorFromKey(colorKey),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getLocalizedColor(l10n, colorKey),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorFromKey(String colorKey) {
    switch (colorKey) {
      case 'colorBrown':
        return Colors.brown;
      case 'colorBlack':
        return Colors.black;
      case 'colorWhite':
        return Colors.white;
      case 'colorGray':
        return Colors.grey;
      case 'colorGolden':
        return Colors.amber;
      case 'colorCream':
        return const Color(0xFFF5DEB3);
      case 'colorOrange':
        return Colors.orange;
      case 'colorBlue':
        return Colors.blue;
      case 'colorGreen':
        return Colors.green;
      case 'colorRed':
        return Colors.red;
      case 'colorMixed':
        return Colors.grey.shade400;
      default:
        return Colors.grey;
    }
  }

  String _getLocalizedColor(AppLocalizations? l10n, String colorKey) {
    if (l10n == null) return colorKey;

    switch (colorKey) {
      case 'colorBrown':
        return l10n.colorBrown;
      case 'colorBlack':
        return l10n.colorBlack;
      case 'colorWhite':
        return l10n.colorWhite;
      case 'colorGray':
        return l10n.colorGray;
      case 'colorGolden':
        return l10n.colorGolden;
      case 'colorCream':
        return l10n.colorCream;
      case 'colorOrange':
        return l10n.colorOrange;
      case 'colorBlue':
        return l10n.colorBlue;
      case 'colorGreen':
        return l10n.colorGreen;
      case 'colorRed':
        return l10n.colorRed;
      case 'colorMixed':
        return l10n.colorMixed;
      default:
        return colorKey;
    }
  }
}
