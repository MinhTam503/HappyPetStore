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

class PetItemsAll extends StatefulWidget {
  final Map<String, dynamic> pet;

  const PetItemsAll({super.key, required this.pet});

  @override
  State<PetItemsAll> createState() => _PetItemsAllState();
}

class _PetItemsAllState extends State<PetItemsAll> {
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
                  onTap: null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Flexible image section to avoid overflow
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
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
                              child: imageUrl.isEmpty
                                  ? const _ImageSkeleton()
                                  : null,
                            ),
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
                                  final userIdentifier = await userManager
                                      .getUserIdForOperations();
                                  if (userIdentifier == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "Please login to continue"),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!isFavorite) {
                                    context.read<FavBloc>().add(AddToFav(
                                      userIdentifier,
                                      {
                                        'productId': widget.pet['id'],
                                        'name': name,
                                        'imageUrl': imageUrl,
                                        'price': widget.pet['price'],
                                      },
                                    ));
                                  } else {
                                    context.read<FavBloc>().add(
                                          RemoveFromFav(
                                            userIdentifier,
                                            widget.pet['id'],
                                          ),
                                        );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: nameSize,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            if (breed.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  breed,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: metaSize,
                                    color: Colors.grey.shade600,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                priceStr,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        child: _PrimaryButton(
                            label: AppLocalizations.of(context)?.addToCart ?? 'Thêm vào giỏ hàng',
                          icon: Icons.add_shopping_cart,
                          onTap: () async {
                            UserManager userManager = UserManager();
                            await userManager.initialize();
                            final userIdentifier = await userManager
                                .getUserIdForOperations();
                            if (userIdentifier == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please login to continue"),
                                ),
                              );
                              return;
                            }
                            context.read<CartBloc>().add(AddToCart(
                              userIdentifier,
                              {
                                'productId': widget.pet['id'],
                                'name': name,
                                'imageUrl': imageUrl,
                                'price': widget.pet['price'],
                              },
                            ));
                          },
                          listenCart: (ctx, state) {
                            if (state is CartLoaded && state.message != null) {
                              if (MessageManager()
                                  .shouldShowMessage(state.message!)) {
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
                              ScaffoldMessenger.of(ctx)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi: ${state.message}'),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
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
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          minimumSize: const Size.fromHeight(0),
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
