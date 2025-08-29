import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/view/mobile/StoreInfoScreen.dart';

import '../../bloc/favBloc/fav_bloc.dart';
import '../../bloc/favBloc/fav_event.dart';
import '../../bloc/favBloc/fav_state.dart';
import '../../widgets/pet_items_all.dart';

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
        petItems = extractPets(breedSnap)..addAll(extractPets(categorySnap));
      });
    } catch (e) {
      // chỉ log
      // print("Lỗi khi lọc thú cưng: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Tính số cột responsive cho “Sản phẩm tương tự”
  int _cols(double width) {
    if (width < 420) return 2;
    if (width < 720) return 3;
    if (width < 1024) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.grocery;
    final imageUrl = (data["imageUrl"] ?? "").toString();
    final name = (data["name"] ?? "").toString();
    final breed = (data["breed"] ?? "").toString();
    final sex = (data["sex"] ?? "").toString();
    final age = (data["age"] ?? "").toString();
    final weight = (data["weight"] ?? "").toString();
    final about = (data["about"] ?? "No description.").toString();

    return BlocBuilder<FavBloc, FavState>(builder: (context, state) {
      bool isFavorite = false;
      if (state is FavLoaded) {
        isFavorite = state.items.any((item) => item['productId'] == data['id']);
      }

      return Scaffold(
        backgroundColor: secondaryColor,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: NetworkImage(imageUrl),
                        ),
                      ),
                      child: Container(
                        // gradient để chữ/nút nổi bật
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black38],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Back
                  Positioned(
                    top: 40,
                    left: 12,
                    child: _CircleButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  // Favorite
                  Positioned(
                    top: 40,
                    right: 12,
                    child: _CircleButton(
                      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                      iconColor: isFavorite ? Colors.red : Colors.black87,
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
                                'productId': data['id'],
                                'name': data['name'],
                                'imageUrl': data['imageUrl'],
                                'price': data['weight'],
                              },
                            ),
                          );
                        } else {
                          context
                              .read<FavBloc>()
                              .add(RemoveFromFav(userEmail, data['id']));
                        }
                      },
                    ),
                  ),
                  // Tên & breed đè lên ảnh (dưới)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          breed,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            shadows: [Shadow(blurRadius: 3, color: Colors.black26)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ----------------- Tên, giá -----------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "\$ $weight",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ----------------- Info chips responsive -----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _InfoChip(
                      iconAsset: 'assets/images/calendar.png',
                      label: "Age",
                      value: "$age Years",
                    ),
                    _InfoChip(
                      iconAsset: 'assets/images/bone.png',
                      label: "Breed",
                      value: breed,
                    ),
                    _InfoChip(
                      iconAsset: 'assets/images/sex.png',
                      label: "Gender",
                      value: sex,
                    ),
                    _InfoChip(
                      iconAsset: 'assets/images/weight.png',
                      label: "Weight",
                      value: "$weight Kg",
                    ),
                  ],
                ),
              ),

              // ----------------- About -----------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  "About $name",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedCrossFade(
                      crossFadeState: isExpand
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                      firstChild: Text(
                        about,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                      secondChild: Text(
                        about,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => isExpand = !isExpand),
                      child: const Text(
                        "Xem thêm",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ----------------- Store card -----------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => StoreInfoScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: NetworkImage(
                                "https://i.pinimg.com/736x/8b/16/7a/8b167af653c2399dd93b952a48740620.jpg",
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Happy Pet",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Pet Owner",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.send),
                      ],
                    ),
                  ),
                ),
              ),

              // ----------------- Similar products -----------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Text(
                  "Sản phẩm tương tự",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black.withOpacity(0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = _cols(constraints.maxWidth);
                  if (_isLoading) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(

                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: cols * 2,
                        itemBuilder: (_, __) => _SkeletonCard(),
                      ),
                    );
                  }

                  if (petItems.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Không có sản phẩm tương tự",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: petItems.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.60,
                      ),
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
                          child: PetItemsAll(pet: petItems[index]),
                        );
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),

        // ----------------- CTA dưới cùng -----------------
        bottomNavigationBar: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Material(
              color: primaryColor,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã gửi yêu cầu liên hệ')),
                  );
                },
                child: const Center(
                  child: Text(
                    "LIÊN HỆ",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ================= Widgets phụ (UI-only) =================

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: iconColor ?? Colors.black87),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String value;

  const _InfoChip({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white;
    final border = Colors.black12;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(iconAsset, width: 22, height: 22, fit: BoxFit.contain),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                      TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black12.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
