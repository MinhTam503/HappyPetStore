import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/recommendation_tracking_service.dart';
import 'package:pet_shop/data/models/viewed_pet_model.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_bloc.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_event.dart';
import 'package:pet_shop/presentation/pages/mobile/infoStore/StoreInfoScreen.dart';
import 'package:pet_shop/presentation/pages/mobile/chat/chat_page.dart';
import '../../../bloc/favBloc/fav_bloc.dart';
import '../../../bloc/favBloc/fav_event.dart';
import '../../../bloc/favBloc/fav_state.dart';
import '../../../widgets/pet_items_all.dart';
// import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_event.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_state.dart';

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
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection("Pets").get();

      setState(() {
        petItems = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
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
        _showMessage('Vui lòng đăng nhập để thêm vào giỏ hàng');
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
      final cartItem = {
        'productId': data['id'] ?? data['productId'] ?? '',
        'name': data['name'] ?? '',
        'imageUrl': data['imageUrl'] ?? '',
        'price': data['price'] ?? 0,
        'breed': data['breed'] ?? '',
        'age': data['age'] ?? '',
        'weight': data['weight'] ?? '',
        'gender': data['sex'] ?? data['color'] ?? '',
        'description':
            data['about'] ?? data['breed'] ?? 'Sản phẩm gợi ý từ hệ thống',
        'category': data['category'] ?? 'Pet',
        'quantity': 1,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
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
                            data['name'] ?? 'Không có tên',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          CurrencyHelper.formatVND(data['price'] ?? 0),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
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
                            const Text(
                              'Thông tin cơ bản',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Giống',
                                data['breed']?.toString() ?? 'Không xác định'),
                            _buildInfoRow('Tuổi',
                                data['age']?.toString() ?? 'Không xác định'),
                            _buildInfoRow('Cân nặng',
                                data['weight']?.toString() ?? 'Không xác định'),
                            _buildInfoRow(
                                'Giới tính',
                                (data['sex'] ?? data['color'])?.toString() ??
                                    'Không xác định'),
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
                            const Text(
                              'Mô tả',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isExpand
                                  ? (data['about'] ?? 'Không có mô tả')
                                  : (data['about'] ?? 'Không có mô tả').length >
                                          100
                                      ? '${(data['about'] ?? 'Không có mô tả').substring(0, 100)}...'
                                      : (data['about'] ?? 'Không có mô tả'),
                              style: const TextStyle(fontSize: 16),
                            ),
                            if ((data['about'] ?? '').length > 100)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    isExpand = !isExpand;
                                  });
                                },
                                child: Text(isExpand ? 'Thu gọn' : 'Xem thêm'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Thông tin cửa hàng
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.store, color: primaryColor),
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

                    // Sản phẩm tương tự
                    const Text(
                      'Sản phẩm tương tự',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: petItems.length > 3 ? 400 : 400,
                      child: GridView.builder(
                        scrollDirection: Axis.vertical,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: petItems.length > 6 ? 6 : petItems.length,
                        itemBuilder: (context, index) {
                          final item = petItems[index];
                          if (item['id'] == data['id'])
                            return const SizedBox.shrink();

                          return PetItemsAll(
                            pet: item,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 100), // Space for bottom button
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
                  backgroundColor: secondaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    // side: const BorderSide(color: primaryColor),
                  ),
                  elevation: 4,
                  minimumSize: const Size.fromHeight(65),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.message, color: primaryColor, size: 24),
                    Text(
                      'Chat ngay',
                      style: TextStyle(
                        fontSize: 15,
                        color: primaryColor,
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
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                    Text(
                      'Thêm vào giỏ hàng',
                      style: TextStyle(
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
}
