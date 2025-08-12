import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/bloc/cartBloc/cart_event.dart';
import 'package:pet_shop/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:provider/provider.dart';

import '../bloc/cartBloc/cart_state.dart';

class PetItemsAll extends StatefulWidget {
  final Map<String, dynamic> pet;

  const PetItemsAll({super.key, required this.pet});

  @override
  State<PetItemsAll> createState() => _PetItemsAllState();
}

class _PetItemsAllState extends State<PetItemsAll> {
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
        width: 120,
        height: 70,
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
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.maxFinite,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: NetworkImage(widget.pet['imageUrl']),
                ),
              ),
            ),
            const SizedBox(
              height: 2,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Text(
                    widget.pet['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Text(
                    "\$ ",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${widget.pet['weight']}",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "${widget.pet['breed']}",
                style:  TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 5,)
,            Row(
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
                      onTap: () {
                        String? userEmail =
                            FirebaseAuth.instance.currentUser?.email;
                        if (userEmail == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Something is wrong")),
                          );
                          return;
                        }
                        if (!isFavorite) {
                          context.read<FavBloc>().add(
                                AddToFav(
                                  userEmail,
                                  {
                                    'productId': widget.pet['id'],
                                    'name': widget.pet['name'],
                                    'imageUrl': widget.pet['imageUrl'],
                                    'price': widget.pet['weight'],
                                  },
                                ),
                              );
                        } else {
                          context.read<FavBloc>().add(RemoveFromFav(
                                userEmail,
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
                          onTap: () {
                            String? userEmail =
                                FirebaseAuth.instance.currentUser?.email;
                            if (userEmail == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Something is wrong")),
                              );
                              return;
                            }
                            context.read<CartBloc>().add(
                                  AddToCart(
                                    userEmail,
                                    {
                                      'productId': widget.pet['id'],
                                      'name': widget.pet['name'],
                                      'imageUrl': widget.pet['imageUrl'],
                                      'price': widget.pet['weight'],
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
