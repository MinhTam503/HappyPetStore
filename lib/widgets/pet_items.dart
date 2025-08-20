import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/bloc/cartBloc/cart_event.dart';
import 'package:pet_shop/bloc/cartBloc/cart_state.dart';
import 'package:pet_shop/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PetItems extends StatefulWidget {
  final Map<String, dynamic> pet;
  const PetItems({super.key, required this.pet});

  @override
  State<PetItems> createState() => _PetItemsState();
}

class _PetItemsState extends State<PetItems> {
  String? lastCartMessage;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavBloc, FavState>(
      builder: (context, state) {
        final bool isFavorite = state is FavLoaded
            ? state.items.any((it) => it['productId'] == widget.pet['id'])
            : false;

        Widget card = AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, (kIsWeb && _hover) ? -2.0 : 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(kIsWeb && _hover ? 0.10 : 0.05),
                blurRadius: kIsWeb && _hover ? 14 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {}, // có thể mở chi tiết ở ngoài
              child: LayoutBuilder(
                builder: (context, c) {
                  final double w =
                      c.maxWidth; // bị ràng buộc bởi itemExtent của list ngang
                  // Thang kích thước: <160 = "nhỏ", >200 = "rộng"
                  final bool compact = w < 165;
                  final bool wide = w > 200;

                  final double nameSize = wide ? 18 : (compact ? 14 : 16);
                  final double priceSize = wide ? 16 : (compact ? 13 : 14);
                  final double gapSmall = compact ? 4 : 6;
                  final double gapMedium = compact ? 6 : 8;
                  final double buttonH = compact ? 34 : 36;
                  final double iconSize = compact ? 20 : 22;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // IMAGE
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              widget.pet['imageUrl'] ?? '',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Color(0xFFEFEFEF)),
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return const _ImageSkeleton();
                              },
                            ),
                            // nút tim nổi góc phải
                            Positioned(
                              right: 8,
                              top: 8,
                              child: _CircleIconButton(
                                size: buttonH,
                                iconSize: iconSize,
                                icon: isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                foreground:
                                    isFavorite ? Colors.red : Colors.black87,
                                background: Colors.white,
                                onTap: () => _toggleFav(isFavorite),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: gapSmall),

                      // NAME
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          (widget.pet['name'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: nameSize,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF0A0A0B).withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFF000000)
                                          .withOpacity(0.06)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '\$',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _priceText(widget.pet['weight']),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: priceSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _addToCart,
                            icon: Icon(
                              Icons.shopping_cart_outlined,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
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
  }

  // Helpers
  String _priceText(dynamic raw) {
    if (raw == null) return '--';
    final n = double.tryParse(raw.toString());
    if (n == null) return raw.toString();
    return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  }

  void _toggleFav(bool isFavorite) {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bạn cần đăng nhập trước.")),
      );
      return;
    }
    if (!isFavorite) {
      context.read<FavBloc>().add(AddToFav(email, {
            'productId': widget.pet['id'],
            'name': widget.pet['name'],
            'imageUrl': widget.pet['imageUrl'],
            'price': widget.pet['weight'],
          }));
    } else {
      context.read<FavBloc>().add(RemoveFromFav(email, widget.pet['id']));
    }
  }

  void _addToCart() {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bạn cần đăng nhập trước.")),
      );
      return;
    }
    context.read<CartBloc>().add(AddToCart(email, {
          'productId': widget.pet['id'],
          'name': widget.pet['name'],
          'imageUrl': widget.pet['imageUrl'],
          'price': widget.pet['weight'],
        }));
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
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)
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

/// Floating circular icon button (favorite)
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _CircleIconButton({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.size = 36,
    this.iconSize = 20,
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
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: foreground),
        ),
      ),
    );
  }
}

/// Primary full-width button “Thêm vào giỏ”
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final BlocWidgetListener<CartState> listenCart;
  final double height;
  final double iconSize;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.listenCart,
    this.height = 36,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartBloc, CartState>(
      listener: listenCart,
      child: SizedBox(
        height: height,
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          icon: Icon(icon, size: iconSize),
          label: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
