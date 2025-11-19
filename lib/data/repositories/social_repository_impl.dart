import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_shop/data/models/social_pet_profile_model.dart';
import 'package:pet_shop/data/models/social_post_model.dart';
import 'package:pet_shop/domain/entities/social_pet_profile.dart';
import 'package:pet_shop/domain/entities/social_post.dart';
import 'package:pet_shop/domain/repositories/social_repository.dart';

class SocialRepositoryImpl implements SocialRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _profilesRef => _firestore.collection('socialPetProfiles');
  CollectionReference get _postsRef => _firestore.collection('socialPosts');
  CollectionReference get _followsRef => _firestore.collection('socialFollows');
  CollectionReference get _usersRef => _firestore.collection('users');

  // === User Profile Management ===

  @override
  Future<SocialPetProfile> ensureUserProfile(String userId) async { 
    try {
      // Check if profile already exists
      final profileDoc = await _profilesRef.doc(userId).get();
      if (profileDoc.exists) {
        return SocialPetProfileModel.fromFirestore(profileDoc);
      }

      // Profile doesn't exist, create from Users collection
      final userDoc = await _usersRef.doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found in Users collection');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Get avatar URL - try multiple possible field names
      String avatarUrl = '';
      if (userData['imageUrl'] != null && userData['imageUrl'].toString().isNotEmpty) {
        avatarUrl = userData['imageUrl'];
      } else if (userData['photoURL'] != null && userData['photoURL'].toString().isNotEmpty) {
        avatarUrl = userData['photoURL'];
      } else if (userData['avatar'] != null && userData['avatar'].toString().isNotEmpty) {
        avatarUrl = userData['avatar'];
      } else if (userData['profilePicture'] != null && userData['profilePicture'].toString().isNotEmpty) {
        avatarUrl = userData['profilePicture'];
      }
      
      if (kDebugMode) {
        print('🔍 User data keys: ${userData.keys.toList()}');
        print('🔍 Avatar URL found: $avatarUrl');
      }
      
      // Create social profile with user data
      final profile = SocialPetProfileModel(
        id: userId,
        ownerId: userId,
        petName: userData['displayName'] ?? userData['name'] ?? 'User',
        breed: '', // Not applicable for users
        category: 'user', // Mark as user profile
        avatarUrl: avatarUrl,
        bio: '',
        followers: [],
        following: [],
        stats: SocialStats(),
        createdAt: DateTime.now(),
        isPublic: true,
        displayName: userData['displayName'] ?? userData['name'],
        email: userData['email'],
        phone: userData['phone'],
        website: null,
      );

      await _profilesRef.doc(userId).set(profile.toFirestore());
      
      if (kDebugMode) {
        print('✅ Created social profile for user: $userId');
      }
      
      return profile;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error ensuring user profile: $e');
      }
      rethrow;
    }
  }

  @override
  Future<SocialPetProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _profilesRef.doc(userId).get();
      if (!doc.exists) return null;
      
      final profile = SocialPetProfileModel.fromFirestore(doc);
      
      // Sync stats with actual array lengths if mismatch
      final actualFollowers = profile.followers.length;
      final actualFollowing = profile.following.length;
      
      if (profile.stats.followers != actualFollowers || profile.stats.following != actualFollowing) {
        if (kDebugMode) {
          print('⚠️ Stats mismatch for $userId: syncing stats');
          print('  Followers: ${profile.stats.followers} → $actualFollowers');
          print('  Following: ${profile.stats.following} → $actualFollowing');
        }
        
        // Update stats to match arrays
        await _profilesRef.doc(userId).update({
          'stats.followers': actualFollowers,
          'stats.following': actualFollowing,
        });
        
        // Return updated profile
        return profile.copyWith(
          stats: profile.stats.copyWith(
            followers: actualFollowers,
            following: actualFollowing,
          ),
        );
      }
      
      return profile;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user profile: $e');
      }
      return null;
    }
  }

  @override
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _profilesRef.doc(userId).update(updates);
      if (kDebugMode) {
        print('✅ Updated user profile: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating user profile: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<SocialPost>> getUserPosts(String userId, {int limit = 20}) async {
    try {
      final querySnapshot = await _postsRef
          .where('petId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => SocialPostModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user posts: $e');
      }
      return [];
    }
  }

  // === Pet Profile Management ===

  @override
  Future<SocialPetProfile> createPetProfile({
    required String petId,
    required String ownerId,
    required String petName,
    required String breed,
    required String category,
    required String avatarUrl,
    String bio = '',
  }) async {
    try {
      final profile = SocialPetProfileModel(
        id: petId,
        ownerId: ownerId,
        petName: petName,
        breed: breed,
        category: category,
        avatarUrl: avatarUrl,
        bio: bio,
        followers: [],
        following: [],
        stats: SocialStats(),
        createdAt: DateTime.now(),
        isPublic: true,
      );

      await _profilesRef.doc(petId).set(profile.toFirestore());
      
      if (kDebugMode) {
        print('✅ Created social profile for pet: $petId');
      }
      
      return profile;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating pet profile: $e');
      }
      rethrow;
    }
  }

  @override
  Future<SocialPetProfile?> getPetProfile(String petId) async {
    try {
      final doc = await _profilesRef.doc(petId).get();
      if (!doc.exists) return null;
      return SocialPetProfileModel.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting pet profile: $e');
      }
      return null;
    }
  }

  @override
  Future<void> updatePetProfile(String petId, Map<String, dynamic> updates) async {
    try {
      await _profilesRef.doc(petId).update(updates);
      if (kDebugMode) {
        print('✅ Updated pet profile: $petId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating pet profile: $e');
      }
      rethrow;
    }
  }

  @override
  Future<bool> hasSocialProfile(String petId) async {
    try {
      final doc = await _profilesRef.doc(petId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // === Follow System ===

  @override
  Future<void> followPet({
    required String userId,
    required String petId,
  }) async {
    try {
      final followId = '${userId}_$petId';
      
      // Check if already following
      final existingFollow = await _followsRef.doc(followId).get();
      if (existingFollow.exists) {
        if (kDebugMode) {
          print('⚠️ User $userId already following pet $petId');
        }
        return; // Already following, do nothing
      }
      
      // Create follow document
      await _followsRef.doc(followId).set({
        'followerId': userId,
        'followingPetId': petId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update follower's following list (current user)
      await _profilesRef.doc(userId).update({
        'following': FieldValue.arrayUnion([petId]),
        'stats.following': FieldValue.increment(1),
      });

      // Update followee's followers list (target user)
      await _profilesRef.doc(petId).update({
        'followers': FieldValue.arrayUnion([userId]),
        'stats.followers': FieldValue.increment(1),
      });

      if (kDebugMode) {
        print('✅ User $userId followed pet $petId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error following pet: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> unfollowPet({
    required String userId,
    required String petId,
  }) async {
    try {
      final followId = '${userId}_$petId';
      
      // Check if actually following
      final existingFollow = await _followsRef.doc(followId).get();
      if (!existingFollow.exists) {
        if (kDebugMode) {
          print('⚠️ User $userId not following pet $petId');
        }
        return; // Not following, do nothing
      }
      
      // Delete follow document
      await _followsRef.doc(followId).delete();

      // Update follower's following list (current user)
      await _profilesRef.doc(userId).update({
        'following': FieldValue.arrayRemove([petId]),
        'stats.following': FieldValue.increment(-1),
      });

      // Update followee's followers list (target user)
      await _profilesRef.doc(petId).update({
        'followers': FieldValue.arrayRemove([userId]),
        'stats.followers': FieldValue.increment(-1),
      });

      if (kDebugMode) {
        print('✅ User $userId unfollowed pet $petId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error unfollowing pet: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<String>> getFollowers(String petId) async {
    try {
      final doc = await _profilesRef.doc(petId).get();
      if (!doc.exists) return [];
      
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['followers'] ?? []);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting followers: $e');
      }
      return [];
    }
  }

  @override
  Future<List<SocialPetProfile>> getFollowing(String userId) async {
    try {
      final followDocs = await _followsRef
          .where('followerId', isEqualTo: userId)
          .get();

      final petIds = followDocs.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['followingPetId'] as String)
          .toList();

      if (petIds.isEmpty) return [];

      // Get profiles in batches (Firestore limit is 10 for whereIn)
      final profiles = <SocialPetProfile>[];
      for (int i = 0; i < petIds.length; i += 10) {
        final batch = petIds.sublist(i, i + 10 > petIds.length ? petIds.length : i + 10);
        final docs = await _profilesRef
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        profiles.addAll(docs.docs.map((doc) => 
            SocialPetProfileModel.fromFirestore(doc)));
      }

      return profiles;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting following: $e');
      }
      return [];
    }
  }

  @override
  Future<bool> isFollowing(String userId, String petId) async {
    try {
      final followId = '${userId}_$petId';
      final doc = await _followsRef.doc(followId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // === Post Management ===

  @override
  Future<SocialPost> createPost({
    required String petId,
    required String authorId,
    required List<String> imageUrls,
    String? videoUrl,
    required String caption,
    List<String> tags = const [],
    PostLocation? location,
  }) async {
    try {
      final docRef = _postsRef.doc();
      
      final post = SocialPostModel(
        id: docRef.id,
        petId: petId,
        authorId: authorId,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        caption: caption,
        likes: [],
        comments: [],
        location: location,
        tags: tags,
        timestamp: DateTime.now(),
        viewCount: 0,
      );

      await docRef.set(post.toFirestore());

      // Update profile post count
      await _profilesRef.doc(petId).update({
        'stats.posts': FieldValue.increment(1),
      });

      if (kDebugMode) {
        print('✅ Created post: ${post.id}');
      }

      return post;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating post: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<SocialPost>> getPetPosts(String petId, {int limit = 20}) async {
    try {
      final snapshot = await _postsRef
          .where('petId', isEqualTo: petId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SocialPostModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting pet posts: $e');
      }
      return [];
    }
  }

  @override
  Future<List<SocialPost>> getFeed(String userId, {int limit = 20}) async {
    try {
      // Get user's following array from their profile
      final userProfile = await getUserProfile(userId);
      if (userProfile == null) {
        return [];
      }

      // Include own userId to see own posts in feed
      final petIds = [...userProfile.following];
      if (!petIds.contains(userId)) {
        petIds.add(userId);
      }
      
      if (petIds.isEmpty) {
        return [];
      }

      // Get posts from followed pets (in batches due to whereIn limit)
      final posts = <SocialPost>[];
      for (int i = 0; i < petIds.length; i += 10) {
        final batch = petIds.sublist(i, i + 10 > petIds.length ? petIds.length : i + 10);
        final snapshot = await _postsRef
            .where('petId', whereIn: batch)
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();

        posts.addAll(snapshot.docs
            .map((doc) => SocialPostModel.fromFirestore(doc)));
      }

      // Sort by timestamp
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return posts.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting feed: $e');
      }
      return [];
    }
  }

  @override
  Future<List<SocialPost>> getExplorePosts({int limit = 30, String? excludeUserId}) async {
    try {
      final snapshot = await _postsRef
          .orderBy('viewCount', descending: true)
          .orderBy('timestamp', descending: true)
          .limit(limit * 2)
          .get();

      var posts = snapshot.docs
          .map((doc) => SocialPostModel.fromFirestore(doc))
          .toList();
      
      // Exclude own posts if userId provided
      if (excludeUserId != null) {
        posts = posts.where((post) => post.petId != excludeUserId).toList();
      }

      return posts.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting explore posts: $e');
      }
      return [];
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      final doc = await _postsRef.doc(postId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final petId = data['petId'] as String;

      await _postsRef.doc(postId).delete();

      // Update profile post count
      await _profilesRef.doc(petId).update({
        'stats.posts': FieldValue.increment(-1),
      });

      if (kDebugMode) {
        print('✅ Deleted post: $postId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting post: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      final doc = await _postsRef.doc(postId).get();
      if (!doc.exists) {
        throw Exception('Post not found');
      }

      // Only allow updating certain fields
      final allowedFields = ['caption', 'tags', 'location'];
      final filteredUpdates = <String, dynamic>{};
      
      for (var key in allowedFields) {
        if (updates.containsKey(key)) {
          filteredUpdates[key] = updates[key];
        }
      }

      if (filteredUpdates.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No valid fields to update');
        }
        return;
      }

      filteredUpdates['updatedAt'] = FieldValue.serverTimestamp();

      await _postsRef.doc(postId).update(filteredUpdates);

      if (kDebugMode) {
        print('✅ Updated post: $postId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating post: $e');
      }
      rethrow;
    }
  }

  // === Likes & Comments ===

  @override
  Future<void> likePost(String postId, String userId) async {
    try {
      await _postsRef.doc(postId).update({
        'likes': FieldValue.arrayUnion([userId]),
      });

      // Update pet profile stats
      final doc = await _postsRef.doc(postId).get();
      final petId = (doc.data() as Map<String, dynamic>)['petId'] as String;
      
      await _profilesRef.doc(petId).update({
        'stats.totalLikes': FieldValue.increment(1),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error liking post: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> unlikePost(String postId, String userId) async {
    try {
      await _postsRef.doc(postId).update({
        'likes': FieldValue.arrayRemove([userId]),
      });

      // Update pet profile stats
      final doc = await _postsRef.doc(postId).get();
      final petId = (doc.data() as Map<String, dynamic>)['petId'] as String;
      
      await _profilesRef.doc(petId).update({
        'stats.totalLikes': FieldValue.increment(-1),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error unliking post: $e');
      }
      rethrow;
    }
  }

  @override
  Future<SocialComment> addComment({
    required String postId,
    required String userId,
    required String userName,
    required String userAvatarUrl,
    required String text,
    String? parentId, // For replies
  }) async {
    try {
      final comment = SocialCommentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        postId: postId,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        text: text,
        likes: [],
        timestamp: DateTime.now(),
        parentId: parentId,
      );

      final commentMap = {
        'id': comment.id,
        'postId': comment.postId,
        'userId': comment.userId,
        'userName': comment.userName,
        'userAvatarUrl': comment.userAvatarUrl,
        'text': comment.text,
        'likes': comment.likes,
        'timestamp': Timestamp.fromDate(comment.timestamp),
        if (parentId != null) 'parentId': parentId,
      };

      // If this is a reply, add it to parent's replies array
      if (parentId != null) {
        final doc = await _postsRef.doc(postId).get();
        final data = doc.data() as Map<String, dynamic>;
        final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
        
        // Find parent comment and add reply
        for (var i = 0; i < comments.length; i++) {
          if (comments[i]['id'] == parentId) {
            final replies = List<Map<String, dynamic>>.from(comments[i]['replies'] ?? []);
            replies.add(commentMap);
            comments[i]['replies'] = replies;
            break;
          }
        }
        
        await _postsRef.doc(postId).update({'comments': comments});
      } else {
        // Top-level comment
        await _postsRef.doc(postId).update({
          'comments': FieldValue.arrayUnion([commentMap]),
        });
      }

      // Update pet profile stats
      final doc = await _postsRef.doc(postId).get();
      final petId = (doc.data() as Map<String, dynamic>)['petId'] as String;
      
      await _profilesRef.doc(petId).update({
        'stats.totalComments': FieldValue.increment(1),
      });

      return comment;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding comment: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      final doc = await _postsRef.doc(postId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
      
      comments.removeWhere((c) => c['id'] == commentId);

      await _postsRef.doc(postId).update({'comments': comments});

      // Update pet profile stats
      final petId = data['petId'] as String;
      await _profilesRef.doc(petId).update({
        'stats.totalComments': FieldValue.increment(-1),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting comment: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> likeComment(String postId, String commentId, String userId) async {
    try {
      final doc = await _postsRef.doc(postId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
      
      for (var comment in comments) {
        if (comment['id'] == commentId) {
          final likes = List<String>.from(comment['likes'] ?? []);
          // Toggle: if already liked, remove; otherwise add
          if (likes.contains(userId)) {
            likes.remove(userId);
          } else {
            likes.add(userId);
          }
          comment['likes'] = likes;
          break;
        }
      }

      await _postsRef.doc(postId).update({'comments': comments});
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error liking comment: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<SocialComment>> getComments(String postId) async {
    try {
      final doc = await _postsRef.doc(postId).get();
      if (!doc.exists) return [];

      final data = doc.data() as Map<String, dynamic>;
      final commentsData = List<Map<String, dynamic>>.from(data['comments'] ?? []);

      return commentsData
          .map((c) => SocialCommentModel.fromMap(c))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting comments: $e');
      }
      return [];
    }
  }

  // === Discovery ===

  @override
  Future<List<SocialPetProfile>> searchPets(String query) async {
    try {
      final queryLower = query.toLowerCase();
      
      // Search by name, displayName, and breed
      final nameResults = await _profilesRef
          .where('isPublic', isEqualTo: true)
          .get();

      final profiles = nameResults.docs
          .map((doc) => SocialPetProfileModel.fromFirestore(doc))
          .where((profile) {
            final petNameMatch = profile.petName.toLowerCase().contains(queryLower);
            final breedMatch = profile.breed.toLowerCase().contains(queryLower);
            final displayNameMatch = (profile.displayName?.toLowerCase().contains(queryLower) ?? false);
            final bioMatch = (profile.bio.toLowerCase().contains(queryLower));
            
            return petNameMatch || breedMatch || displayNameMatch || bioMatch;
          })
          .toList();

      // Sort by relevance: exact matches first, then partial matches
      profiles.sort((a, b) {
        final aExact = a.petName.toLowerCase() == queryLower || 
                       (a.displayName?.toLowerCase() == queryLower);
        final bExact = b.petName.toLowerCase() == queryLower || 
                       (b.displayName?.toLowerCase() == queryLower);
        
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        
        // Sort by follower count
        return b.stats.followers.compareTo(a.stats.followers);
      });

      return profiles;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error searching pets: $e');
      }
      return [];
    }
  }

  @override
  Future<List<SocialPetProfile>> getPetsByBreed(String breed) async {
    try {
      final snapshot = await _profilesRef
          .where('breed', isEqualTo: breed)
          .where('isPublic', isEqualTo: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => SocialPetProfileModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting pets by breed: $e');
      }
      return [];
    }
  }

  @override
  Future<List<SocialPetProfile>> getPetsByLocation(String city) async {
    try {
      final snapshot = await _profilesRef
          .where('isPublic', isEqualTo: true)
          .get();

      // Filter by city (requires fetching posts and checking location)
      // This is a simplified version - in production, you'd want better indexing
      return snapshot.docs
          .map((doc) => SocialPetProfileModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting pets by location: $e');
      }
      return [];
    }
  }

  @override
  Future<List<String>> getTrendingTags({int limit = 10}) async {
    try {
      // Get recent posts and count tag frequencies
      final snapshot = await _postsRef
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final tagCounts = <String, int>{};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tags = List<String>.from(data['tags'] ?? []);
        for (var tag in tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTags
          .take(limit)
          .map((e) => e.key)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting trending tags: $e');
      }
      return [];
    }
  }

  // === Statistics ===

  @override
  Future<void> incrementViewCount(String postId) async {
    try {
      await _postsRef.doc(postId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error incrementing view count: $e');
      }
    }
  }

  @override
  Future<SocialStats> getPetStats(String petId) async {
    try {
      final doc = await _profilesRef.doc(petId).get();
      if (!doc.exists) return SocialStats();

      final data = doc.data() as Map<String, dynamic>;
      final statsData = data['stats'] as Map<String, dynamic>? ?? {};

      return SocialStatsModel.fromMap(statsData);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting pet stats: $e');
      }
      return SocialStats();
    }
  }
}
