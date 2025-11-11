import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:pet_shop/presentation/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_event.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_state.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/message_manager.dart';
// import 'package:pet_shop/core/utils/localization_helper.dart';

class PopularPetItems extends StatefulWidget {
  final Map<String, dynamic> pet;

  const PopularPetItems({super.key, required this.pet});

  @override
  State<PopularPetItems> createState() => _PetItemsAllState();
}

class _PetItemsAllState extends State<PopularPetItems> {
  bool _hover = false;

  String _priceText(dynamic raw) => CurrencyHelper.formatVND(raw);

  @override
  Widget build(BuildContext context) {
    final name = widget.pet['name']?.toString() ?? '';
    final breed = widget.pet['breed']?.toString() ?? '';
    final imageUrl = widget.pet['imageUrl']?.toString() ?? '';
    final priceStr = _priceText(widget.pet['price']);

    return BlocBuilder<FavBloc, FavState>(
      builder: (context, state) {
        bool isFavorite = false;
        if (state is FavLoaded) {
          isFavorite =
              state.items.any((it) => it['productId'] == widget.pet['id']);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final nameSize = w < 200 ? 14.0 : 16.0;
            final metaSize = w < 200 ? 12.0 : 13.0;

            Widget card = AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              transform: Matrix4.identity()
                ..translate(0.0, (kIsWeb && _hover) ? -2.0 : 0.0)
                ..scale((kIsWeb && _hover) ? 1.015 : 1.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: (kIsWeb && _hover)
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [
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
                  onTap: null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image with badges
                      AspectRatio(
                        aspectRatio: 3 / 2,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image
                            Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Color(0xFFEFEFEF)),
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return const _ImageSkeleton();
                              },
                            ),

                            // Favorite (top-right)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: _CircleIconButton(
                                icon: isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                foreground:
                                    isFavorite ? Colors.red : Colors.black87,
                                background: Colors.white,
                                onTap: () async {
                                  UserManager userManager = UserManager();
                                  await userManager.initialize();
                                  final userIdentifier = await userManager.getUserIdForOperations();
                                  print("💖 PopularPetItems: Using userId for favorites: $userIdentifier");
                                  
                                  if (userIdentifier == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)?.loginRequired ?? 'Vui lòng đăng nhập để tiếp tục',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!isFavorite) {
                                    context
                                        .read<FavBloc>()
                                        .add(AddToFav(userIdentifier, {
                                          'productId': widget.pet['id'],
                                          'name': name,
                                          'imageUrl': imageUrl,
                                          'price': widget.pet['price'],
                                        }));
                                  } else {
                                    context.read<FavBloc>().add(
                                        RemoveFromFav(userIdentifier, widget.pet['id']));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content block – compact to hug items
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (name.isNotEmpty)
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: nameSize,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                // Price chip outside image
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.pink.shade400,
                                        Colors.pink.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    priceStr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (breed.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    breed,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: metaSize,
                                      color: Colors.black.withOpacity(0.65),
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Action button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        child: SizedBox(
                          height: 34,
                          width: double.infinity,
                          child: _PrimaryButton(
                            label: AppLocalizations.of(context)?.addToCart ?? 'Thêm vào giỏ hàng',
                            icon: Icons.shopping_cart_outlined,
                            onTap: () async {
                              UserManager userManager = UserManager();
                              await userManager.initialize();
                              final userIdentifier = await userManager.getUserIdForOperations();
                              print("🛒 PopularPetItems: Using userId for cart: $userIdentifier");
                              
                              if (userIdentifier == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(context)?.loginRequired ?? 'Vui lòng đăng nhập để tiếp tục',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final now = DateTime.now();
                              context.read<CartBloc>().add(AddToCart(userIdentifier, {
                                    'productId': widget.pet['id'],
                                    'name': name,
                                    'imageUrl': imageUrl,
                                    'price': widget.pet['price'],
                                    // meta for cart display
                                    'breed': widget.pet['breed'] ?? '',
                                    'gender': widget.pet['sex'] ?? widget.pet['gender'] ?? '',
                                    'color': widget.pet['color'] ?? '',
                                    'quantity': 1,
                                    // timestamps
                                    'createdAtMillis': now.millisecondsSinceEpoch,
                                    'createdAt': now.toIso8601String(),
                                  }));
                            },
                            listenCart: (ctx, state) {
                              if (state is CartLoaded &&
                                  state.message != null) {
                                // Use MessageManager to prevent duplicate messages
                                if (MessageManager().shouldShowMessage(state.message!)) {
                                  ScaffoldMessenger.of(ctx)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(state.message!),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } else if (state is CartError) {
                                ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                      content: Text('Lỗi: ${state.message}'),
                                      duration: const Duration(seconds: 3)),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (kIsWeb) {
              card = MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: card,
              );
            }
            return card;
          },
        );
      },
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
                      color: Colors.black.withOpacity(0.06), blurRadius: 8)
                ]),
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

/// Nút tròn nổi (favorite)
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

/// Nút primary full-width “Thêm vào giỏ”
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final BlocWidgetListener<CartState> listenCart;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.listenCart,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartBloc, CartState>(
      listener: listenCart,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor, width: 1.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }
}
