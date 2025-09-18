import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/user_manager.dart';

import '../detail_pet.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  late String? userIdentifier;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  void _initializeUser() async {
    UserManager userManager = UserManager();
    await userManager.initialize();
    
    // Sử dụng userId thay vì email để consistent với logic mới
    userIdentifier = await userManager.getUserIdForOperations();
    
    print("💖 FavoriteScreen: Using userId for favorites: $userIdentifier");
    
    if (userIdentifier != null) {
      context.read<FavBloc>().add(LoadFav(userIdentifier!));
    } else {
      print("❌ FavoriteScreen: No userId found, user may not be logged in");
    }
  }

  int _computeCrossAxisCount(double width) {
    if (width < 500) return 1; // phone
    if (width < 800) return 2; // small tablet
    if (width < 1200) return 3; // large tablet / small desktop
    return 4; // desktop
    // Tùy dự án, bạn có thể tinh chỉnh breakpoints này.
  }

  double _computeChildAspectRatio(int crossAxisCount, double width) {
    // Với 1 cột: card dạng hàng ngang => rộng : cao ≈ 3.6
    // Nhiều cột: card gần như vuông đứng hơn
    if (crossAxisCount == 1) return 3.6;
    if (crossAxisCount == 2) return 2.0;
    if (crossAxisCount == 3) return 1.6;
    return 1.4;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: secondaryColor,
        elevation: 0,
        title: const Text(
          "Favorite",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<FavBloc, FavState>(
          builder: (context, state) {
            if (state is FavLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is FavLoaded) {
              final favoriteItems = state.items;

              if (favoriteItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border,
                          size: 56, color: Colors.black26),
                      const SizedBox(height: 10),
                      Text(
                        "No Favorite yet",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Hãy thêm vài thú cưng vào danh sách yêu thích nhé!",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = _computeCrossAxisCount(width);
                  final aspect =
                      _computeChildAspectRatio(crossAxisCount, width);

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: aspect,
                    ),
                    itemCount: favoriteItems.length,
                    itemBuilder: (context, index) {
                      final favorite = favoriteItems[index];
                      final productId = favorite["productId"];

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection("Pets")
                            .doc(productId)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _FavoriteSkeleton();
                          }
                          if (!snapshot.hasData ||
                              !(snapshot.data?.exists ?? false)) {
                            return const _ErrorCard(
                                message: 'Error loading favorites');
                          }

                          final itemData =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          if (itemData == null) {
                            return const _ErrorCard(
                                message: 'No data available for this favorite');
                          }

                          return _FavoriteCard(
                            data: itemData,
                            onOpen: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DetailPet(grocery: itemData),
                                ),
                              );
                            },
                            onDelete: () {
                              if (userIdentifier != null) {
                                context
                                    .read<FavBloc>()
                                    .add(RemoveFromFav(userIdentifier!, productId));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Đã có lỗi xảy ra")),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            } else if (state is FavError) {
              return Center(child: Text("Error: ${state.message}"));
            } else {
              return const Center(child: Text("Unknown state"));
            }
          },
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _FavoriteCard({
    required this.data,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data["name"] ?? "").toString();
    final price = data["price"];
    final imageUrl = (data["imageUrl"] ?? "").toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 2,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Stack(
            children: [
              // Nội dung
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Ảnh vuông, bo góc
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 1, // vuông
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child:
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(
                                    Icons.image_not_supported_outlined),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            CurrencyHelper.formatVND(price),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Nút delete nổi góc phải
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.white.withOpacity(0.9),
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    tooltip: "Remove from Favorites",
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteSkeleton extends StatelessWidget {
  const _FavoriteSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // khung ảnh
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 12),
          // khung text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 18, width: 140, color: Colors.black12),
                const SizedBox(height: 10),
                Container(height: 16, width: 90, color: Colors.black12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
