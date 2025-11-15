import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';
import 'package:pet_shop/presentation/widgets/social/post_card.dart';

class FollowingFeed extends StatelessWidget {
  final String? currentUserId;
  final Function(String postId) onCommentTap;
  final Function(String petId) onProfileTap;

  const FollowingFeed({
    Key? key,
    required this.currentUserId,
    required this.onCommentTap,
    required this.onProfileTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SocialBloc, SocialState>(
      builder: (context, state) {
        if (state is SocialLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SocialError) {
          return _buildErrorState(context, state.message);
        }

        if (state is SocialLoaded) {
          if (state.feed.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<SocialBloc>().add(const LoadFeed(refresh: true));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.feed.length,
              itemBuilder: (context, index) {
                final post = state.feed[index];
                final isLiked = currentUserId != null && post.isLikedBy(currentUserId!);

                // Get profile info from profileCache
                String petName = 'User';
                String? petAvatar;
                
                // Try to find profile in cache
                if (state.profileCache.containsKey(post.petId)) {
                  final profile = state.profileCache[post.petId]!;
                  petName = profile.displayName ?? profile.petName;
                  petAvatar = profile.avatarUrl;
                } else {
                  // Load profile if not in cache
                  context.read<SocialBloc>().add(LoadUserProfile(post.petId));
                }

                return PostCard(
                  post: post,
                  petName: petName,
                  petAvatarUrl: petAvatar,
                  isLiked: isLiked,
                  onLike: () {
                    if (isLiked) {
                      context.read<SocialBloc>().add(UnlikePost(post.id));
                    } else {
                      context.read<SocialBloc>().add(LikePost(post.id));
                    }
                  },
                  onComment: () => onCommentTap(post.id),
                  onProfileTap: () => onProfileTap(post.petId),
                );
              },
            ),
          );
        }

        return _buildEmptyState(context);
      },
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<SocialBloc>().add(const LoadFeed());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
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
              Icons.people_outline,
              size: 80,
              color: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noPostsYet ?? 'No posts yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.startFollowing ?? 'Follow pets to see their posts here',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            ),
          ],
        ),
      ),
    );
  }
}
