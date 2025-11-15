import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/domain/entities/social_post.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/widgets/social/post_card.dart';

class PostDetailSheet extends StatefulWidget {
  final SocialPost post;
  final String? currentUserId;
  final Function(String postId) onCommentTap;

  const PostDetailSheet({
    Key? key,
    required this.post,
    required this.currentUserId,
    required this.onCommentTap,
  }) : super(key: key);

  @override
  State<PostDetailSheet> createState() => _PostDetailSheetState();

  static void show(
    BuildContext context, {
    required SocialPost post,
    required String? currentUserId,
    required Function(String postId) onCommentTap,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostDetailSheet(
        post: post,
        currentUserId: currentUserId,
        onCommentTap: onCommentTap,
      ),
    );
  }
}

class _PostDetailSheetState extends State<PostDetailSheet> {
  String? _petName;
  String? _petAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadPetProfile();
  }

  Future<void> _loadPetProfile() async {
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('socialPetProfiles')
          .doc(widget.post.petId)
          .get();

      if (profileDoc.exists && mounted) {
        final data = profileDoc.data();
        setState(() {
          _petName = data?['displayName'] ?? data?['petName'] ?? 'User';
          _petAvatarUrl = data?['avatarUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error loading pet profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = widget.currentUserId != null && widget.post.isLikedBy(widget.currentUserId!);

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
                          'Post',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
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
                      post: widget.post,
                      petName: _petName,
                      petAvatarUrl: _petAvatarUrl,
                      isLiked: isLiked,
                      onLike: () {
                        if (isLiked) {
                          context.read<SocialBloc>().add(UnlikePost(widget.post.id));
                        } else {
                          context.read<SocialBloc>().add(LikePost(widget.post.id));
                        }
                      },
                      onComment: () {
                        Navigator.pop(context);
                        widget.onCommentTap(widget.post.id);
                      },
                      onProfileTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/social/profile',
                          arguments: widget.post.petId,
                        );
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
  }
}
