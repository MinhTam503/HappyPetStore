import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';

/// Demo script to populate Social Pet Network with test data
/// 
/// Usage:
/// 1. Login to app with a test account
/// 2. Call initializeSocialNetworkDemo(context) from anywhere in the app
/// 3. Wait for success message
/// 4. Navigate to Social tab to see demo data

class SocialNetworkDemo {
  /// Initialize demo data with 3 pets and 5 posts
  static Future<void> initializeSocialNetworkDemo(BuildContext context) async {
    if (!context.mounted) return;
    
    final socialBloc = context.read<SocialBloc>();
    final currentUserId = userManager.currentUserId;
    
    if (currentUserId == null) {
      _showMessage(context, 'Please login first!', isError: true);
      return;
    }
    
    _showMessage(context, 'Creating demo data... Please wait');
    
    try {
      // Create 3 demo pet profiles
      final pets = [
        _DemoPet(
          id: 'demo_pet_1',
          name: 'Milo',
          breed: 'Golden Retriever',
          category: 'Dog',
          avatar: 'https://images.unsplash.com/photo-1633722715463-d30f4f325e24?w=400',
          bio: 'Just a happy golden retriever living my best life! 🐕✨',
        ),
        _DemoPet(
          id: 'demo_pet_2',
          name: 'Luna',
          breed: 'British Shorthair',
          category: 'Cat',
          avatar: 'https://images.unsplash.com/photo-1574158622682-e40e69881006?w=400',
          bio: 'Meow! I sleep 20 hours a day and I\'m proud of it 😴',
        ),
        _DemoPet(
          id: 'demo_pet_3',
          name: 'Charlie',
          breed: 'Corgi',
          category: 'Dog',
          avatar: 'https://images.unsplash.com/photo-1612536621410-7108c6c66f3f?w=400',
          bio: 'Short legs, big dreams! 🐾',
        ),
      ];
      
      // Create pet profiles
      for (final pet in pets) {
        socialBloc.add(CreatePetProfile(
          petId: pet.id,
          petName: pet.name,
          breed: pet.breed,
          category: pet.category,
          avatarUrl: pet.avatar,
          bio: pet.bio,
        ));
        
        // Wait a bit to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Wait for profiles to be created
      await Future.delayed(const Duration(seconds: 2));
      
      // Create demo posts
      final posts = [
        _DemoPost(
          petId: 'demo_pet_1',
          caption: 'Beautiful day at the park! 🌳☀️ #goldenretriever #dogsofinstagram #happydog',
          images: [
            'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=800',
            'https://images.unsplash.com/photo-1558788353-f76d92427f16?w=800',
          ],
        ),
        _DemoPost(
          petId: 'demo_pet_2',
          caption: 'Nap time is the best time 😴💤 #catsofinstagram #catlife #sleepy',
          images: [
            'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800',
          ],
        ),
        _DemoPost(
          petId: 'demo_pet_1',
          caption: 'Playing fetch with my favorite ball! 🎾 #playful #fetch',
          images: [
            'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=800',
          ],
        ),
        _DemoPost(
          petId: 'demo_pet_3',
          caption: 'Short legs, can\'t reach the treat... but I\'ll keep trying! 😂 #corgi #funny #shortlegs',
          images: [
            'https://images.unsplash.com/photo-1612536621410-7108c6c66f3f?w=800',
            'https://images.unsplash.com/photo-1558929996-da64ba858215?w=800',
          ],
        ),
        _DemoPost(
          petId: 'demo_pet_2',
          caption: 'Judging you from my throne 👑🐱 #catitude #queen',
          images: [
            'https://images.unsplash.com/photo-1573865526739-10c1dd7e9d99?w=800',
          ],
        ),
      ];
      
      // Create posts
      for (final post in posts) {
        socialBloc.add(CreatePost(
          petId: post.petId,
          caption: post.caption,
          imageUrls: post.images,
        ));
        
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Wait for posts to be created
      await Future.delayed(const Duration(seconds: 2));
      
      // Make pets follow each other
      socialBloc.add(const FollowPet('demo_pet_2'));
      await Future.delayed(const Duration(milliseconds: 300));
      socialBloc.add(const FollowPet('demo_pet_3'));
      
      // Reload feed to show new data
      await Future.delayed(const Duration(seconds: 1));
      socialBloc.add(const LoadExploreFeed());
      
      if (!context.mounted) return;
      _showMessage(
        context,
        '✅ Demo data created successfully!\n\n'
        '• 3 pet profiles created\n'
        '• 5 posts added\n'
        '• Following relationships set up\n\n'
        'Go to Social tab to see the feed!',
        duration: const Duration(seconds: 5),
      );
      
    } catch (e) {
      if (!context.mounted) return;
      _showMessage(
        context,
        'Error creating demo data: $e',
        isError: true,
      );
    }
  }
  
  /// Show a message to the user
  static void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF4CAF50)
                : const Color(0xFF08A045)),
        duration: duration,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

/// Demo pet data class
class _DemoPet {
  final String id;
  final String name;
  final String breed;
  final String category;
  final String avatar;
  final String bio;
  
  _DemoPet({
    required this.id,
    required this.name,
    required this.breed,
    required this.category,
    required this.avatar,
    required this.bio,
  });
}

/// Demo post data class
class _DemoPost {
  final String petId;
  final String caption;
  final List<String> images;
  
  _DemoPost({
    required this.petId,
    required this.caption,
    required this.images,
  });
}

/// Easy access function to call from debug console or any widget
/// 
/// Example usage in HomePage or ProfileScreen:
/// ```dart
/// FloatingActionButton(
///   onPressed: () => initializeSocialNetworkDemo(context),
///   child: const Icon(Icons.science),
/// )
/// ```
Future<void> initializeSocialNetworkDemo(BuildContext context) async {
  await SocialNetworkDemo.initializeSocialNetworkDemo(context);
}
