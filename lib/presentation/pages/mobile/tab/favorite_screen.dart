import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/presentation/widgets/common/app_drawer.dart';

import '../pet/detail_pet.dart';

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

  // int _computeCrossAxisCount(double width) {
  //   if (width < 500) return 2; // phone
  //   if (width < 800) return 2; // small tablet
  //   if (width < 1200) return 3; // large tablet / small desktop
  //   return 4; // desktop
  //   // Tùy dự án, bạn có thể tinh chỉnh breakpoints này.
  // }

  // double _computeChildAspectRatio(int crossAxisCount, double width) {
  //   // Với 1 cột: card dạng hàng ngang => rộng : cao ≈ 3.6
  //   // Nhiều cột: card gần như vuông đứng hơn
  //   if (crossAxisCount == 1) return 3.6;
  //   if (crossAxisCount == 2) return 2.0;
  //   if (crossAxisCount == 3) return 1.6;
  //   return 1.4;
  // }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: secondaryColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: primaryColor,
          size: 28,
        ),
        key: _scaffoldKey,
        centerTitle: true,
        backgroundColor: secondaryColor,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.favorites,
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
                      const Icon(Icons.favorite_border,
                          size: 56, color: Colors.black26),
                      const SizedBox(height: 10),
                      Text(
                        AppLocalizations.of(context)!.noFavoriteYet,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.addFavoritePetsMessage,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  // final width = constraints.maxWidth;
                  // final crossAxisCount = _computeCrossAxisCount(width);

                  // final aspect =
                  //     _computeChildAspectRatio(crossAxisCount, width);

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.72, // responsive card ratio
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
                                      DetailPet(pet: itemData),
                                ),
                              );
                            },
                            onDelete: () {
                              if (userIdentifier != null) {
                                context.read<FavBloc>().add(
                                    RemoveFromFav(userIdentifier!, productId));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          AppLocalizations.of(context)!
                                              .errorOccurred(''))),
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
              return Center(
                  child: Text(AppLocalizations.of(context)!.unknownState));
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
    final breed = (data["breed"] ?? "").toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section with flexible expand
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Pet Image
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEFEF),
                        image: imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageUrl.isEmpty ? const _ImageSkeleton() : null,
                    ),

                    // Favorite Button (top right)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _CircleIconButton(
                        icon: Icons.favorite,
                        foreground: Colors.red,
                        background: Colors.white,
                        onTap: onDelete,
                      ),
                    ),
                  ],
                ),
              ),

              // Pet Information
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pet Name
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),

                    // Breed
                    if (breed.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          breed,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.1,
                          ),
                        ),
                      ),

                    // Price
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        CurrencyHelper.formatVND(price),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              // View Details Button
              // Padding(
              //   padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              //   child: SizedBox(
              //     width: double.infinity,
              //     child: ElevatedButton.icon(
              //       onPressed: onOpen,
              //       style: ElevatedButton.styleFrom(
              //         backgroundColor: primaryColor,
              //         foregroundColor: Colors.white,
              //         elevation: 0,
              //         padding: const EdgeInsets.symmetric(
              //           horizontal: 12,
              //           vertical: 10,
              //         ),
              //         shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(12),
              //         ),
              //         textStyle: const TextStyle(fontWeight: FontWeight.w700),
              //         minimumSize: const Size.fromHeight(0),
              //         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              //       ),
              //       icon: const Icon(Icons.visibility, size: 18),
              //       label: Text(
              //         LocalizationHelper.getLocalizedText(
              //             context, 'viewDetails'),
              //         maxLines: 1,
              //         overflow: TextOverflow.ellipsis,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Image skeleton placeholder
class _ImageSkeleton extends StatelessWidget {
  const _ImageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFF3F4F6)),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(6.0),
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Circle icon button (favorite)
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: foreground),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFFF3F4F6)),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info skeleton
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),

                // Breed
                Container(
                  height: 13,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),

                // Price
                Container(
                  height: 15,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

          // Button skeleton
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Container(
              height: 38,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
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
