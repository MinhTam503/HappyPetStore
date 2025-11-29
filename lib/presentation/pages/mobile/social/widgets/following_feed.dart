import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';
import 'package:pet_shop/presentation/widgets/social/post_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowingFeed extends StatefulWidget {
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
  State<FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<FollowingFeed> with AutomaticKeepAliveClientMixin {
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
    if (widget.currentUserId == null) {
      setState(() => _isLoadingBlockedList = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(widget.currentUserId)
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
          if (state.feed.isEmpty) {
            return _buildEmptyState(context);
          }

          // Filter out posts from blocked users (check both petId and authorId)
          final filteredFeed = _isLoadingBlockedList 
              ? state.feed 
              : state.feed.where((post) => 
                  !_blockedUserIds.contains(post.authorId) && 
                  !_blockedUserIds.contains(post.petId)
                ).toList();

          if (filteredFeed.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _loadBlockedUsers();
              context.read<SocialBloc>().add(const LoadFeed(refresh: true));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredFeed.length,
              itemBuilder: (context, index) {
                final post = filteredFeed[index];
                final isLiked = widget.currentUserId != null && post.isLikedBy(widget.currentUserId!);
                final isOwnPost = widget.currentUserId != null && post.authorId == widget.currentUserId;

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
                  onComment: () => widget.onCommentTap(post.id),
                  onProfileTap: () => widget.onProfileTap(post.petId),
                  onDelete: isOwnPost
                      ? () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(AppLocalizations.of(context)!.deletePost),
                              content: Text(AppLocalizations.of(context)!.deletePostConfirm),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(AppLocalizations.of(context)!.cancel),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    context.read<SocialBloc>().add(DeletePost(post.id));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(AppLocalizations.of(context)!.postDeleted)),
                                    );
                                  },
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: Text(AppLocalizations.of(context)!.deletePost),
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                  onEdit: isOwnPost
                      ? () {
                          Navigator.pushNamed(
                            context,
                            '/social/edit-post',
                            arguments: post,
                          );
                        }
                      : null,
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
    final l10n = AppLocalizations.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            l10n!.oopsSomethingWrong,
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
              context.read<SocialBloc>().add(const LoadFeed());
            },
            icon: const Icon(Icons.refresh),
            label: Text(l10n.tryAgain),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ],
        ),
      ),
    );
  }
}
