import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/data/models/viewed_pet_model.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_bloc.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_event.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_state.dart';
import 'package:pet_shop/presentation/pages/mobile/chat/chat_page.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_event.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_state.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/services/settings_service.dart';
import 'package:pet_shop/presentation/widgets/common/history_disabled_message.dart';

class ViewedPage extends StatefulWidget {
  const ViewedPage({super.key});

  @override
  State<ViewedPage> createState() => _ViewedPageState();
}

class _ViewedPageState extends State<ViewedPage> {
  final userManager = UserManager();
  final SettingsService _settingsService = SettingsService();
  bool _viewedPetsHistoryEnabled = true;

  @override
  void initState() {
    super.initState();
    context.read<RecentPetsBloc>().add(LoadRecentPets());
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final viewedPetsHistoryEnabled = await _settingsService.getViewedPetsHistoryEnabled();
      if (mounted) {
        setState(() {
          _viewedPetsHistoryEnabled = viewedPetsHistoryEnabled;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        centerTitle: true,
        title: Text(
          l10n?.recentlyViewed ?? 'Đã xem gần đây',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black),
            onPressed: () {
              context.read<RecentPetsBloc>().add(ClearRecentPets());
            },
          ),
        ],
      ),
      body: !_viewedPetsHistoryEnabled
          ? HistoryDisabledMessage(
              messageKey: 'viewedPetsHistoryDisabledMessage',
              icon: Icons.pets_outlined,
              iconColor: Colors.purple,
            )
          : BlocBuilder<RecentPetsBloc, RecentPetsState>(
              builder: (context, state) {
                if (state is RecentPetsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is RecentPetsError) {
                  return Center(child: Text('Lỗi: ${state.message}'));
                }

                if (state is RecentPetsEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          l10n?.noRecentlyViewed ?? 'Chưa có thú cưng nào được xem',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (state is RecentPetsLoaded) {
                  // Filter out unavailable pets
                  final availablePets = state.items.where((pet) {
                    final isAvailable = pet.isAvailable ?? true;
                    final status = pet.status?.toLowerCase() ?? '';
                    return isAvailable && status != 'sold';
                  }).toList();

                  if (availablePets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            l10n?.noRecentlyViewed ?? 'Chưa có thú cưng nào được xem',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: availablePets.length,
                    itemBuilder: (context, index) {
                      final pet = availablePets[index];
                      return _buildPetCard(pet);
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
    );
  }

  Widget _buildPetCard(ViewedPetModel pet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Navigate to pet details
        },
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  pet.imageUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      pet.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (pet.breed != null)
                      Text(
                        pet.breed!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    Text(
                      CurrencyHelper.formatVND(pet.price ?? 0),
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Xem lúc: ${_formatDate(pet.viewedAt)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFavoriteButton(pet),
                  IconButton(
                    icon:
                        const Icon(Icons.message_outlined, color: primaryColor),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            selectedPet: {
                              'id': pet.id,
                              'name': pet.name,
                              'imageUrl': pet.imageUrl,
                              'breed': pet.breed,
                              'price': pet.price,
                              'category': pet.category,
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(ViewedPetModel pet) {
    return BlocBuilder<FavBloc, FavState>(
      builder: (context, favState) {
        bool isFavorite = false;
        if (favState is FavLoaded) {
          isFavorite = favState.items.any((it) => it['productId'] == pet.id);
        }
        return IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.grey,
          ),
          onPressed: () async {
            final userIdentifier = await userManager.getUserIdForOperations();
            if (userIdentifier != null) {
              if (!isFavorite) {
                context.read<FavBloc>().add(AddToFav(userIdentifier, {
                      'productId': pet.id,
                      'name': pet.name,
                      'imageUrl': pet.imageUrl,
                      'price': pet.price,
                    }));
              } else {
                context
                    .read<FavBloc>()
                    .add(RemoveFromFav(userIdentifier, pet.id));
              }
            }
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
