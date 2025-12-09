import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/domain/entities/social_post.dart';

/// Instagram-style post card widget
class PostCard extends StatelessWidget {
  final SocialPost post;
  final String? petName;
  final String? petAvatarUrl;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback? onComment;
  final VoidCallback? onProfileTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const PostCard({
    Key? key,
    required this.post,
    this.petName,
    this.petAvatarUrl,
    required this.isLiked,
    required this.onLike,
    this.onComment,
    this.onProfileTap,
    this.onDelete,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Profile info
          _buildHeader(context, theme, isDark),

          // Images carousel
          if (post.imageUrls.isNotEmpty) _buildImageCarousel(context),

          // Action buttons: Like, Comment, Share
          _buildActionButtons(context, theme, isDark),

          // Like count
          if (post.likeCount > 0) _buildLikeCount(context, theme),

          // Caption
          if (post.caption.isNotEmpty) _buildCaption(context, theme),

          // Comments preview
          if (post.commentCount > 0) _buildCommentsPreview(context, theme),

          // Timestamp
          _buildTimestamp(context, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDark) {
    return ListTile(
      leading: GestureDetector(
        onTap: onProfileTap,
        child: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          backgroundImage: petAvatarUrl != null && petAvatarUrl!.isNotEmpty
              ? NetworkImage(petAvatarUrl!)
              : null,
          child: petAvatarUrl == null || petAvatarUrl!.isEmpty
              ? const Icon(Icons.pets, color: Colors.white)
              : null,
        ),
      ),
      title: GestureDetector(
        onTap: onProfileTap,
        child: Text(
          petName ?? 'Unknown Pet',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      subtitle: post.location != null
          ? Row(
              children: [
                const Icon(Icons.location_on, size: 12),
                const SizedBox(width: 4),
                Text(
                  post.location.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            )
          : null,
      trailing: (onDelete != null || onEdit != null)
          ? IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptionsMenu(context),
            )
          : null,
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    if (post.imageUrls.length == 1) {
      return Image.network(
        post.imageUrls.first,
        width: double.infinity,
        height: 400,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 400,
            color: Colors.grey[300],
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
        errorBuilder: (context, error, stackTrace) => Container(
          height: 400,
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        ),
      );
    }

    return SizedBox(
      height: 400,
      child: PageView.builder(
        itemCount: post.imageUrls.length,
        itemBuilder: (context, index) {
          return Image.network(
            post.imageUrls[index],
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[300],
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
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Like button
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked
                  ? Colors.red
                  : theme.iconTheme.color,
            ),
            onPressed: onLike,
          ),
          // Comment button - visibility controlled by parent widget
          if (onComment != null)
            IconButton(
              icon: const Icon(Icons.comment_outlined),
              onPressed: onComment,
            ),
        ],
      ),
    );
  }

  Widget _buildLikeCount(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '${post.likeCount} ${post.likeCount == 1 ? 'like' : 'likes'}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCaption(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '${petName ?? 'Pet'} ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: post.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsPreview(BuildContext context, ThemeData theme) {
    if (post.commentCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onComment,
        child: Text(
          post.commentCount == 1
              ? AppLocalizations.of(context)!.viewComment
              : AppLocalizations.of(context)!.viewAllComments(post.commentCount),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context, ThemeData theme, bool isDark) {
    final timeAgo = _getTimeAgo(post.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        timeAgo,
        style: TextStyle(
          color: theme.textTheme.bodySmall?.color,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return DateFormat('MMM d, y').format(timestamp);
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(AppLocalizations.of(context)!.editPost),
                  onTap: () {
                    Navigator.pop(context);
                    onEdit!();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(AppLocalizations.of(context)!.deletePost, style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete!();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: Text(AppLocalizations.of(context)!.cancel),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
