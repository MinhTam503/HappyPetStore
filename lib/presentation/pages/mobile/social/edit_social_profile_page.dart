import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/domain/entities/social_pet_profile.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';

class EditSocialProfilePage extends StatefulWidget {
  final SocialPetProfile profile;
  
  const EditSocialProfilePage({
    Key? key,
    required this.profile,
  }) : super(key: key);

  @override
  State<EditSocialProfilePage> createState() => _EditSocialProfilePageState();
}

class _EditSocialProfilePageState extends State<EditSocialProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _websiteController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  
  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName ?? widget.profile.petName,
    );
    _bioController = TextEditingController(text: widget.profile.bio);
    _websiteController = TextEditingController(text: widget.profile.website ?? '');
    _emailController = TextEditingController(text: widget.profile.email ?? '');
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _uploadedImageUrl = widget.profile.avatarUrl;
  }
  
  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }
  
  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('social_profiles')
          .child('${widget.profile.id}_$timestamp.jpg');
      
      await ref.putFile(_selectedImage!);
      final url = await ref.getDownloadURL();
      
      setState(() {
        _uploadedImageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorUploadingImage}: $e')),
        );
      }
    }
  }
  
  bool _isUpdating = false;
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUpdating) return; // Prevent multiple saves
    
    setState(() {
      _isUpdating = true;
    });
    
    final updates = <String, dynamic>{
      'displayName': _displayNameController.text.trim(),
      'petName': _displayNameController.text.trim(),
      'bio': _bioController.text.trim(),
      'website': _websiteController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
    };
    
    if (_uploadedImageUrl != null && _uploadedImageUrl != widget.profile.avatarUrl) {
      updates['avatarUrl'] = _uploadedImageUrl;
    }
    
    context.read<SocialBloc>().add(
      UpdateUserProfile(widget.profile.id, updates),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editSocialProfile),
        actions: [
          BlocConsumer<SocialBloc, SocialState>(
            listener: (context, state) {
              // Listen for profile update
              if (state is SocialLoaded && _isUpdating) {
                // Check if the profile has been updated
                final updatedProfile = state.profileCache[widget.profile.id];
                if (updatedProfile != null) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileUpdated)),
                  );
                  Navigator.pop(context, true); // Return true to indicate update success
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
                onPressed: _isUpdating ? null : _saveProfile,
                child: Text(
                  _isUpdating ? l10n.savingProfile : l10n.saveProfile,
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!) as ImageProvider
                        : (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty
                            ? NetworkImage(_uploadedImageUrl!)
                            : null),
                    child: _selectedImage == null && 
                           (_uploadedImageUrl == null || _uploadedImageUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: CircularProgressIndicator(),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: theme.primaryColor,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                        onPressed: _isUploading ? null : _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Display Name
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: l10n.displayName,
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a display name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Bio
            TextFormField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: l10n.bio,
                prefixIcon: const Icon(Icons.info_outline),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Website
            TextFormField(
              controller: _websiteController,
              decoration: InputDecoration(
                labelText: l10n.website,
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            
            const SizedBox(height: 16),
            
            // Email
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                prefixIcon: const Icon(Icons.email_outlined),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: l10n.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
