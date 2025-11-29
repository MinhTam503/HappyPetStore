import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/domain/entities/social_post.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/services/user_manager.dart';

class ExploreGrid extends StatefulWidget {
  final Function(SocialPost post) onPostTap;

  const ExploreGrid({
    Key? key,
    required this.onPostTap,
  }) : super(key: key);

  @override
  State<ExploreGrid> createState() => _ExploreGridState();
}

class _ExploreGridState extends State<ExploreGrid> with AutomaticKeepAliveClientMixin {
  List<String> _blockedUserIds = [];
  bool _isLoadingBlockedList = true;

  @override
  bool get wantKeepAlive => false; // Don't keep state when tab changes

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload blocked users when screen becomes visible again
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final userId = await UserManager().getUserIdForOperations();
    
    if (userId == null) {
      setState(() {
        _isLoadingBlockedList = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(userId)
          .get();

      if (doc.exists && mounted) {
        final List<dynamic> blocked = doc.data()?['blocked'] ?? [];
        final List<dynamic> blockedBy = doc.data()?['blockedBy'] ?? [];
        
        setState(() {
          _blockedUserIds = [...blocked.cast<String>(), ...blockedBy.cast<String>()];
          _isLoadingBlockedList = false;
        });
      } else {
        setState(() => _isLoadingBlockedList = false);
      }
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      setState(() => _isLoadingBlockedList = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    return BlocBuilder<SocialBloc, SocialState>(
      builder: (context, state) {
        if (state is SocialLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SocialError) {
          return _buildErrorState(context, state.message);
        }

        if (state is SocialLoaded) {
          if (state.exploreFeed.isEmpty) {
            return _buildEmptyState(context);
          }

          // Filter out posts from blocked users (check both petId and authorId)
          final filteredFeed = _isLoadingBlockedList 
              ? state.exploreFeed 
              : state.exploreFeed.where((post) => 
                  !_blockedUserIds.contains(post.authorId) && 
                  !_blockedUserIds.contains(post.petId)
                ).toList();

          if (filteredFeed.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _loadBlockedUsers();
              context.read<SocialBloc>().add(const LoadExploreFeed(refresh: true));
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: filteredFeed.length,
              itemBuilder: (context, index) {
                final post = filteredFeed[index];
                return _buildGridItem(context, post);
              },
            ),
          );
        }

        return _buildEmptyState(context);
      },
    );
  }

  Widget _buildGridItem(BuildContext context, SocialPost post) {
    return GestureDetector(
      onTap: () => widget.onPostTap(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          post.imageUrls.isNotEmpty
              ? Image.network(
                  post.imageUrls.first,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.pets, size: 40),
                ),

          // Stats overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Like count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, color: Colors.white, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${post.likeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Comment count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.comment, color: Colors.white, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${post.commentCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Multi-image indicator
          if (post.imageUrls.length > 1)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.collections, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      '${post.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            l10n?.oopsSomethingWrong ?? 'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<SocialBloc>().add(const LoadExploreFeed());
            },
            icon: const Icon(Icons.refresh),
            label: Text(l10n?.tryAgain ?? 'Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 80,
              color: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.explore ?? 'Explore',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover amazing pet posts',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            ),
          ],
        ),
      ),
    );
  }
}
