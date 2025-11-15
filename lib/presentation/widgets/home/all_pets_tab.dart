import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';
import 'package:pet_shop/presentation/widgets/pet_items_all.dart';

class AllPetsTab extends StatefulWidget {
  const AllPetsTab({super.key});

  @override
  State<AllPetsTab> createState() => _AllPetsTabState();
}

class _AllPetsTabState extends State<AllPetsTab> {
  List<Map<String, dynamic>> allPets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllPets();
  }

  Future<void> _loadAllPets() async {
    try {
      setState(() => isLoading = true);
      
      final snapshot = await FirebaseFirestore.instance
          .collection('Pets')
          .get();
      
      if (mounted) {
        setState(() {
          allPets = snapshot.docs.map((doc) {
            final data = doc.data();
            // ensure id field exists for downstream detail fetch
            data['id'] = doc.id;
            return data;
          }).where((pet) {
            // Only show available pets (not sold)
            final isAvailable = pet['isAvailable'] ?? true;
            final status = pet['status']?.toString().toLowerCase() ?? '';
            return isAvailable && status != 'sold';
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      print('Error loading all pets: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (allPets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noResults ?? 'Không có thú cưng nào',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.78,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: allPets.length,
        itemBuilder: (context, index) {
          final pet = allPets[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailPet(pet: pet),
                ),
              );
            },
            child: PetItemsAll(pet: pet),
          );
        },
      ),
    );
  }
}