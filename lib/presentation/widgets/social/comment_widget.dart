import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/domain/entities/social_post.dart';

/// Modern comment widget with like functionality
class CommentWidget extends StatelessWidget {
  final SocialComment comment;
  final String? currentUserId;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const CommentWidget({
    Key? key,
    required this.comment,
    this.currentUserId,
    this.onLike,
    this.onReply,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLiked = currentUserId != null && comment.likes.contains(currentUserId);
    final isOwner = currentUserId == comment.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.1),
            backgroundImage: comment.userAvatarUrl.isNotEmpty
                ? NetworkImage(comment.userAvatarUrl)
                : null,
            child: comment.userAvatarUrl.isEmpty
                ? Icon(
                    Icons.person,
                    size: 20,
                    color: isDark ? darkPrimaryColor : primaryColor,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username
                      Text(
                        comment.userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? darkPrimaryColor : primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Comment text
                      Text(
                        comment.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 6),
                
                // Actions row
                Row(
                  children: [
                    // Timestamp
                    Text(
                      _formatTimestamp(comment.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Like button
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.like,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                              color: isLiked
                                  ? (isDark ? darkPrimaryColor : primaryColor)
                                  : Colors.grey[600],
                            ),
                          ),
                          if (comment.likes.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${comment.likes.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Reply button
                    if (onReply != null)
                      GestureDetector(
                        onTap: onReply,
                        child: Text(
                          AppLocalizations.of(context)!.reply,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    
                    const Spacer(),
                    
                    // Delete button (only for owner)
                    if (isOwner && onDelete != null)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red[400],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}

/// Comment input widget with modern design
class CommentInput extends StatefulWidget {
  final String? currentUserAvatar;
  final String? currentUserName;
  final Function(String) onSubmit;
  final String? replyingTo;
  final VoidCallback? onCancelReply;

  const CommentInput({
    Key? key,
    this.currentUserAvatar,
    this.currentUserName,
    required this.onSubmit,
    this.replyingTo,
    this.onCancelReply,
  }) : super(key: key);

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSubmit(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply indicator
          if (widget.replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: isDark ? darkPrimaryColor : primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to ${widget.replyingTo}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? darkPrimaryColor : primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onCancelReply,
                  ),
                ],
              ),
            ),
          
          // Input row
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: (isDark ? darkPrimaryColor : primaryColor)
                        .withOpacity(0.1),
                    backgroundImage: widget.currentUserAvatar != null &&
                            widget.currentUserAvatar!.isNotEmpty
                        ? NetworkImage(widget.currentUserAvatar!)
                        : null,
                    child: widget.currentUserAvatar == null ||
                            widget.currentUserAvatar!.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 20,
                            color: isDark ? darkPrimaryColor : primaryColor,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  
                  // Input field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!.addComment,
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                              maxLines: 5,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                          
                          // Send button
                          IconButton(
                            icon: Icon(
                              Icons.send_rounded,
                              color: _controller.text.trim().isNotEmpty
                                  ? (isDark ? darkPrimaryColor : primaryColor)
                                  : Colors.grey[400],
                            ),
                            onPressed: _submit,
                          ),
                        ],
                      ),
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
}
