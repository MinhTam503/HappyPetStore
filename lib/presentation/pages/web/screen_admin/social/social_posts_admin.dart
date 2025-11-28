import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/domain/entities/social_post.dart';
import 'package:pet_shop/data/models/social_post_model.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class SocialPostsAdmin extends StatefulWidget {
  const SocialPostsAdmin({Key? key}) : super(key: key);

  @override
  State<SocialPostsAdmin> createState() => _SocialPostsAdminState();
}

class _SocialPostsAdminState extends State<SocialPostsAdmin> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'newest';
  String _filterStatus = 'all'; // all, hidden, visible

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<SocialPost>> _getPostsStream() {
    Query query = FirebaseFirestore.instance.collection('socialPosts');

    // Sort
    switch (_sortBy) {
      case 'newest':
        query = query.orderBy('timestamp', descending: true);
        break;
      case 'oldest':
        query = query.orderBy('timestamp', descending: false);
        break;
      case 'mostLikes':
        query = query.orderBy('likes', descending: true);
        break;
      case 'mostComments':
        query = query.orderBy('comments', descending: true);
        break;
    }

    return query.limit(100).snapshots().map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => SocialPostModel.fromFirestore(doc))
          .toList();

      // Filter by hidden status
      List<SocialPost> filteredPosts = posts;
      if (_filterStatus == 'hidden') {
        filteredPosts = posts.where((post) {
          // Check if post has isHidden field in Firestore
          final doc = snapshot.docs.firstWhere((d) => d.id == post.id);
          final data = doc.data() as Map<String, dynamic>?;
          return data != null && data['isHidden'] == true;
        }).toList();
      } else if (_filterStatus == 'visible') {
        filteredPosts = posts.where((post) {
          final doc = snapshot.docs.firstWhere((d) => d.id == post.id);
          final data = doc.data() as Map<String, dynamic>?;
          return data == null || data['isHidden'] != true;
        }).toList();
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        return filteredPosts.where((post) {
          final caption = post.caption.toLowerCase();
          final query = _searchQuery.toLowerCase();
          return caption.contains(query) || post.tags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
      }

      return filteredPosts;
    });
  }

  Future<void> _togglePostVisibility(String postId, bool currentlyHidden) async {
    try {
      await FirebaseFirestore.instance.collection('socialPosts').doc(postId).update({
        'isHidden': !currentlyHidden,
      });
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyHidden ? l10n.postShown : l10n.postHidden),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('socialPosts').doc(postId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.postDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showDeleteDialog(SocialPost post) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePost),
        content: Text(l10n.deletePostConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(post.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showPostDetails(SocialPost post) {
    showDialog(
      context: context,
      builder: (context) => _PostDetailsDialog(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.article_outlined, size: 32, color: primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      l10n.postManagement,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.searchPosts,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterStatus,
                        decoration: InputDecoration(
                          labelText: l10n.filterByPostStatus,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text(l10n.all)),
                          DropdownMenuItem(value: 'visible', child: Text(l10n.visiblePosts)),
                          DropdownMenuItem(value: 'hidden', child: Text(l10n.hiddenPosts)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _filterStatus = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: InputDecoration(
                          labelText: l10n.sortBy,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        items: [
                          DropdownMenuItem(value: 'newest', child: Text(l10n.newest)),
                          DropdownMenuItem(value: 'oldest', child: Text(l10n.oldest)),
                          DropdownMenuItem(value: 'mostLikes', child: Text(l10n.mostLikes)),
                          DropdownMenuItem(value: 'mostComments', child: Text(l10n.mostComments)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortBy = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Posts List
          Expanded(
            child: StreamBuilder<List<SocialPost>>(
              stream: _getPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noPostsFound,
                          style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: posts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          l10n.showingResults(posts.length.toString()),
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                      );
                    }

                    final post = posts[index - 1];
                    
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('socialPosts')
                          .doc(post.id)
                          .snapshots(),
                      builder: (context, docSnapshot) {
                        final isHidden = docSnapshot.hasData 
                            ? ((docSnapshot.data!.data() as Map<String, dynamic>?)?['isHidden'] == true)
                            : false;
                        
                        return _PostCard(
                          post: post,
                          isHidden: isHidden,
                          onView: () => _showPostDetails(post),
                          onDelete: () => _showDeleteDialog(post),
                          onToggleVisibility: () => _togglePostVisibility(post.id, isHidden),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final SocialPost post;
  final bool isHidden;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onToggleVisibility;

  const _PostCard({
    required this.post,
    required this.isHidden,
    required this.onView,
    required this.onDelete,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              if (post.imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.imageUrls.first,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.caption.isEmpty ? '(No caption)' : post.caption,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isHidden)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Text(
                              l10n.hidden,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (post.tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: post.tags.take(3).map((tag) {
                          return Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('${post.likeCount}', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(width: 16),
                        Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('${post.commentCount}', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(width: 16),
                        Icon(Icons.remove_red_eye, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('${post.viewCount}', style: TextStyle(color: Colors.grey[600])),
                        const Spacer(),
                        Text(
                          DateFormat('dd/MM/yyyy').format(post.timestamp),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: onView,
                    tooltip: l10n.viewPost,
                    color: primaryColor,
                  ),
                  IconButton(
                    icon: Icon(isHidden ? Icons.visibility : Icons.visibility_off),
                    onPressed: onToggleVisibility,
                    tooltip: isHidden ? l10n.showPost : l10n.hidePost,
                    color: isHidden ? Colors.green : Colors.orange,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    tooltip: l10n.deletePost,
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostDetailsDialog extends StatefulWidget {
  final SocialPost post;

  const _PostDetailsDialog({required this.post});

  @override
  State<_PostDetailsDialog> createState() => _PostDetailsDialogState();
}

class _PostDetailsDialogState extends State<_PostDetailsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteComment(String commentId, bool isReply) async {
    try {
      final postRef = FirebaseFirestore.instance
          .collection('socialPosts')
          .doc(widget.post.id);
      
      // Get current post data
      final doc = await postRef.get();
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>;
      final comments = List<Map<String, dynamic>>.from(
        (data['comments'] as List<dynamic>?)?.map((c) => c as Map<String, dynamic>) ?? []
      );
      
      if (isReply) {
        // Find parent comment and remove reply from its replies array
        for (var comment in comments) {
          final replies = List<Map<String, dynamic>>.from(
            (comment['replies'] as List<dynamic>?)?.map((r) => r as Map<String, dynamic>) ?? []
          );
          
          replies.removeWhere((r) => r['id'] == commentId);
          comment['replies'] = replies;
        }
      } else {
        // Remove top-level comment
        comments.removeWhere((c) => c['id'] == commentId);
      }
      
      // Update post with modified comments array
      await postRef.update({'comments': comments});
      
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commentDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: Container(
        width: 800,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Text(
                    l10n.postDetails,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // TabBar
            TabBar(
              controller: _tabController,
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: primaryColor,
              tabs: [
                Tab(icon: Icon(Icons.info_outline), text: l10n.postDetails),
                Tab(icon: Icon(Icons.comment_outlined), text: l10n.viewComments),
              ],
            ),
            
            // TabView Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Post Details Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildPostDetailsContent(context),
                  ),
                  // Comments Tab
                  _buildCommentsTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostDetailsContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images
        if (widget.post.imageUrls.isNotEmpty)
          SizedBox(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.post.imageUrls.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.post.imageUrls[index],
                      height: 300,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        
        // Caption
        Text(
          l10n.caption,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(widget.post.caption.isEmpty ? '(No caption)' : widget.post.caption),
        const SizedBox(height: 16),
        
        // Tags
        if (widget.post.tags.isNotEmpty) ...[
          Text(
            l10n.tags,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.post.tags.map((tag) {
              return Chip(label: Text(tag));
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        
        // Stats
        Row(
          children: [
            _StatItem(icon: Icons.favorite, label:l10n.like, value: widget.post.likeCount),
            const SizedBox(width: 24),
            _StatItem(icon: Icons.comment, label: l10n.comment, value: widget.post.commentCount),
          ],
        ),
        const SizedBox(height: 16),
        
        // Timestamp
        Text(
          '${l10n.createdDate}: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.post.timestamp)}',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCommentsTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Comments are stored in the post document as an array, not a subcollection
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('socialPosts')
          .doc(widget.post.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Text(
              l10n.noCommentsYet,
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final commentsData = data?['comments'] as List<dynamic>? ?? [];

        if (commentsData.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.comment_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  l10n.noCommentsYet,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Parse comments from array
        final comments = commentsData.map((c) => c as Map<String, dynamic>).toList();
        
        // Separate top-level comments and build replies map
        final topLevelComments = comments.where((c) => c['parentId'] == null).toList();
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: topLevelComments.length,
          itemBuilder: (context, index) {
            final comment = topLevelComments[index];
            final commentId = comment['id'] as String;
            
            // Get replies for this comment (from nested 'replies' array)
            final replies = comment['replies'] as List<dynamic>? ?? [];
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCommentCard(context, commentId, comment, false),
                // Show replies indented
                if (replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Column(
                      children: replies.map((reply) {
                        final replyData = reply as Map<String, dynamic>;
                        final replyId = replyData['id'] as String;
                        return _buildCommentCard(context, replyId, replyData, true);
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCommentCard(BuildContext context, String commentId, Map<String, dynamic> comment, bool isReply) {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12, top: isReply ? 8 : 0),
      color: isReply ? Colors.grey[50] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: comment['userAvatarUrl'] != null
              ? NetworkImage(comment['userAvatarUrl'])
              : null,
          child: comment['userAvatarUrl'] == null
              ? Text(comment['userName']?[0] ?? 'U')
              : null,
        ),
        title: Row(
          children: [
            Text(
              comment['userName'] ?? 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isReply) ...[
              const SizedBox(width: 8),
              Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Reply',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(comment['text'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(
                    (comment['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  ),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.favorite, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${(comment['likes'] as List?)?.length ?? 0}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.deleteComment),
                content: Text(l10n.deleteCommentConfirm),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteComment(commentId, isReply);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text(l10n.delete),
                  ),
                ],
              ),
            );
          },
          tooltip: l10n.deleteComment,
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: primaryColor),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}
