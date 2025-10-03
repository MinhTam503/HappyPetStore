import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/widgets/pet_items_all.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_bloc.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_event.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_state.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';

class ForYouTab extends StatefulWidget {
  const ForYouTab({super.key});

  @override
  State<ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends State<ForYouTab> {
  UserManager userManager = UserManager();

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  void _loadRecommendations() async {
    final userIdentifier = await userManager.getUserIdentifier();
    if (userIdentifier != null) {
      context
          .read<RecommendationBloc>()
          .add(LoadRecommendations(userId: userIdentifier));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<RecommendationBloc, RecommendationState>(
      builder: (context, state) {
        if (state is RecommendationLoading || state is RecommendationInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is RecommendationError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (state is RecommendationLoaded) {
          final recommendations = state.recommendations;
          
          if (recommendations.isEmpty) {
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
                    l10n?.noResults ?? 'Chưa có gợi ý cho bạn',
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final recommendation = recommendations[index];
                // Convert RecommendationItem to pet format for existing widget
                final pet = {
                  'id': recommendation.petId,
                  'name': recommendation.name,
                  'category': recommendation.category,
                  'breed': recommendation.breed,
                  'price': recommendation.price,
                  'imageUrl': recommendation.imageUrl,
                };
                return GestureDetector(
                  onTap: () async {
                    try {
                      final petId = pet['id'] ?? pet['productId'];
                      Map<String, dynamic> fullData = Map<String, dynamic>.from(pet);
                      if (petId != null) {
                        final doc = await FirebaseFirestore.instance.collection('Pets').doc(petId as String).get();
                        if (doc.exists) {
                          fullData = doc.data() ?? fullData;
                          fullData['id'] = doc.id;
                        }
                      }
                      // ignore: use_build_context_synchronously
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailPet(pet: fullData),
                        ),
                      );
                    } catch (e) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailPet(pet: pet),
                        ),
                      );
                    }
                  },
                  child: PetItemsAll(pet: pet),
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}