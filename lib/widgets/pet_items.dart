import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/bloc/cartBloc/cart_event.dart';
import 'package:pet_shop/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/utils/responsive_utils.dart';

import '../bloc/cartBloc/cart_state.dart';

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
    return BlocBuilder<FavBloc, FavState>(builder: (context, state) {
      bool isFavorite = false;
      if (state is FavLoaded) {
        isFavorite =
            state.items.any((item) => item['productId'] == widget.pet['id']);
      }

      Widget card = AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: (isWeb && _hover) ? 1.02 : 1.0,
        child: Material(
          color: Colors.white,
          elevation: (isWeb && _hover) ? 5 : 2,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(
                      widget.pet['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: Colors.black12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    widget.pet['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("\$ ",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("${widget.pet['weight']}",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _OutlinedIconButton(
                        isActive: isFavorite,
                        activeColor: Colors.red,
                        icon:
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                        onTap: () {
                          final userEmail =
                              FirebaseAuth.instance.currentUser?.email;
                          if (userEmail == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Something is wrong")),
                            );
                            return;
                          }
                          if (!isFavorite) {
                            context.read<FavBloc>().add(AddToFav(userEmail, {
                                  'productId': widget.pet['id'],
                                  'name': widget.pet['name'],
                                  'imageUrl': widget.pet['imageUrl'],
                                  'price': widget.pet['weight'],
                                }));
                          } else {
                            context.read<FavBloc>().add(
                                RemoveFromFav(userEmail, widget.pet['id']));
                          }
                        },
                      ),
                      _FilledIconButton(
                        icon: Icons.shopping_cart,
                        onTap: () {
                          final userEmail =
                              FirebaseAuth.instance.currentUser?.email;
                          if (userEmail == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Something is wrong")),
                            );
                            return;
                          }
                          context.read<CartBloc>().add(AddToCart(userEmail, {
                                'productId': widget.pet['id'],
                                'name': widget.pet['name'],
                                'imageUrl': widget.pet['imageUrl'],
                                'price': widget.pet['weight'],
                              }));
                        },
                        listener: (ctx, state) {
                          if (state is CartLoaded && state.message != null) {
                            if (lastCartMessage != state.message) {
                              ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(state.message!)),
                              );
                              lastCartMessage = state.message;
                            }
                          } else if (state is CartError) {
                            ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Lỗi: ${state.message}')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (isWeb) {
        card = MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: card,
        );
      }
      return card;
    });
  }
}

class _OutlinedIconButton extends StatelessWidget {
  final bool isActive;
  final Color activeColor;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlinedIconButton({
    required this.isActive,
    required this.activeColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: primaryColor),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, size: 24, color: isActive ? activeColor : null),
      ),
    );
  }
}

class _FilledIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final BlocWidgetListener<CartState> listener;

  const _FilledIconButton({
    required this.icon,
    required this.onTap,
    required this.listener,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 40,
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(18),
          topLeft: Radius.circular(18),
        ),
      ),
      child: BlocListener<CartBloc, CartState>(
        listener: listener,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: 24, color: Colors.white),
        ),
      ),
    );
  }
}
