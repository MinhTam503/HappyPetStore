import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_bloc.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_event.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_state.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';

class RecommendationSection extends StatefulWidget {
  final String title;
  final RecommendationType? type;
  final int limit;
  final bool showViewAll;

  const RecommendationSection({
    super.key,
    required this.title,
    this.type,
    this.limit = 10,
    this.showViewAll = true,
  });

  @override
  State<RecommendationSection> createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<RecommendationSection> {
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  void _loadRecommendations() async {
    final userManager = UserManager();
    await userManager.initialize();
    userId = await userManager.getUserIdForOperations();

    if (userId != null && mounted) {
      if (widget.type != null) {
        context.read<RecommendationBloc>().add(
          LoadRecommendationsByType(
            userId: userId!,
            type: widget.type!,
            limit: widget.limit,
          ),
        );
      } else {
        context.read<RecommendationBloc>().add(
          LoadPersonalizedRecommendations(
            userId: userId!,
            limit: widget.limit,
          ),
        );
      }
    }
  }

  void _trackInteraction(String petId, InteractionType type) {
    if (userId != null) {
      context.read<RecommendationBloc>().add(
        TrackUserInteraction(
          userId: userId!,
          petId: petId,
          type: type,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecommendationBloc, RecommendationState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(),
            const SizedBox(height: 16),
            _buildContent(state),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.showViewAll)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecommendationListPage(
                      type: widget.type,
                      title: widget.title,
                    ),
                  ),
                );
              },
              child: const Text('Xem tất cả'),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(RecommendationState state) {
    if (state is RecommendationLoading) {
      return _buildLoadingShimmer();
    }

    if (state is RecommendationError) {
      return _buildErrorWidget(state.message);
    }

    if (state is RecommendationLoaded && state.recommendations.isNotEmpty) {
      return _buildRecommendationList(state.recommendations);
    }

    if (state is RecommendationEmpty) {
      return _buildEmptyWidget(state.message);
    }

    return _buildLoadingShimmer();
  }

  Widget _buildLoadingShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              child: Column(
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Container(
                          height: 16,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          color: Colors.grey[300],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadRecommendations,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationList(List<RecommendationItem> recommendations) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final item = recommendations[index];
          return _buildRecommendationCard(item);
        },
      ),
    );
  }

  Widget _buildRecommendationCard(RecommendationItem item) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () {
            _trackInteraction(item.petId, InteractionType.view);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPet(
                  pet: {
                    'id': item.petId,
                    'name': item.name,
                    'category': item.category,
                    'breed': item.breed,
                    'price': item.price,
                    'image': item.imageUrl,
                  },
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pet Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: Image.network(
                  item.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      color: Colors.grey[300],
                      child: const Icon(Icons.pets, size: 40),
                    );
                  },
                ),
              ),
              
              // Pet Info
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.breed,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyHelper.formatVND(item.price),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Recommendation reason
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(item.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTypeLabel(item.type),
                        style: TextStyle(
                          color: _getTypeColor(item.type),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.contentBased:
        return Colors.blue;
      case RecommendationType.collaborative:
        return Colors.purple;
      case RecommendationType.trending:
        return Colors.orange;
      case RecommendationType.association:
        return Colors.green;
      case RecommendationType.hybrid:
        return Colors.red;
      case RecommendationType.personalized:
        return Colors.teal;
    }
  }

  String _getTypeLabel(RecommendationType type) {
    switch (type) {
      case RecommendationType.contentBased:
        return 'Phù hợp';
      case RecommendationType.collaborative:
        return 'Phổ biến';
      case RecommendationType.trending:
        return 'Thịnh hành';
      case RecommendationType.association:
        return 'Liên quan';
      case RecommendationType.hybrid:
        return 'Đề xuất';
      case RecommendationType.personalized:
        return 'Cá nhân';
    }
  }
}

// Full-screen recommendation list page
class RecommendationListPage extends StatefulWidget {
  final RecommendationType? type;
  final String title;

  const RecommendationListPage({
    super.key,
    this.type,
    required this.title,
  });

  @override
  State<RecommendationListPage> createState() => _RecommendationListPageState();
}

class _RecommendationListPageState extends State<RecommendationListPage> {
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  void _loadRecommendations() async {
    final userManager = UserManager();
    await userManager.initialize();
    userId = await userManager.getUserIdForOperations();

    if (userId != null && mounted) {
      if (widget.type != null) {
        context.read<RecommendationBloc>().add(
          LoadRecommendationsByType(
            userId: userId!,
            type: widget.type!,
            limit: 50,
          ),
        );
      } else {
        context.read<RecommendationBloc>().add(
          LoadPersonalizedRecommendations(
            userId: userId!,
            limit: 50,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: BlocBuilder<RecommendationBloc, RecommendationState>(
        builder: (context, state) {
          if (state is RecommendationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is RecommendationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadRecommendations,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (state is RecommendationLoaded && state.recommendations.isNotEmpty) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: state.recommendations.length,
              itemBuilder: (context, index) {
                final item = state.recommendations[index];
                return _buildGridItem(item);
              },
            );
          }

          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets, color: Colors.grey, size: 48),
                SizedBox(height: 16),
                Text('Không có khuyến nghị nào'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridItem(RecommendationItem item) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (userId != null) {
            context.read<RecommendationBloc>().add(
              TrackUserInteraction(
                userId: userId!,
                petId: item.petId,
                type: InteractionType.view,
              ),
            );
          }
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailPet(
                pet: {
                  'id': item.petId,
                  'name': item.name,
                  'category': item.category,
                  'breed': item.breed,
                  'price': item.price,
                  'image': item.imageUrl,
                },
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: Image.network(
                  item.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.pets, size: 40),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.breed,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      CurrencyHelper.formatVND(item.price),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}