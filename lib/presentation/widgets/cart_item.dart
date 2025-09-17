import 'package:flutter/material.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_bloc.dart';
import 'package:pet_shop/presentation/bloc/cartBloc/cart_event.dart';
import 'package:pet_shop/core/services/user_manager.dart';

import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:provider/provider.dart';

import '../bloc/model/cart_model.dart';

class CartItem extends StatelessWidget {
  final CartModel cart;

  const CartItem({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13, left: 10, right: 10),
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
                                CurrencyHelper.formatVND(cart.grocery['price']),
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
                onTap: () async {
                  UserManager userManager = UserManager();
                  String? userIdentifier = await userManager.getUserIdentifier();
                  if (userIdentifier == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please login to continue")),
                    );
                    return;
                  }
                  context.read<CartBloc>().add(
                      RemoveFromCart(userIdentifier, cart.grocery['productId']));
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
