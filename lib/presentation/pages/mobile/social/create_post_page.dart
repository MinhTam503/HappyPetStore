import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  
  String? _userName;
  String? _userAvatar;
  String? _userId;
  
  bool _isUploading = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }
  
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() {
      _userId = user.uid;
    });
    
    // Get from socialPetProfiles collection (already synced)
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('socialPetProfiles')
          .doc(user.uid)
          .get();
      
      if (profileDoc.exists) {
        final data = profileDoc.data();
        setState(() {
          _userName = data?['displayName'] ?? data?['petName'] ?? 'User';
          _userAvatar = data?['avatarUrl'] ?? '';
        });
      } else {
        // Fallback to Users collection if profile not synced yet
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _userName = data?['displayName'] ?? data?['name'] ?? user.displayName ?? 'User';
            _userAvatar = data?['imageUrl'] ?? data?['photoURL'] ?? user.photoURL ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }
  
  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImages() async {
    if (_selectedImages.length >= 10) {
      final l10n = AppLocalizations.of(context);
      if (!mounted) return;
      NotificationHelper.showWarning(
        context,
        l10n?.maxPhotosReached ?? 'Maximum 10 photos',
      );
      return;
    }
    
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          final remaining = 10 - _selectedImages.length;
          _selectedImages.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }
  
  Future<void> _takePhoto() async {
    if (_selectedImages.length >= 10) {
      final l10n = AppLocalizations.of(context);
      if (!mounted) return;
      NotificationHelper.showWarning(
        context,
        l10n?.maxPhotosReached ?? 'Maximum 10 photos',
      );
      return;
    }
    
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }
  
  Future<void> _showImageSourceDialog() async {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  Icons.photo_library_rounded,
                  color: Theme.of(context)
                                    .colorScheme.primary,
                  size: 28,
                ),
                title: Text(
                  l10n?.selectFromGallery ?? 'Select from gallery',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImages();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_rounded,
                  color: Theme.of(context)
                                    .colorScheme.primary,
                  size: 28,
                ),
                title: Text(
                  l10n?.takePhoto ?? 'Take photo',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _ensureUserProfileExists() async {
    if (_userId == null) return;
    
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('socialPetProfiles')
          .doc(_userId)
          .get();
      
      if (!profileDoc.exists) {
        // Create user's social profile
        await FirebaseFirestore.instance
            .collection('socialPetProfiles')
            .doc(_userId)
            .set({
          'petId': _userId,
          'petName': _userName ?? 'User',
          'breed': '',
          'category': 'User',
          'avatarUrl': _userAvatar ?? '',
          'bio': '',
          'followers': [],
          'following': [],
          'posts': 0,
          'totalFollowers': 0,
          'totalLikes': 0,
          'totalComments': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Created social profile for user: $_userId');
      }
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
    }
  }
  
  Future<List<String>> _uploadImages() async {
    final List<String> imageUrls = [];
    final storage = FirebaseStorage.instance;
    
    for (int i = 0; i < _selectedImages.length; i++) {
      final file = File(_selectedImages[i].path);
      final fileName = 'social_posts/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      
      try {
        final ref = storage.ref().child(fileName);
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      } catch (e) {
        debugPrint('Error uploading image $i: $e');
        throw Exception('Failed to upload image ${i + 1}');
      }
    }
    
    return imageUrls;
  }
  
  Future<void> _createPost() async {
    final l10n = AppLocalizations.of(context);
    
    // Validation
    if (_selectedImages.isEmpty) {
      NotificationHelper.showWarning(
        context,
        l10n?.selectAtLeastOnePhoto ?? 'Please select at least 1 photo',
      );
      return;
    }
    
    if (_userId == null) {
      NotificationHelper.showError(
        context,
        l10n?.pleaseLogin ?? 'Please login',
      );
      return;
    }
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      // Show loading dialog
      if (!mounted) return;
      DialogHelper.showLoadingDialog(
        context,
        message: l10n?.uploadingImages ?? 'Uploading images...',
      );
      
      // Ensure user profile exists first
      await _ensureUserProfileExists();
      
      // Upload images to Firebase Storage
      final imageUrls = await _uploadImages();
      
      // Extract hashtags from caption
      final caption = _captionController.text.trim();
      final tags = <String>[];
      final hashtagRegex = RegExp(r'#(\w+)');
      final matches = hashtagRegex.allMatches(caption);
      for (final match in matches) {
        tags.add(match.group(1)!.toLowerCase());
      }
      
      // Create post with user ID as petId
      context.read<SocialBloc>().add(
            CreatePost(
              petId: _userId!,
              imageUrls: imageUrls,
              caption: caption,
              tags: tags,
            ),
          );
      
      // Hide loading
      if (!mounted) return;
      await DialogHelper.hideLoadingDialog(context);
      
      // Show success notification
      if (!mounted) return;
      NotificationHelper.showSuccess(
        context,
        l10n?.postCreatedSuccessfully ?? 'Post created successfully!',
      );
      
      // Navigate back
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Error creating post: $e');
      
      setState(() {
        _isUploading = false;
      });
      
      // Hide loading
      if (!mounted) return;
      await DialogHelper.hideLoadingDialog(context);
      
      // Show error notification
      if (!mounted) return;
      NotificationHelper.showError(
        context,
        l10n?.errorCreatingPost ?? 'Error creating post',
        e.toString(),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n?.newPost ?? 'New Post',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _createPost,
            child: Text(
              l10n?.post ?? 'Post',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isUploading
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                    : (isDark ? darkPrimaryColor : Theme.of(context)
                                    .colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context)
                                    .colorScheme.primary.withOpacity(0.1),
                    backgroundImage: _userAvatar != null && _userAvatar!.isNotEmpty
                        ? NetworkImage(_userAvatar!)
                        : null,
                    child: _userAvatar == null || _userAvatar!.isEmpty
                        ? Icon(Icons.person, color: Theme.of(context)
                                    .colorScheme.primary, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // User Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName ?? 'User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n?.createPost ?? 'Create Post',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Caption Input
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _captionController,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: l10n?.writeCaption ?? 'Write caption...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  counterStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                style: const TextStyle(fontSize: 15),
              ),
            ),
            
            // Images Grid
            if (_selectedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Text(
                        //   '${_selectedImages.length} ${l10n?.photosSelected ?? 'photos selected'}',
                        //   style: TextStyle(
                        //     fontSize: 14,
                        //     fontWeight: FontWeight.w600,
                        //     color: Colors.grey[700],
                        //   ),
                        // ),
                        Text(
                          '${_selectedImages.length}/10',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_selectedImages[index].path),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Add Photos Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _showImageSourceDialog,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _selectedImages.isEmpty
                      ? (l10n?.selectPhotos ?? 'Select Photos')
                      : (l10n?.addLocation ?? 'Add More Photos'),
                  style: const TextStyle(fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? darkPrimaryColor : Theme.of(context)
                                    .colorScheme.primary,
                  side: BorderSide(
                    color: isDark ? darkPrimaryColor : Theme.of(context)
                                    .colorScheme.primary,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            // const SizedBox(height: 24),
            
            // // Tips Section
            // Padding(
            //   padding: const EdgeInsets.all(16),
            //   child: Container(
            //     padding: const EdgeInsets.all(16),
            //     decoration: BoxDecoration(
            //       color: (isDark ? darkPrimaryColor : primaryColor)
            //           .withOpacity(0.1),
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         // Row(
            //         //   children: [
            //         //     Icon(
            //         //       Icons.lightbulb_outline,
            //         //       color: isDark ? darkPrimaryColor : primaryColor,
            //         //       size: 20,
            //         //     ),
            //         //     const SizedBox(width: 8),
            //         //     Text(
            //         //       'Tips',
            //         //       style: TextStyle(
            //         //         fontSize: 15,
            //         //         fontWeight: FontWeight.bold,
            //         //         color: isDark ? darkPrimaryColor : primaryColor,
            //         //       ),
            //         //     ),
            //         //   ],
            //         // ),
            //         // const SizedBox(height: 8),
            //         // Text(
            //         //   '• ${l10n?.writeCaption ?? 'Write engaging captions'}\n'
            //         //   '• Use #hashtags to reach more people\n'
            //         //   '• Add clear, bright photos\n'
            //         //   '• Share your pet moments',
            //         //   style: TextStyle(
            //         //     fontSize: 13,
            //         //     color: Colors.grey[700],
            //         //     height: 1.5,
            //         //   ),
            //         // ),
            //       ],
            //     ),
            //   ),
            // ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
