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
import 'package:pet_shop/presentation/pages/mobile/social/social_settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/presentation/widgets/social/comment_widget.dart';

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
  bool _isChatBlocked = false; // cached block status for chat button
  
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
      // Check if blocked before loading profile
      await _checkIfBlocked();
      await _updateChatBlockStatus();
      // Load profile after getting current user ID
      _loadProfile();
    }
  }

  Future<void> _updateChatBlockStatus() async {
    if (_currentUserId == null || _currentUserId == widget.userId) {
      setState(() => _isChatBlocked = false);
      return;
    }
    final isBlocked = await _checkIfUserBlocked(_currentUserId!, widget.userId);
    if (mounted) {
      setState(() => _isChatBlocked = isBlocked);
    }
  }

  Future<void> _checkIfBlocked() async {
    if (_currentUserId == null || _currentUserId == widget.userId) return;

    try {
      // Check if current user blocked target user
      final currentUserBlockDoc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(_currentUserId)
          .get();
      
      if (currentUserBlockDoc.exists) {
        final List<dynamic> blocked = currentUserBlockDoc.data()?['blocked'] ?? [];
        if (blocked.contains(widget.userId)) {
          // Already blocked, go back
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.userBlocked),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // Check if target user blocked current user
      final targetUserBlockDoc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(widget.userId)
          .get();
      
      if (targetUserBlockDoc.exists) {
        final List<dynamic> blockedBy = targetUserBlockDoc.data()?['blockedBy'] ?? [];
        if (blockedBy.contains(_currentUserId)) {
          // Blocked by target user, go back
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.cannotAccessProfile),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking block status: $e');
    }
  }

  Future<bool> _checkIfUserBlocked(String currentUserId, String targetUserId) async {
    try {
      // Check if current user blocked target user
      final currentUserBlockDoc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(currentUserId)
          .get();
      
      if (currentUserBlockDoc.exists) {
        final List<dynamic> blocked = currentUserBlockDoc.data()?['blocked'] ?? [];
        if (blocked.contains(targetUserId)) {
          return true;
        }
      }

      // Check if target user blocked current user
      final targetUserBlockDoc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(targetUserId)
          .get();
      
      if (targetUserBlockDoc.exists) {
        final List<dynamic> blockedBy = targetUserBlockDoc.data()?['blockedBy'] ?? [];
        if (blockedBy.contains(currentUserId)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking if user blocked: $e');
      return false;
    }
  }

  Future<List<String>> _getBlockedUserIds() async {
    if (_currentUserId == null) return [];
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(_currentUserId)
          .get();
      
      if (doc.exists) {
        final List<dynamic> blocked = doc.data()?['blocked'] ?? [];
        final List<dynamic> blockedBy = doc.data()?['blockedBy'] ?? [];
        return [...blocked.cast<String>(), ...blockedBy.cast<String>()];
      }
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
    }
    
    return [];
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
                  Text(l10n.userNotFound),
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
                    // Settings Button
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SocialSettingsPage(),
                              ),
                            );
                          },
                        ),
                  if (!_isOwnProfile)
                    // More options menu (Block user, Report, etc.)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'block') {
                          _showBlockUserDialog(context, profile);
                        } else if (value == 'report') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.comingSoon)),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              const Icon(Icons.block, color: Colors.red),
                              const SizedBox(width: 12),
                              Text(l10n.blockUser),
                            ],
                          ),
                        ),
                        // PopupMenuItem(
                        //   value: 'report',
                        //   child: Row(
                        //     children: [
                        //       const Icon(Icons.flag, color: Colors.orange),
                        //       const SizedBox(width: 12),
                        //       Text(l10n.reportUser),
                        //     ],
                        //   ),
                        // ),
                      ],
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
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
    return FutureBuilder<List<String>>(
      future: _getBlockedUserIds(),
      builder: (context, snapshot) {
        final blockedUserIds = snapshot.data ?? [];
        
        // Calculate filtered counts - always show numbers
        final followersCount = profile.followers
            .where((id) => !blockedUserIds.contains(id))
            .length;
        final followingCount = profile.following
            .where((id) => !blockedUserIds.contains(id))
            .length;

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
                  
                  // Stats - Always show numbers
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          profile.stats.posts.toString(),
                          l10n.posts(profile.stats.posts),
                        ),
                        _buildStatColumn(
                          followersCount.toString(),
                          l10n.userFollowers,
                        ),
                        _buildStatColumn(
                          followingCount.toString(),
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
                      backgroundColor: isFollowing ? Theme.of(context).colorScheme.surfaceVariant : theme.primaryColor,
                      foregroundColor: isFollowing ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: Text(isFollowing ? l10n.unfollow : l10n.follow),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentUserId == null || _isChatBlocked ? null : () async {
                      final participants = [_currentUserId!, widget.userId]..sort();
                      final conversationId = participants.join('_');
                      context.read<ChatBloc>().add(CreateConversation(
                        currentUserId: _currentUserId!,
                        otherUserId: widget.userId,
                        otherUserName: profile.displayName ?? 'User',
                        otherUserAvatar: profile.avatarUrl,
                      ));
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
      },
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
        final isOwnPost = _currentUserId != null && post.authorId == _currentUserId;
        
        return GestureDetector(
          onTap: () {
            final l10n = AppLocalizations.of(context)!;
            
            PostDetailSheet.show(
              context,
              post: post,
              currentUserId: _currentUserId,
              onCommentTap: (postId) {
                _showCommentsSheet(context, postId);
              },
              onDelete: isOwnPost
                  ? () {
                      Navigator.pop(context); // Close detail sheet
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(l10n.deletePost),
                          content: Text(l10n.deletePostConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                context.read<SocialBloc>().add(DeletePost(post.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.postDeleted)),
                                );
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: Text(l10n.deletePost),
                            ),
                          ],
                        ),
                      );
                    }
                  : null,
              onEdit: isOwnPost
                  ? () {
                      Navigator.pop(context); // Close detail sheet
                      Navigator.pushNamed(
                        context,
                        '/social/edit-post',
                        arguments: post,
                      );
                    }
                  : null,
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
    // Check permission first
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _getBlockedUserIds(),
        SocialPrivacyHelper.canViewFollowers(widget.userId, _currentUserId),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final blockedUserIds = (snapshot.data?[0] as List<String>?) ?? [];
        final canView = (snapshot.data?[1] as bool?) ?? true;

        // If user can't view, show privacy message
        if (!canView) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.followersPrivate,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.onlyOwnerCanView,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Filter out blocked users
        final filteredFollowers = profile.followers
            .where((id) => !blockedUserIds.contains(id))
            .toList();

        if (filteredFollowers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.noFollowers,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredFollowers.length,
          itemBuilder: (context, index) {
            final followerId = filteredFollowers[index];
        
            return BlocBuilder<SocialBloc, SocialState>(
              builder: (context, state) {
            if (state is! SocialLoaded) {
              return const ListTile(
                leading: CircleAvatar(child: Icon(Icons.person)),
                title: Text('Loading...'),
              );
            }
            
            // Try to get profile from cache
            final followerProfile = state.profileCache[followerId];
            if (followerProfile == null) {
              // Load profile if not in cache
              context.read<SocialBloc>().add(LoadUserProfile(followerId));
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(AppLocalizations.of(context)!.loading),
              );
            }

            // Check following status for this user if not in cache
            if (!state.followingStatus.containsKey(followerId) && _currentUserId != null && followerId != _currentUserId) {
              context.read<SocialBloc>().add(CheckIsFollowing(followerId));
            }

            final isFollowing = state.followingStatus[followerId] ?? false;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: followerProfile.avatarUrl.isNotEmpty
                    ? NetworkImage(followerProfile.avatarUrl)
                    : null,
                child: followerProfile.avatarUrl.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(followerProfile.displayName ?? followerProfile.petName),
              subtitle: followerProfile.bio.isNotEmpty ? Text(followerProfile.bio) : null,
              trailing: (_isOwnProfile || followerId == _currentUserId)
                  ? null
                  : OutlinedButton(
                      onPressed: () {
                        if (isFollowing) {
                          context.read<SocialBloc>().add(UnfollowPet(followerId));
                        } else {
                          context.read<SocialBloc>().add(FollowPet(followerId));
                        }
                      },
                      child: Text(
                        isFollowing
                            ? AppLocalizations.of(context)!.following
                            : AppLocalizations.of(context)!.follow,
                      ),
                    ),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/social/profile',
                  arguments: followerId,
                );
              },
            );
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildFollowingList(BuildContext context, SocialPetProfile profile) {
    // Check permission first
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _getBlockedUserIds(),
        SocialPrivacyHelper.canViewFollowing(widget.userId, _currentUserId),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final blockedUserIds = (snapshot.data?[0] as List<String>?) ?? [];
        final canView = (snapshot.data?[1] as bool?) ?? true;

        // If user can't view, show privacy message
        if (!canView) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.followingPrivate,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.onlyOwnerCanView,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Filter out blocked users
        final filteredFollowing = profile.following
            .where((id) => !blockedUserIds.contains(id))
            .toList();

        if (filteredFollowing.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.noFollowing,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredFollowing.length,
          itemBuilder: (context, index) {
            final followingId = filteredFollowing[index];
        
        return BlocBuilder<SocialBloc, SocialState>(
          builder: (context, state) {
            if (state is! SocialLoaded) {
              return const ListTile(
                leading: CircleAvatar(child: Icon(Icons.person)),
                title: Text('Loading...'),
              );
            }
            
            // Try to get profile from cache
            final followingProfile = state.profileCache[followingId];
            if (followingProfile == null) {
              // Load profile if not in cache
              context.read<SocialBloc>().add(LoadUserProfile(followingId));
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(AppLocalizations.of(context)!.loading),
              );
            }

            // Check following status for this user if not in cache
            if (!state.followingStatus.containsKey(followingId) && _currentUserId != null && followingId != _currentUserId) {
              context.read<SocialBloc>().add(CheckIsFollowing(followingId));
            }

            final isFollowing = state.followingStatus[followingId] ?? false;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: followingProfile.avatarUrl.isNotEmpty
                    ? NetworkImage(followingProfile.avatarUrl)
                    : null,
                child: followingProfile.avatarUrl.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(followingProfile.displayName ?? followingProfile.petName),
              subtitle: followingProfile.bio.isNotEmpty ? Text(followingProfile.bio) : null,
              trailing: (_isOwnProfile || followingId == _currentUserId)
                  ? null
                  : OutlinedButton(
                      onPressed: () {
                        if (isFollowing) {
                          context.read<SocialBloc>().add(UnfollowPet(followingId));
                        } else {
                          context.read<SocialBloc>().add(FollowPet(followingId));
                        }
                      },
                      child: Text(
                        isFollowing
                            ? AppLocalizations.of(context)!.following
                            : AppLocalizations.of(context)!.follow,
                      ),
                    ),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/social/profile',
                  arguments: followingId,
                );
              },
            );
              },
            );
          },
        );
      },
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
                            side: BorderSide(color: Theme.of(context).dividerColor),
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
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

  void _showBlockUserDialog(BuildContext context, SocialPetProfile profile) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUserId = await UserManager().getUserIdForOperations();
    
    if (currentUserId == null) return;

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.block, size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.blockUser,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.blockUserConfirmation(profile.displayName ?? profile.petName),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
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
                      _blockUser(currentUserId, profile);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.block,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
  }

  Future<void> _blockUser(String currentUserId, SocialPetProfile profile) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Add to blocked list (current user blocks target)
      await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(currentUserId)
          .set({
        'blocked': FieldValue.arrayUnion([widget.userId]),
        'blockedAt_${widget.userId}': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also add reverse block (target user blocked by current user)
      await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(widget.userId)
          .set({
        'blockedBy': FieldValue.arrayUnion([currentUserId]),
        'blockedByAt_$currentUserId': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Unfollow both directions if following
      final currentUserFollowDoc = await FirebaseFirestore.instance
          .collection('socialFollows')
          .doc(currentUserId)
          .get();
      
      if (currentUserFollowDoc.exists) {
        await FirebaseFirestore.instance
            .collection('socialFollows')
            .doc(currentUserId)
            .update({
          'following': FieldValue.arrayRemove([widget.userId]),
        });
      }

      final targetUserFollowDoc = await FirebaseFirestore.instance
          .collection('socialFollows')
          .doc(widget.userId)
          .get();
      
      if (targetUserFollowDoc.exists) {
        await FirebaseFirestore.instance
            .collection('socialFollows')
            .doc(widget.userId)
            .update({
          'followers': FieldValue.arrayRemove([currentUserId]),
          'following': FieldValue.arrayRemove([currentUserId]),
        });
      }

      final currentUserFollowDoc2 = await FirebaseFirestore.instance
          .collection('socialFollows')
          .doc(currentUserId)
          .get();
      
      if (currentUserFollowDoc2.exists) {
        await FirebaseFirestore.instance
            .collection('socialFollows')
            .doc(currentUserId)
            .update({
          'followers': FieldValue.arrayRemove([widget.userId]),
        });
      }

      // Also update socialPetProfiles collection
      await FirebaseFirestore.instance
          .collection('socialPetProfiles')
          .doc(currentUserId)
          .update({
        'following': FieldValue.arrayRemove([widget.userId]),
        'followers': FieldValue.arrayRemove([widget.userId]),
      });

      await FirebaseFirestore.instance
          .collection('socialPetProfiles')
          .doc(widget.userId)
          .update({
        'followers': FieldValue.arrayRemove([currentUserId]),
        'following': FieldValue.arrayRemove([currentUserId]),
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Refresh feed and explore to remove blocked user's posts
        context.read<SocialBloc>().add(const LoadFeed(refresh: true));
        context.read<SocialBloc>().add(const LoadExploreFeed(refresh: true));
        
        Navigator.pop(context); // Go back to previous page
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.userBlocked),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error blocking user: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorBlockingUser),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCommentsSheet(BuildContext context, String postId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);
    
    // Load post to get author ID
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('socialPosts')
          .doc(postId)
          .get();

      if (!postDoc.exists) {
        if (context.mounted) {
          NotificationHelper.showError(
            context,
            l10n?.error ?? 'Lỗi',
            'Bài viết không tìm thấy',
          );
        }
        return;
      }

      final postAuthorId = postDoc.data()?['authorId'] as String?;
      if (postAuthorId == null) return;

      // Check if comments are allowed
      final commentsAllowed = await SocialPrivacyHelper.areCommentsAllowed(postAuthorId);
      if (!commentsAllowed) {
        if (context.mounted) {
          NotificationHelper.showError(
            context,
            l10n?.error ?? 'Lỗi',
            'Bình luận đã bị tắt cho bài viết này',
          );
        }
        return;
      }
    } catch (e) {
      if (context.mounted) {
        NotificationHelper.showError(
          context,
          l10n?.error ?? 'Lỗi',
          'Lỗi kiểm tra quyền: $e',
        );
      }
      return;
    }

    String? replyingToUser;
    String? replyingToCommentId;

    // Load comments when opening sheet
    if (context.mounted) {
      context.read<SocialBloc>().add(LoadComments(postId));
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(width: 48),
                                Text(
                                  l10n!.commentCount,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(sheetContext),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Comments list
                      Expanded(
                        child: BlocBuilder<SocialBloc, SocialState>(
                          builder: (context, state) {
                            if (state is SocialLoaded) {
                              if (state.currentComments.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.comment_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        l10n.noCommentsYet,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.beFirstToComment,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final topLevelComments = state.currentComments
                                  .where((c) => c.parentId == null)
                                  .toList();

                              return ListView.builder(
                                controller: scrollController,
                                itemCount: topLevelComments.length,
                                padding: const EdgeInsets.only(top: 8),
                                itemBuilder: (context, index) {
                                  final comment = topLevelComments[index];

                                  return CommentWidget(
                                    comment: comment,
                                    currentUserId: currentUser?.uid,
                                    onLike: () {
                                      context.read<SocialBloc>().add(
                                            LikeComment(postId, comment.id),
                                          );
                                    },
                                    onReply: () {
                                      setState(() {
                                        replyingToUser = comment.userName;
                                        replyingToCommentId = comment.id;
                                      });
                                    },
                                    onDelete: () async {
                                      final shouldDelete =
                                          await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(l10n.deleteComment),
                                          content: Text(
                                              l10n.deleteCommentConfirm),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: Text(l10n.cancel),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: Text(l10n.delete),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (shouldDelete == true &&
                                          context.mounted) {
                                        context.read<SocialBloc>().add(
                                              DeleteComment(
                                                  postId, comment.id),
                                            );
                                      }
                                    },
                                  );
                                },
                              );
                            }

                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        ),
                      ),

                      // Comment input
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (replyingToUser != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                color: Colors.grey[100],
                                child: Row(
                                  children: [
                                    Text(
                                      l10n.replyingTo('@$replyingToUser'),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          replyingToUser = null;
                                          replyingToCommentId = null;
                                        });
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(),
                                      decoration: InputDecoration(
                                        hintText: l10n.addComment,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                      onSubmitted: (text) {
                                        if (text.trim().isNotEmpty) {
                                          context.read<SocialBloc>().add(
                                                AddComment(
                                                  postId,
                                                  text.trim(),
                                                  parentId:
                                                      replyingToCommentId,
                                                ),
                                              );
                                          setState(() {
                                            replyingToUser = null;
                                            replyingToCommentId = null;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
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
