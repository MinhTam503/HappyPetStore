import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/domain/entities/social_post.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';
import 'package:pet_shop/presentation/widgets/social/post_card.dart';
import 'package:pet_shop/presentation/widgets/social/comment_widget.dart';

/// Social Home Page - Instagram-style feed
class SocialHomePage extends StatefulWidget {
  const SocialHomePage({Key? key}) : super(key: key);

  @override
  State<SocialHomePage> createState() => _SocialHomePageState();
}

class _SocialHomePageState extends State<SocialHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    _currentUserId = await UserManager().getUserIdForOperations();
    context.read<SocialBloc>().add(const LoadFeed());
    context.read<SocialBloc>().add(const LoadExploreFeed());
    context.read<SocialBloc>().add(const LoadTrendingTags());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          l10n?.socialNetwork ?? 'Pet Social Network',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: isDark ? darkPrimaryColor : primaryColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearchDialog(context),
            tooltip: l10n?.search ?? 'Search',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? darkPrimaryColor : primaryColor,
          indicatorWeight: 3,
          labelColor: isDark ? darkPrimaryColor : primaryColor,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 15,
          ),
          tabs: [
            Tab(text: l10n?.following ?? 'Following'),
            Tab(text: l10n?.explore ?? 'Explore'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/social/create-post');
        },
        backgroundColor: isDark ? darkPrimaryColor : primaryColor,
        child: const Icon(Icons.add, size: 28),
      ),
      body: BlocConsumer<SocialBloc, SocialState>(
        listener: (context, state) {
          if (state is SocialError) {
            NotificationHelper.showError(
              context,
              l10n?.error ?? 'Error',
              state.message,
            );
          } else if (state is SocialOperationSuccess) {
            NotificationHelper.showSuccess(
              context,
              l10n?.success ?? 'Success',
              state.message,
            );
          }
        },
        builder: (context, state) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildFollowingTab(context, state),
              _buildExploreTab(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFollowingTab(BuildContext context, SocialState state) {
    if (state is SocialLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state is SocialError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
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
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (state is SocialLoaded) {
      if (state.feed.isEmpty) {
        return _buildEmptyFeed(context, true);
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
            final isLiked = _currentUserId != null &&
                post.isLikedBy(_currentUserId!);

            return PostCard(
              post: post,
              petName: 'Pet Name', // TODO: Fetch from profile
              petAvatarUrl: null,
              isLiked: isLiked,
              onLike: () {
                if (isLiked) {
                  context.read<SocialBloc>().add(UnlikePost(post.id));
                } else {
                  context.read<SocialBloc>().add(LikePost(post.id));
                }
              },
              onComment: () {
                _showCommentsSheet(context, post.id);
              },
              onProfileTap: () {
                Navigator.pushNamed(
                  context,
                  '/social/profile',
                  arguments: post.petId,
                );
              },
            );
          },
        ),
      );
    }

    return _buildEmptyFeed(context, true);
  }

  Widget _buildExploreTab(BuildContext context, SocialState state) {
    if (state is SocialLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state is SocialError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
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
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<SocialBloc>().add(const LoadExploreFeed());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (state is SocialLoaded) {
      if (state.exploreFeed.isEmpty) {
        return _buildEmptyFeed(context, false);
      }

      return RefreshIndicator(
        onRefresh: () async {
          context.read<SocialBloc>().add(const LoadExploreFeed());
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: state.exploreFeed.length,
          itemBuilder: (context, index) {
            final post = state.exploreFeed[index];
            return GestureDetector(
              onTap: () {
                _showPostDetailSheet(context, post);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
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
                          child: const Icon(Icons.pets),
                        ),
                  // Overlay with stats
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${post.likeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
          },
        ),
      );
    }

    return _buildEmptyFeed(context, false);
  }

  Widget _buildEmptyFeed(BuildContext context, bool isFollowing) {
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
              isFollowing ? Icons.people_outline : Icons.explore_outlined,
              size: 80,
              color: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isFollowing
                  ? (l10n?.noPostsYet ?? 'No posts yet')
                  : (l10n?.explore ?? 'Explore'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFollowing
                  ? (l10n?.startFollowing ?? 'Follow pets to see their posts here')
                  : (l10n?.explore ?? 'Discover pet profiles'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            if (isFollowing) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _tabController.animateTo(1); // Switch to Explore tab
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? darkPrimaryColor : primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n?.explore ?? 'Explore',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String query = '';
        return AlertDialog(
          title: const Text('Search Pets'),
          content: TextField(
            onChanged: (value) => query = value,
            decoration: const InputDecoration(
              hintText: 'Enter pet name or breed',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (query.isNotEmpty) {
                  context.read<SocialBloc>().add(SearchPets(query));
                  Navigator.pop(context);
                  // Navigate to search results page
                }
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  void _showCommentsSheet(BuildContext context, String postId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    String? replyingToUser;

    // Load comments when opening sheet
    context.read<SocialBloc>().add(LoadComments(postId));

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
                                const Text(
                                  'Comments',
                                  style: TextStyle(
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
                                        AppLocalizations.of(context)!.noCommentsYet,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppLocalizations.of(context)!.beFirstToComment,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                controller: scrollController,
                                itemCount: state.currentComments.length,
                                padding: const EdgeInsets.only(top: 8),
                                itemBuilder: (context, index) {
                                  final comment = state.currentComments[index];

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
                                      });
                                    },
                                    onDelete: () async {
                                      final shouldDelete = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: Text(AppLocalizations.of(context)!.deleteComment),
                                          content: Text(
                                            AppLocalizations.of(context)!.deleteCommentConfirm,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext, false),
                                              child: Text(AppLocalizations.of(context)!.cancel),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: Text(AppLocalizations.of(context)!.delete),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (shouldDelete == true) {
                                        context.read<SocialBloc>().add(
                                              DeleteComment(postId, comment.id),
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
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('Users')
                            .doc(currentUser?.uid)
                            .get(),
                        builder: (context, snapshot) {
                          String? userAvatar;
                          String? userName;

                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>;
                            userAvatar = userData['avatar'] as String?;
                            userName = userData['name'] as String?;
                          }

                          return CommentInput(
                            currentUserAvatar: userAvatar,
                            currentUserName: userName,
                            replyingTo: replyingToUser,
                            onCancelReply: () {
                              setState(() {
                                replyingToUser = null;
                              });
                            },
                            onSubmit: (text) {
                              if (text.isNotEmpty) {
                                String commentText = text;
                                if (replyingToUser != null) {
                                  commentText = '@$replyingToUser $text';
                                }

                                context.read<SocialBloc>().add(
                                      AddComment(postId, commentText),
                                    );

                                setState(() {
                                  replyingToUser = null;
                                });
                              }
                            },
                          );
                        },
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

  void _showPostDetailSheet(BuildContext context, SocialPost post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLiked = currentUser != null && post.isLikedBy(currentUser.uid);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48),
                        const Text(
                          'Post',
                          style: TextStyle(
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
                  ),
                  const Divider(height: 1),

                  // Post content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        PostCard(
                          post: post,
                          petName: 'Pet Name',
                          petAvatarUrl: null,
                          isLiked: isLiked,
                          onLike: () {
                            if (isLiked) {
                              context.read<SocialBloc>().add(UnlikePost(post.id));
                            } else {
                              context.read<SocialBloc>().add(LikePost(post.id));
                            }
                            Navigator.pop(sheetContext);
                          },
                          onComment: () {
                            Navigator.pop(sheetContext);
                            _showCommentsSheet(context, post.id);
                          },
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
  }
}
