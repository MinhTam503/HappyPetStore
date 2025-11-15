import 'package:pet_shop/domain/entities/social_pet_profile.dart';
import 'package:pet_shop/domain/entities/social_post.dart';

/// Repository interface for social network features
abstract class SocialRepository {
  // === User Profile Management ===
  
  /// Ensure user has a social profile, create from Users collection if not exists
  Future<SocialPetProfile> ensureUserProfile(String userId);
  
  /// Get user's social profile by userId
  Future<SocialPetProfile?> getUserProfile(String userId);
  
  /// Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates);
  
  /// Get posts by a specific user
  Future<List<SocialPost>> getUserPosts(String userId, {int limit = 20});
  
  // === Pet Profile Management ===
  
  /// Create a social profile for a pet
  Future<SocialPetProfile> createPetProfile({
    required String petId,
    required String ownerId,
    required String petName,
    required String breed,
    required String category,
    required String avatarUrl,
    String bio = '',
  });
  
  /// Get a pet's social profile
  Future<SocialPetProfile?> getPetProfile(String petId);
  
  /// Update pet profile
  Future<void> updatePetProfile(String petId, Map<String, dynamic> updates);
  
  /// Check if a pet has a social profile
  Future<bool> hasSocialProfile(String petId);
  
  // === Follow System ===
  
  /// Follow a pet
  Future<void> followPet({
    required String userId,
    required String petId,
  });
  
  /// Unfollow a pet
  Future<void> unfollowPet({
    required String userId,
    required String petId,
  });
  
  /// Get followers of a pet
  Future<List<String>> getFollowers(String petId);
  
  /// Get pets that a user follows
  Future<List<SocialPetProfile>> getFollowing(String userId);
  
  /// Check if user follows a pet
  Future<bool> isFollowing(String userId, String petId);
  
  // === Post Management ===
  
  /// Create a new post
  Future<SocialPost> createPost({
    required String petId,
    required String authorId,
    required List<String> imageUrls,
    String? videoUrl,
    required String caption,
    List<String> tags = const [],
    PostLocation? location,
  });
  
  /// Get posts from a specific pet
  Future<List<SocialPost>> getPetPosts(String petId, {int limit = 20});
  
  /// Get feed for a user (posts from followed pets)
  Future<List<SocialPost>> getFeed(String userId, {int limit = 20});
  
  /// Get trending/explore posts
  Future<List<SocialPost>> getExplorePosts({int limit = 30, String? excludeUserId});
  
  /// Delete a post
  Future<void> deletePost(String postId);
  
  // === Likes & Comments ===
  
  /// Like a post
  Future<void> likePost(String postId, String userId);
  
  /// Unlike a post
  Future<void> unlikePost(String postId, String userId);
  
  /// Add a comment to a post
  Future<SocialComment> addComment({
    required String postId,
    required String userId,
    required String userName,
    required String userAvatarUrl,
    required String text,
    String? parentId, // For nested replies
  });
  
  /// Delete a comment
  Future<void> deleteComment(String postId, String commentId);
  
  /// Like a comment
  Future<void> likeComment(String postId, String commentId, String userId);
  
  /// Get comments for a post
  Future<List<SocialComment>> getComments(String postId);
  
  // === Discovery ===
  
  /// Search pets by name or breed
  Future<List<SocialPetProfile>> searchPets(String query);
  
  /// Get pets by breed
  Future<List<SocialPetProfile>> getPetsByBreed(String breed);
  
  /// Get pets by location
  Future<List<SocialPetProfile>> getPetsByLocation(String city);
  
  /// Get trending hashtags
  Future<List<String>> getTrendingTags({int limit = 10});
  
  // === Statistics ===
  
  /// Update post view count
  Future<void> incrementViewCount(String postId);
  
  /// Get pet statistics
  Future<SocialStats> getPetStats(String petId);
}
