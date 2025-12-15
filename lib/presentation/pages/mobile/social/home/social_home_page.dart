import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';
import 'package:pet_shop/presentation/pages/mobile/social/widgets/following_feed.dart';
import 'package:pet_shop/presentation/pages/mobile/social/widgets/explore_grid.dart';
import 'package:pet_shop/presentation/pages/mobile/social/widgets/post_detail_sheet.dart';
import 'package:pet_shop/presentation/widgets/social/comment_widget.dart';
import 'package:pet_shop/presentation/pages/mobile/social/social_settings_page.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';

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
  String? _userAvatar;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    _currentUserId = await UserManager().getUserIdForOperations();

    // Ensure user profile exists (auto-sync from Users collection)
    if (_currentUserId != null) {
      context.read<SocialBloc>().add(EnsureUserProfile(_currentUserId!));

      // Load user avatar (locked check is in StreamBuilder)
      try {
        final profileDoc = await FirebaseFirestore.instance
            .collection('socialPetProfiles')
            .doc(_currentUserId)
            .get();

        if (profileDoc.exists && mounted) {
          final data = profileDoc.data();
          setState(() {
            _userAvatar = data?['avatarUrl'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Error loading user profile: $e');
      }
    }

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

    // Real-time check for account lock status
    if (_currentUserId == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('socialPetProfiles')
          .doc(_currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        // Check if account is locked
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final isLocked = data?['isLocked'] == true;
          
          if (isLocked) {
            // Show locked screen
            return _buildLockedAccountScreen(context, l10n);
          }
        }

        return _buildMainScaffold(context, l10n, theme, isDark);
      },
    );
  }

  Widget _buildLockedAccountScreen(BuildContext context, AppLocalizations? l10n) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.socialNetwork ?? 'Mạng xã hội'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 100, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                l10n?.accountLocked ?? 'Tài khoản bị khóa',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Tài khoản đã bị khóa vui lòng liên hệ quản trị viên để biết thêm thông tin!',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bạn không thể sử dụng tính năng mạng xã hội khi tài khoản bị khóa.',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to home (BottomNavigator index 0)
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const BottomNavigator(initialIndex: 0),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Thoát'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainScaffold(BuildContext context, AppLocalizations? l10n, ThemeData theme, bool isDark) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          l10n?.socialNetwork ?? 'Pet Social Network',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.pushNamed(context, '/social/search');
            },
            tooltip: l10n?.search ?? 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.pushNamed(context, '/social/chat');
            },
            tooltip: l10n?.messages ?? 'Messages',
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            onPressed: () {
              if (_currentUserId != null) {
                Navigator.pushNamed(
                  context,
                  '/social/profile',
                  arguments: _currentUserId,
                );
              }
            },
            tooltip: l10n?.myProfile ?? 'My Profile',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          labelColor: theme.colorScheme.primary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          unselectedLabelColor:
              theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
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
          return Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Following Tab with Fake TextField
                    Column(
                      children: [
                        // Fake TextField for creating post (Facebook style)
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: theme.scaffoldBackgroundColor,
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                  context, '/social/create-post');
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: theme.colorScheme.primary,
                                    backgroundImage: _userAvatar != null &&
                                            _userAvatar!.isNotEmpty
                                        ? NetworkImage(_userAvatar!)
                                        : null,
                                    child: _userAvatar == null ||
                                            _userAvatar!.isEmpty
                                        ? const Icon(Icons.person,
                                            size: 20, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l10n?.whatsOnYourMind ??
                                          'Bạn đang nghĩ gì?',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey[600],
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: FollowingFeed(
                            currentUserId: _currentUserId,
                            onCommentTap: (postId) =>
                                _showCommentsSheet(context, postId),
                            onProfileTap: (petId) => Navigator.pushNamed(
                              context,
                              '/social/profile',
                              arguments: petId,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Explore Tab without TextField
                    ExploreGrid(
                      onPostTap: (post) {
                        final isOwnPost = _currentUserId != null &&
                            post.authorId == _currentUserId;
                        return PostDetailSheet.show(
                          context,
                          post: post,
                          currentUserId: _currentUserId,
                          onCommentTap: (postId) =>
                              _showCommentsSheet(context, postId),
                          onDelete: isOwnPost
                              ? () {
                                  Navigator.pop(context); // Close detail sheet
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: Text(AppLocalizations.of(context)!
                                          .deletePost),
                                      content: Text(
                                          AppLocalizations.of(context)!
                                              .deletePostConfirm),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
                                          child: Text(
                                              AppLocalizations.of(context)!
                                                  .cancel),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(dialogContext);
                                            context
                                                .read<SocialBloc>()
                                                .add(DeletePost(post.id));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      AppLocalizations.of(
                                                              context)!
                                                          .postDeleted)),
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                              foregroundColor: Colors.red),
                                          child: Text(
                                              AppLocalizations.of(context)!
                                                  .deletePost),
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
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
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
    String? replyingToCommentId; // Store parent comment ID

    // Load comments when opening sheet
    if (context.mounted) {
      context.read<SocialBloc>().add(LoadComments(postId));
    }

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
                                  AppLocalizations.of(context)!.commentCount,
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
                                        AppLocalizations.of(context)!
                                            .noCommentsYet,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppLocalizations.of(context)!
                                            .beFirstToComment,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Filter to show only top-level comments (replies will be rendered inside CommentWidget)
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
                                        builder: (dialogContext) => AlertDialog(
                                          title: Text(
                                              AppLocalizations.of(context)!
                                                  .deleteComment),
                                          content: Text(
                                            AppLocalizations.of(context)!
                                                .deleteCommentConfirm,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                  dialogContext, false),
                                              child: Text(
                                                  AppLocalizations.of(context)!
                                                      .cancel),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                  dialogContext, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: Text(
                                                  AppLocalizations.of(context)!
                                                      .delete),
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

                      // Comment input with keyboard padding
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: FutureBuilder<DocumentSnapshot>(
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
                                  replyingToCommentId = null;
                                });
                              },
                              onSubmit: (text) {
                                if (text.isNotEmpty) {
                                  String commentText = text;
                                  if (replyingToUser != null) {
                                    commentText = '@$replyingToUser $text';
                                  }

                                  context.read<SocialBloc>().add(
                                        AddComment(
                                          postId,
                                          commentText,
                                          parentId:
                                              replyingToCommentId, // Pass parentId for replies
                                        ),
                                      );

                                  setState(() {
                                    replyingToUser = null;
                                    replyingToCommentId = null;
                                  });
                                }
                              },
                            );
                          },
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
