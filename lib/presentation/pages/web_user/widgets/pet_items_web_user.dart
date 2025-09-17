import 'package:flutter/material.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_event.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_state.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:provider/provider.dart';
import 'package:pet_shop/core/services/user_manager.dart';

class PetItemsWebUser extends StatefulWidget {
  final Map<String, dynamic> pet;

  const PetItemsWebUser({super.key, required this.pet});

  @override
  State<PetItemsWebUser> createState() => _PetItemsState();
}

class _PetItemsState extends State<PetItemsWebUser> {
  String? lastCartMessage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavBloc, FavState>(builder: (context, state) {
      bool isFavorite = false;

      if (state is FavLoaded) {
        isFavorite =
            state.items.any((item) => item['productId'] == widget.pet['id']);
      }

      return Container(
        width: 150,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
              colors: [Colors.white, Color(0xffF7FFF7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 0,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25)),
                child: Image.network(
                  widget.pet['imageUrl'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Colors.black12),
                ),
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              widget.pet['name'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "\$ ",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1),
                ),
                Text(
                  CurrencyHelper.formatVND(widget.pet['price']),
                  style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: 45,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: primaryColor,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(23),
                        topRight: Radius.circular(22),
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () async {
                        UserManager userManager = UserManager();
                        String? userIdentifier = await userManager.getUserIdentifier();
                        if (userIdentifier == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please login to continue")),
                          );
                          return;
                        }
                        if (!isFavorite) {
                          context.read<FavBloc>().add(
                                AddToFav(
                                  userIdentifier,
                                  {
                                    'productId': widget.pet['id'],
                                    'name': widget.pet['name'],
                                    'imageUrl': widget.pet['imageUrl'],
                                    'price': widget.pet['price'],
                                  },
                                ),
                              );
                        } else {
                          context.read<FavBloc>().add(RemoveFromFav(
                                userIdentifier,
                                widget.pet['id'],
                              ));
                        }
                      },
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 27,
                        color: isFavorite ? Colors.red : null,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                      width: 45,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(20),
                            topLeft: Radius.circular(25)),
                      ),
                      child: BlocListener<CartBloc, CartState>(
                        listener: (context, state) {
                          if (state is CartLoaded && state.message != null) {
                            if (lastCartMessage != state.message) {
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(state.message!)),
                              );
                              lastCartMessage = state.message;
                            }
                          } else if (state is CartError) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi: ${state.message}')),
                            );
                          }
                        },
                        child: GestureDetector(
                          onTap: () async {
                            UserManager userManager = UserManager();
                            String? userIdentifier = await userManager.getUserIdentifier();
                            if (userIdentifier == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Please login to continue")),
                              );
                              return;
                            }
                            context.read<CartBloc>().add(
                                  AddToCart(
                                    userIdentifier,
                                    {
                                      'productId': widget.pet['id'],
                                      'name': widget.pet['name'],
                                      'imageUrl': widget.pet['imageUrl'],
                                      'price': widget.pet['price'],
                                    },
                                  ),
                                );
                          },
                          child: const Icon(
                            Icons.shopping_cart,
                            size: 27,
                            color: Colors.white,
                          ),
                        ),
                      )),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
