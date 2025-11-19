import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/domain/entities/social_post.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';

class EditPostPage extends StatefulWidget {
  final SocialPost post;

  const EditPostPage({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late TextEditingController _captionController;
  late TextEditingController _tagsController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.post.caption);
    _tagsController = TextEditingController(
      text: widget.post.tags.join(' '),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    // Parse tags from text
    final tagsText = _tagsController.text.trim();
    final tags = tagsText.isEmpty
        ? <String>[]
        : tagsText
            .split(' ')
            .where((tag) => tag.isNotEmpty)
            .map((tag) => tag.startsWith('#') ? tag : '#$tag')
            .toList();

    final updates = {
      'caption': _captionController.text.trim(),
      'tags': tags,
    };

    context.read<SocialBloc>().add(
      UpdatePost(widget.post.id, updates),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editPost),
        actions: [
          BlocConsumer<SocialBloc, SocialState>(
            listener: (context, state) {
              if (state is SocialLoaded && _isUpdating) {
                // Check if post was updated
                final updatedPost = [
                  ...state.feed,
                  ...state.userPosts,
                  ...state.exploreFeed
                ].firstWhere(
                  (post) => post.id == widget.post.id,
                  orElse: () => widget.post,
                );

                if (updatedPost.caption != widget.post.caption ||
                    updatedPost.tags.join() != widget.post.tags.join()) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.postUpdatedSuccessfully)),
                  );
                  Navigator.pop(context, true);
                }
              } else if (state is SocialError) {
                setState(() {
                  _isUpdating = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              }
            },
            builder: (context, state) {
              return TextButton(
                onPressed: _isUpdating ? null : _saveChanges,
                child: Text(
                  _isUpdating ? l10n.saving : l10n.save,
                  style: TextStyle(
                    color: _isUpdating ? Colors.grey : theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Show first image as preview
          if (widget.post.imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.post.imageUrls.first,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          const SizedBox(height: 24),

          // Caption field
          TextField(
            controller: _captionController,
            maxLines: 5,
            maxLength: 2200,
            decoration: InputDecoration(
              labelText: l10n.caption,
              hintText: l10n.writeCaption,
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 16),

          // Tags field
          TextField(
            controller: _tagsController,
            decoration: InputDecoration(
              labelText: l10n.tags,
              hintText: l10n.tagsHint,
              border: const OutlineInputBorder(),
              helperText: l10n.tagsHelperText,
            ),
          ),

          const SizedBox(height: 24),

          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.editPostInfo,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
