import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/core/services/search_recommendations_cache.dart';
import 'package:pet_shop/core/services/search_recommendations_manager.dart';
import 'package:pet_shop/presentation/bloc/search/search_bloc.dart';
import 'package:pet_shop/presentation/bloc/search/search_event.dart';
// Removed RecommendationConfig here because search is cache-only and doesn't trigger loads

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
  bool _isRefreshing = false;
  bool _refreshAttempted = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    // Cache-only: Try cache-first (reuse home recommendations); do NOT trigger refresh or fallback
    setState(() {
      _isLoadingFromCache = true;
    });
    final cachedRecommendations = await SearchRecommendationsCache.getRecommendations(widget.userId);

    if (cachedRecommendations != null && mounted) {
      setState(() {
        _cachedRecommendations = cachedRecommendations;
        _isLoadingFromCache = false;
      });
  debugPrint('📦 Using cached home recommendations (${cachedRecommendations.length} items) for search');
      return;
    }

    // No cache available → trigger one-time background refresh, then try again
    if (!_refreshAttempted) {
      _refreshAttempted = true;
      setState(() {
        _isRefreshing = true;
        _isLoadingFromCache = false;
      });

      try {
  debugPrint('🌐 No cache for search; triggering manual refresh...');
        await SearchRecommendationsManager().refreshNow();
        final fetched = await SearchRecommendationsCache.getRecommendations(widget.userId);
        if (mounted) {
          setState(() {
            _cachedRecommendations = fetched;
            _isRefreshing = false;
          });
          if (fetched != null) {
            debugPrint('✅ Search recommendations fetched (${fetched.length}) after refresh');
          } else {
            debugPrint('ℹ️ Still no recommendations after refresh (possibly no data or user not logged in)');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
        }
        debugPrint('❌ Error refreshing search recommendations: $e');
      }
      return;
    }

    // After a failed refresh attempt, show nothing
    if (mounted) {
      setState(() {
        _isLoadingFromCache = false;
      });
    }
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
              color: Colors.grey.withValues(alpha: 0.1),
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

    // Nếu đang refresh sau khi không có cache, hiển thị loading nhỏ gọn
    if (_isRefreshing) {
      return Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
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
            Text('Đang làm mới gợi ý...'),
          ],
        ),
      );
    }

    // Nếu không có cache, ẩn section (không trigger load mới)
    return const SizedBox.shrink();
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
            color: Colors.grey.withValues(alpha: 0.1),
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
                // Icon(Icons.recommend, color: primaryColor, size: 20),
                // const SizedBox(width: 8),
                const Text(
                  'Có thể bạn quan tâm',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                // if (_cachedRecommendations != null) 
                //   Icon(
                //     Icons.offline_bolt,
                //     color: Colors.green,
                //     size: 16,
                //   ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Hiển thị recommendations được group theo type với nhiều item hơn
          ..._buildRecommendationGroupsFromList(recommendations),
        ],
      ),
    );
  }

  /// Build groups từ list recommendations giữ nguyên UI cũ nhưng hiển thị nhiều item hơn
  List<Widget> _buildRecommendationGroupsFromList(List<RecommendationItem> recommendations) {
    final widgets = <Widget>[];

    // Group theo type
    final Map<RecommendationType, List<RecommendationItem>> groupedRecommendations = {};
    for (final item in recommendations) {
      groupedRecommendations.putIfAbsent(item.type, () => []);
      groupedRecommendations[item.type]!.add(item);
    }

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
        final items = entry.value; // Không giới hạn 3 nữa, hiển thị hết để "nhiều gợi ý"

        widgets.add(_buildRecommendationGroup(
          context,
          typeColors[type] ?? Colors.grey,
          items,
        ));
      }
    }

    return widgets;
  }

  Widget _buildRecommendationGroup(
    BuildContext context,
    Color color,
    List<RecommendationItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            decoration: BoxDecoration(
              border: index < items.length - 1
                  ? Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))
                  : null,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
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
                ],
              ),
              trailing: Icon(
                Icons.north_west,
                color: Colors.grey[400],
                size: 16,
              ),
              onTap: () {
                // Giữ behavior cũ: tap sẽ search theo breed
                context.read<SearchBloc>().add(SearchSubmitted(
                  item.breed,
                  isSuggestionTap: true,
                ));
              },
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}