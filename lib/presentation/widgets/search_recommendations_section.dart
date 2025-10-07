import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/core/services/search_recommendations_cache.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_bloc.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_event.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_state.dart';
import 'package:pet_shop/presentation/bloc/search/search_bloc.dart';
import 'package:pet_shop/presentation/bloc/search/search_event.dart';

class SearchRecommendationsSection extends StatefulWidget {
  final String userId;
  
  const SearchRecommendationsSection({
    super.key,
    required this.userId,
  });

  @override
  State<SearchRecommendationsSection> createState() => _SearchRecommendationsSectionState();
}

class _SearchRecommendationsSectionState extends State<SearchRecommendationsSection> {
  List<RecommendationItem>? _cachedRecommendations;
  bool _isLoadingFromCache = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    // Bước 1: Kiểm tra cache trước
    final cachedRecommendations = await SearchRecommendationsCache.getRecommendations(widget.userId);
    
    if (cachedRecommendations != null && mounted) {
      setState(() {
        _cachedRecommendations = cachedRecommendations;
        _isLoadingFromCache = false;
      });
      print('📦 Using cached recommendations (${cachedRecommendations.length} items)');
      return;
    }

    // Bước 2: Nếu không có cache, load từ server
    setState(() => _isLoadingFromCache = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RecommendationBloc>().add(
          LoadSearchRecommendations(userId: widget.userId, limit: 15),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Nếu đang load từ cache, hiển thị loading đơn giản
    if (_isLoadingFromCache) {
      return Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Đang tải gợi ý...'),
          ],
        ),
      );
    }

    // Nếu có cache, hiển thị ngay lập tức
    if (_cachedRecommendations != null) {
      return _buildRecommendationsList(_cachedRecommendations!);
    }

    // Nếu không có cache, sử dụng BlocBuilder để load từ server
    return BlocConsumer<RecommendationBloc, RecommendationState>(
      listener: (context, state) {
        // Lưu vào cache khi load thành công từ server
        if (state is RecommendationLoaded) {
          SearchRecommendationsCache.saveRecommendations(
            userId: widget.userId,
            recommendations: state.recommendations,
          );
        }
      },
      builder: (context, state) {
        if (state is RecommendationLoading) {
          return Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Đang tải gợi ý...'),
              ],
            ),
          );
        }

        if (state is RecommendationLoaded && state.recommendations.isNotEmpty) {
          return _buildRecommendationsList(state.recommendations);
        }

        return const SizedBox.shrink();
      },
    );
  }

  /// Build recommendations list từ cache hoặc server
  Widget _buildRecommendationsList(List<RecommendationItem> recommendations) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.recommend, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Có thể bạn quan tâm',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                if (_cachedRecommendations != null) // Hiển thị icon cache
                  Icon(
                    Icons.offline_bolt,
                    color: Colors.green,
                    size: 16,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Hiển thị recommendations được group theo type
          ..._buildRecommendationGroupsFromList(recommendations),
        ],
      ),
    );
  }

  /// Build groups từ list recommendations đơn giản
  List<Widget> _buildRecommendationGroupsFromList(List<RecommendationItem> recommendations) {
    final widgets = <Widget>[];
    
    // Group theo type
    final Map<RecommendationType, List<RecommendationItem>> groupedRecommendations = {};
    for (final item in recommendations) {
      if (!groupedRecommendations.containsKey(item.type)) {
        groupedRecommendations[item.type] = [];
      }
      groupedRecommendations[item.type]!.add(item);
    }
    
    // Nhóm theo type và hiển thị
    final typeLabels = {
      RecommendationType.contentBased: 'Phù hợp với sở thích',
      RecommendationType.trending: 'Đang thịnh hành',
      RecommendationType.collaborative: 'Người khác cũng thích',
      RecommendationType.association: 'Thường mua cùng nhau',
      RecommendationType.personalized: 'Dành riêng cho bạn',
      RecommendationType.hybrid: 'Đề xuất thông minh',
    };

    final typeColors = {
      RecommendationType.contentBased: Colors.blue,
      RecommendationType.trending: Colors.orange,
      RecommendationType.collaborative: Colors.purple,
      RecommendationType.association: Colors.green,
      RecommendationType.personalized: Colors.red,
      RecommendationType.hybrid: Colors.indigo,
    };

    for (final entry in groupedRecommendations.entries) {
      if (entry.value.isNotEmpty) {
        final type = entry.key;
        final items = entry.value.take(3).toList(); // Limit to 3 items per type
        
        widgets.add(_buildRecommendationGroup(
          context,
          typeLabels[type] ?? 'Gợi ý',
          typeColors[type] ?? Colors.grey,
          items,
        ));
      }
    }

    return widgets;
  }

  Widget _buildRecommendationGroup(
    BuildContext context,
    String title,
    Color color,
    List<RecommendationItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            decoration: BoxDecoration(
              border: index < items.length - 1
                  ? Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2)))
                  : null,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.pets, color: color, size: 20);
                    },
                  ),
                ),
              ),
              title: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.breed,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(item.score * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Icon(
                Icons.north_west,
                color: Colors.grey[400],
                size: 16,
              ),
              onTap: () {
                // Trigger search for this pet's breed
                context.read<SearchBloc>().add(SearchSubmitted(
                  item.breed,
                  isSuggestionTap: true,
                ));
              },
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
      ],
    );
  }
}