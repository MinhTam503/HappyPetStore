// import 'package:flutter/material.dart';
// import 'package:pet_shop/provider/cart_provider.dart';
// import 'package:pet_shop/presentation/pages/cart_screen.dart';
// import 'package:provider/provider.dart';
//
// class CartIcon extends StatelessWidget {
//   const CartIcon({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     CartProvider cartProvider = Provider.of<CartProvider>(context);
//     return Stack(
//       clipBehavior: Clip.none,
//       children: [
//         const Padding(
//           padding: EdgeInsets.all(5),
//           child: Icon(
//             Icons.shopping_cart_outlined,
//             color: Colors.black,
//             size: 30,
//           ),
//         ),
//         cartProvider.carts.isNotEmpty
//             ? Positioned(
//                 right: -4,
//                 top: -10,
//                 child: GestureDetector(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => const CartScreen()),
//                     );
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(6),
//                     decoration: const BoxDecoration(
//                       color: Colors.red,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Text(
//                       cartProvider.carts.length.toString(),
//                       style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//               )
//             : Container(),
//       ],
//     );
//   }
// }
