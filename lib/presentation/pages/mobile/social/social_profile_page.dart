import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/domain/entities/social_pet_profile.dart';
import 'package:pet_shop/domain/entities/social_post.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';
import 'package:pet_shop/presentation/bloc/chat/chat_bloc.dart';
import 'package:pet_shop/presentation/bloc/chat/chat_event.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/pages/mobile/social/widgets/post_detail_sheet.dart';

class SocialProfilePage extends StatefulWidget {
  final String userId;
  
  const SocialProfilePage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<SocialProfilePage> createState() => _SocialProfilePageState();
}

class _SocialProfilePageState extends State<SocialProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
  }
  
  Future<void> _loadCurrentUser() async {
    final userManager = UserManager();
    await userManager.initialize();
    final userId = await userManager.getUserIdForOperations();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
      // Load profile after getting current user ID
      _loadProfile();
    }
  }
  
  void _loadProfile() {
    context.read<SocialBloc>().add(LoadUserProfile(widget.userId));
    context.read<SocialBloc>().add(LoadUserPosts(widget.userId));
    
    // Check following status if viewing another user's profile
    if (_currentUserId != null && _currentUserId != widget.userId) {
      context.read<SocialBloc>().add(CheckIsFollowing(widget.userId));
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  bool get _isOwnProfile => _currentUserId == widget.userId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Scaffold(
      body: BlocBuilder<SocialBloc, SocialState>(
        builder: (context, state) {
          if (state is SocialLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is SocialError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProfile,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }
          
          if (state is! SocialLoaded) {
            return const SizedBox.shrink();
          }
          
          final profile = state.profileCache[widget.userId];
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64),
                  const SizedBox(height: 16),
                  Text(l10n.noPetsFound),
                ],
              ),
            );
          }
          
          final posts = state.userPosts;
          final isFollowing = state.followingStatus[widget.userId] ?? false;
          
          return CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                title: Text(
                  profile.displayName ?? profile.petName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                actions: [
                  if (_isOwnProfile)
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        // TODO: Navigate to settings
                      },
                    ),
                ],
              ),
              
              // Profile Header
              SliverToBoxAdapter(
                child: _buildProfileHeader(context, profile, isFollowing, l10n, theme),
              ),
              
              // Tab Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: theme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: theme.primaryColor,
                    tabs: [
                      Tab(text: l10n.userPosts),
                      Tab(text: l10n.userFollowers),
                      Tab(text: l10n.userFollowing),
                    ],
                  ),
                ),
              ),
              
              // Tab Content
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsGrid(context, posts),
                    _buildFollowersList(context, profile),
                    _buildFollowingList(context, profile),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildProfileHeader(
    BuildContext context,
    SocialPetProfile profile,
    bool isFollowing,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar and Stats
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundImage: profile.avatarUrl.isNotEmpty
                    ? NetworkImage(profile.avatarUrl)
                    : null,
                child: profile.avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(width: 24),
              
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      profile.stats.posts.toString(),
                      l10n.posts(profile.stats.posts),
                    ),
                    _buildStatColumn(
                      profile.followers.length.toString(),
                      l10n.userFollowers,
                    ),
                    _buildStatColumn(
                      profile.following.length.toString(),
                      l10n.userFollowing,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Name and Bio
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName ?? profile.petName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(profile.bio),
                ],
                if (profile.website != null && profile.website!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.website!,
                    style: TextStyle(color: theme.primaryColor),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              if (_isOwnProfile) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/social/edit-profile',
                        arguments: profile,
                      );
                    },
                    child: Text(l10n.editProfile),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (isFollowing) {
                        _showUnfollowDialog(
                          context,
                          profile.displayName ?? 'User',
                          () {
                            context.read<SocialBloc>().add(UnfollowPet(widget.userId));
                          },
                        );
                      } else {
                        context.read<SocialBloc>().add(FollowPet(widget.userId));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey[300] : theme.primaryColor,
                      foregroundColor: isFollowing ? Colors.black : Colors.white,
                    ),
                    child: Text(isFollowing ? l10n.unfollow : l10n.follow),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentUserId == null ? null : () {
                      // Create conversation ID (consistent with repository)
                      final participants = [_currentUserId!, widget.userId]..sort();
                      final conversationId = participants.join('_');
                      
                      // Create conversation in Firestore
                      context.read<ChatBloc>().add(CreateConversation(
                        currentUserId: _currentUserId!,
                        otherUserId: widget.userId,
                        otherUserName: profile.displayName ?? 'User',
                        otherUserAvatar: profile.avatarUrl,
                      ));
                      
                      // Navigate to chat room
                      Navigator.pushNamed(
                        context,
                        '/social/chat/room',
                        arguments: {
                          'conversationId': conversationId,
                          'otherUserId': widget.userId,
                          'otherUserName': profile.displayName ?? 'User',
                          'otherUserAvatar': profile.avatarUrl,
                        },
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 20),
                    label: Text(l10n.message),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPostsGrid(BuildContext context, List<SocialPost> posts) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noPostsYet,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () {
            PostDetailSheet.show(
              context,
              post: post,
              currentUserId: _currentUserId,
              onCommentTap: (postId) {
                // Handle comment tap - navigate to comments
                // Can be implemented later
              },
            );
          },
          child: Image.network(
            post.imageUrls.first,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFollowersList(BuildContext context, SocialPetProfile profile) {
    return Center(
      child: Text(AppLocalizations.of(context)!.noFollowers),
    );
  }
  
  Widget _buildFollowingList(BuildContext context, SocialPetProfile profile) {
    return Center(
      child: Text(AppLocalizations.of(context)!.noFollowing),
    );
  }

  void _showUnfollowDialog(BuildContext context, String userName, VoidCallback onConfirm) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 10),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_remove_rounded,
                    color: Colors.orange.shade400,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  l10n.unfollow,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  'Bạn có chắc chắn muốn hủy theo dõi $userName?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 30),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          l10n.cancel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          l10n.unfollow,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Custom delegate for TabBar in SliverPersistentHeader
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
