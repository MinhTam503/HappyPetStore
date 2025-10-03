import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';
import 'package:pet_shop/presentation/widgets/popular_pet_items.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_bloc.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_state.dart';

class PopularTab extends StatelessWidget {
  const PopularTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<PopularBloc, PopularState>(
      builder: (context, state) {
        if (state is PopularLoading || state is PopularInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is PopularError) {
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

        if (state is PopularLoaded) {
          final pets = state.pets;
          
          if (pets.isEmpty) {
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
                    l10n?.noResults ?? 'Chưa có dữ liệu',
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
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: pets.length,
              itemBuilder: (context, index) {
                final pet = pets[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailPet(pet: pet),
                      ),
                    );
                  },
                  child: PopularPetItems(pet: pet),
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