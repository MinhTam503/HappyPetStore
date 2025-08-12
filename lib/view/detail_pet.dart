import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/view/StoreInfoScreen.dart';

import '../bloc/favBloc/fav_bloc.dart';
import '../bloc/favBloc/fav_event.dart';
import '../bloc/favBloc/fav_state.dart';
import '../widgets/pet_items_all.dart';

class DetailPet extends StatefulWidget {
  final Map<String, dynamic> grocery;

  const DetailPet({super.key, required this.grocery});

  @override
  State<DetailPet> createState() => _DetailPetState();
}

class _DetailPetState extends State<DetailPet> {
  bool isExpand = false;
  List<Map<String, dynamic>> petItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    similarPets();
  }

  Future<void> similarPets() async {
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // Hàm phụ xử lý snapshot
      List<Map<String, dynamic>> extractPets(QuerySnapshot snapshot) {
        return snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .where((pet) => pet['name'] != widget.grocery['name'])
            .toList();
      }

      final breedSnap = await firestore
          .collection("Pets")
          .where("breed", isEqualTo: widget.grocery['breed'])
          .get();

      final categorySnap = await firestore
          .collection("Pets")
          .where("category", isEqualTo: widget.grocery['category'])
          .where("breed", isNotEqualTo: widget.grocery['breed'])
          .get();

      if (!mounted) return;

      setState(() {
        petItems = extractPets(breedSnap)
          ..addAll(extractPets(categorySnap));
      });
    } catch (e) {
      print("Lỗi khi lọc thú cưng: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavBloc, FavState>(builder: (context, state) {
      bool isFavorite = false;

      if (state is FavLoaded) {
        isFavorite =
            state.items.any((item) =>
            item['productId'] == widget.grocery['id']);
      }

      return Scaffold(
        backgroundColor: secondaryColor,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //image
              Stack(
                children: [
                  Container(
                    height: 290,
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                        image: DecorationImage(
                            fit: BoxFit.cover,
                            image: NetworkImage(widget.grocery["imageUrl"]))),
                  ),
                  Positioned(
                    top: 25,
                    left: 5,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: Colors.grey.shade400),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              // Name
              Padding(
                padding: const EdgeInsets.only(
                  left: 10, right: 10, top: 10,),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.grocery["name"],
                            style: const TextStyle(
                                fontSize: 22,
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                        Text(widget.grocery["breed"],
                            style: const TextStyle(
                                fontSize: 18, color: Colors.black54)),
                      ],
                    ),
                    GestureDetector(
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
                                'productId': widget.grocery['id'],
                                'name': widget.grocery['name'],
                                'imageUrl': widget.grocery['imageUrl'],
                                'price': widget.grocery['weight'],
                              },
                            ),
                          );
                        } else {
                          context.read<FavBloc>().add(RemoveFromFav(
                            userEmail,
                            widget.grocery['id'],
                          ));
                        }
                      },
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 40,
                        color: isFavorite ? Colors.red : null,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10),
                child: Text("\$ " + widget.grocery["weight"],
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.black.withOpacity(0.6),
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10,),
              //Detail pet
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12)),
                      width: 190,
                      height: 55,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 8,
                          ),
                          Image.asset(
                            'assets/images/calendar.png',
                            width: 35,
                            height: 35,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Age"),
                              Text(
                                widget.grocery['age'] + " Years",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12)),
                      width: 190,
                      height: 55,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 8,
                          ),
                          Image.asset(
                            'assets/images/bone.png',
                            width: 35,
                            height: 35,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Breed"),
                              Text(
                                widget.grocery['breed'].length > 10
                                    ? '${widget.grocery['breed'].substring(0, 10)}...'
                                    : widget.grocery['breed'],
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),

                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              //Detail pet
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12)),
                      width: 190,
                      height: 55,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 8,
                          ),
                          Image.asset(
                            'assets/images/sex.png',
                            width: 35,
                            height: 35,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Gender"),
                              Text(
                                widget.grocery['sex'],
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12)),
                      width: 190,
                      height: 55,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 8,
                          ),
                          Image.asset(
                            'assets/images/weight.png',
                            width: 35,
                            height: 35,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Weight"),
                              Text(
                                widget.grocery['weight'] + " Kg",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              //About
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
                child: Text(
                  "About " + widget.grocery["name"],
                  style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      maxLines: isExpand ? null : 3,
                      overflow:
                      isExpand ? TextOverflow.visible : TextOverflow.ellipsis,
                      widget.grocery["about"],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    GestureDetector(
                        onTap: () {
                          setState(() {
                            isExpand = !isExpand;
                            print(isExpand);
                          });
                        },
                        child: Text(
                          isExpand ? "Thu gọn" : "Xem thêm",
                          style: const TextStyle(color: Colors.green),
                        ))
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  width: double.maxFinite,
                  height: 65,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: primaryColor, width: 2)),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => StoreInfoScreen()));
                    },
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                        ),
                        Container(
                          width: 45,
                          height: 45,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: NetworkImage(
                                  "https://i.pinimg.com/736x/8b/16/7a/8b167af653c2399dd93b952a48740620.jpg"),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 20,
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Happy Pet",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Pet Owner",
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                            width: 40,
                            height: 30,
                            child: Image.asset("assets/images/send.png")),
                        const SizedBox(
                          width: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  "Sản phẩm tương tự",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.black.withOpacity(0.7),
                      fontWeight: FontWeight.w500),
                ),
              ),
              petItems.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(10),
                child: Text("Không có sản phẩm tương tự",
                  style: TextStyle(fontWeight: FontWeight.w500),),
              )
                  : GridView.builder(
                itemCount: petItems.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.903,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DetailPet(grocery: petItems[index]),
                        ),
                      );
                    },
                    child: PetItemsAll(
                      pet: petItems[index],
                    ),
                  );
                },
              ),
              const SizedBox(
                height: 20,
              )
            ],
          ),
        ),
        bottomNavigationBar: Container(
          width: double.maxFinite,
          height: 50,
          color: primaryColor,
          child: const Center(
            child: Text(
              "LIÊN HỆ",
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    });
  }
}
