import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/bloc/cartBloc/cart_event.dart';

import 'package:pet_shop/utils/contants.dart';
import 'package:provider/provider.dart';

import '../bloc/model/cart_model.dart';
class CartItem extends StatelessWidget {
  final CartModel cart;

  const CartItem({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13,left: 10,right: 10),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 85,
                height: 85,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: NetworkImage(cart.grocery["imageUrl"]),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 30),
                    child: Text(
                      cart.grocery['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(left: 30),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Price: ",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black),
                              ),
                              Text(
                                cart.grocery['price'],
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor),
                              ),
                            ],
                          ),
                        ),

                      ],
                    ),
                  )
                ],
              )
            ],
          ),
          Positioned(
              right: 10,
              bottom: 40,
              child: GestureDetector(
                onTap: () {
                  String? userEmail = FirebaseAuth.instance.currentUser?.email;
                  if (userEmail == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Something is wrong")),
                    );
                    return;
                  }
                  context.read<CartBloc>().add(RemoveFromCart(userEmail, cart.grocery['productId']));
                },
                child: const Icon(
                  Icons.cancel_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ))
        ],
      ),
    );
  }
}
