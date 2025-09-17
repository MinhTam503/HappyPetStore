import 'package:flutter/material.dart';
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

class PetItemsAll extends StatefulWidget {
  final Map<String, dynamic> pet;

  const PetItemsAll({super.key, required this.pet});

  @override
  State<PetItemsAll> createState() => _PetItemsAllState();
}

class _PetItemsAllState extends State<PetItemsAll> {
  String? lastCartMessage;
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
            final nameSize = w < 180 ? 14.0 : 16.0;
            final metaSize = w < 180 ? 12.0 : 13.0;

            Widget card = AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              transform: Matrix4.identity()
                ..translate(0.0, (kIsWeb && _hover) ? -2.0 : 0.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
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
                            // Price pill (góc trái dưới)
                            Positioned(
                              left: 2,
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.pink.shade400,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.pink.shade200.withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      priceStr,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Favorite (góc phải trên)
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
                                  final userIdentifier = await userManager.getUserIdentifier();
                                  if (userIdentifier == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text("Please login to continue")));
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

                      // Nội dung
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Tooltip(
                                message: name,
                                waitDuration: const Duration(milliseconds: 400),
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: nameSize,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (breed.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                          child: Text(
                            breed,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: metaSize,
                              color: Colors.grey.shade600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Hàng nút action (Add to cart)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(5, 6, 5, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: _PrimaryButton(
                                  label: 'Thêm vào giỏ hàng',
                                  icon: Icons.shopping_cart_outlined,
                                  onTap: () async {
                                    UserManager userManager = UserManager();
                                    final userIdentifier = await userManager.getUserIdentifier();
                                    if (userIdentifier == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text("Please login to continue")));
                                      return;
                                    }
                                    context
                                        .read<CartBloc>()
                                        .add(AddToCart(userIdentifier, {
                                          'productId': widget.pet['id'],
                                          'name': name,
                                          'imageUrl': imageUrl,
                                          'price': widget.pet['price'],
                                        }));
                                  },
                                  listenCart: (ctx, state) {
                                    if (state is CartLoaded &&
                                        state.message != null) {
                                      if (lastCartMessage != state.message) {
                                        ScaffoldMessenger.of(ctx)
                                            .hideCurrentSnackBar();
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(state.message!)),
                                        );
                                        lastCartMessage = state.message;
                                      }
                                    } else if (state is CartError) {
                                      ScaffoldMessenger.of(ctx)
                                          .hideCurrentSnackBar();
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Lỗi: ${state.message}')),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
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
      child: SizedBox(
        height: 42,
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}
