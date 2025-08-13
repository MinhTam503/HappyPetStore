import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/utils/contants.dart';

import '../detail_pet.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  late String? userEmail;

  @override
  void initState() {
    super.initState();
    userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail != null) {
      context.read<FavBloc>().add(LoadFav(userEmail!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: secondaryColor,
        title: const Text(
          "Favorite",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: BlocBuilder<FavBloc, FavState>(
        builder: (context, state) {
          if (state is FavLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is FavLoaded) {
            final favoriteItems = state.items;

            if (favoriteItems.isEmpty) {
              return const Center(
                child: Text(
                  "No Favorite yet",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              );
            }

            return ListView.builder(
              itemCount: favoriteItems.length,
              itemBuilder: (context, index) {
                final favorite = favoriteItems[index];
                final productId = favorite["productId"];

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection("Pets")
                      .doc(productId)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(
                        child: Text('Error loading favorites'),
                      );
                    }

                    final itemData =
                        snapshot.data!.data() as Map<String, dynamic>?;

                    if (itemData == null) {
                      return const Center(
                        child: Text('No data available for this favorite'),
                      );
                    }

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => DetailPet(
                                    grocery: itemData)));
                      },
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 8),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              width: double.maxFinite,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      image: DecorationImage(
                                        fit: BoxFit.cover,
                                        image: NetworkImage(itemData["imageUrl"]),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemData["name"],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        "\$ ${itemData["weight"]}",
                                        style: const TextStyle(
                                            fontSize: 18),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 50,
                            right: 35,
                            child: GestureDetector(
                              onTap: () {
                                if (userEmail != null) {
                                  context
                                      .read<FavBloc>()
                                      .add(RemoveFromFav(userEmail!, productId));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("Đã có lỗi sảy ra")));
                                }
                              },
                              child: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          } else if (state is FavError) {
            return Center(child: Text("Error: ${state.message}"));
          } else {
            return const Center(child: Text("Unknown state"));
          }
        },
      ),
    );
  }
}
