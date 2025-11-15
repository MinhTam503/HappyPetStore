import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/data/repositories/social_repository_impl.dart';
import 'package:pet_shop/domain/entities/social_pet_profile.dart';
import 'package:pet_shop/domain/repositories/social_repository.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';

class SocialBloc extends Bloc<SocialEvent, SocialState> {
  final SocialRepository _repository;
  final UserManager _userManager;

  SocialBloc({
    SocialRepository? repository,
    UserManager? userManager,
  })  : _repository = repository ?? SocialRepositoryImpl(),
        _userManager = userManager ?? UserManager(),
        super(SocialInitial()) {
    // Profile events
    on<EnsureUserProfile>(_onEnsureUserProfile);
    on<LoadUserProfile>(_onLoadUserProfile);
    on<UpdateUserProfile>(_onUpdateUserProfile);
    on<LoadUserPosts>(_onLoadUserPosts);
    on<LoadPetProfile>(_onLoadPetProfile);
    on<CreatePetProfile>(_onCreatePetProfile);
    on<UpdatePetProfile>(_onUpdatePetProfile);

    // Follow events
    on<FollowPet>(_onFollowPet);
    on<UnfollowPet>(_onUnfollowPet);
    on<LoadFollowing>(_onLoadFollowing);
    on<CheckIsFollowing>(_onCheckIsFollowing);

    // Feed events
    on<LoadFeed>(_onLoadFeed);
    on<LoadExploreFeed>(_onLoadExploreFeed);
    on<LoadPetPosts>(_onLoadPetPosts);

    // Post events
    on<CreatePost>(_onCreatePost);
    on<DeletePost>(_onDeletePost);

    // Like events
    on<LikePost>(_onLikePost);
    on<UnlikePost>(_onUnlikePost);

    // Comment events
    on<AddComment>(_onAddComment);
    on<DeleteComment>(_onDeleteComment);
    on<LikeComment>(_onLikeComment);
    on<LoadComments>(_onLoadComments);

    // Search events
    on<SearchPets>(_onSearchPets);
    on<LoadTrendingTags>(_onLoadTrendingTags);

    // Statistics events
    on<IncrementPostView>(_onIncrementPostView);
  }

  Future<String?> _getUserId() async {
    await _userManager.initialize();
    return await _userManager.getUserIdForOperations();
  }

  // === Profile Handlers ===

  Future<void> _onEnsureUserProfile(
    EnsureUserProfile event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final profile = await _repository.ensureUserProfile(event.userId);
      
      if (state is SocialLoaded) {
        final currentState = state as SocialLoaded;
        final updatedCache = Map<String, SocialPetProfile>.from(currentState.profileCache);
        updatedCache[event.userId] = profile;
        
        emit(currentState.copyWith(
          currentProfile: profile,
          profileCache: updatedCache,
        ));
      } else {
        emit(SocialLoaded(
          currentProfile: profile,
          profileCache: {event.userId: profile},
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error ensuring user profile: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onLoadUserProfile(
    LoadUserProfile event,
    Emitter<SocialState> emit,
  ) async {
    try {
      // Check cache first
      if (state is SocialLoaded) {
        final currentState = state as SocialLoaded;
        if (currentState.profileCache.containsKey(event.userId)) {
          return; // Already loaded
        }
      }

      final profile = await _repository.getUserProfile(event.userId);
      
      if (profile != null && state is SocialLoaded) {
        final currentState = state as SocialLoaded;
        final updatedCache = Map<String, SocialPetProfile>.from(currentState.profileCache);
        updatedCache[event.userId] = profile;
        
        emit(currentState.copyWith(
          profileCache: updatedCache,
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading user profile: $e');
      }
    }
  }

  Future<void> _onUpdateUserProfile(
    UpdateUserProfile event,
    Emitter<SocialState> emit,
  ) async {
    try {
      await _repository.updateUserProfile(event.userId, event.updates);
      
      // Reload profile
      final profile = await _repository.getUserProfile(event.userId);
      
      if (profile != null && state is SocialLoaded) {
        final currentState = state as SocialLoaded;
        final updatedCache = Map<String, SocialPetProfile>.from(currentState.profileCache);
        updatedCache[event.userId] = profile;
        
        emit(currentState.copyWith(
          currentProfile: profile,
          profileCache: updatedCache,
        ));
      }
      
      emit(const SocialOperationSuccess('Profile updated successfully'));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating user profile: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onLoadUserPosts(
    LoadUserPosts event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final posts = await _repository.getUserPosts(event.userId);
      
      if (state is SocialLoaded) {
        emit((state as SocialLoaded).copyWith(
          userPosts: posts,
        ));
      } else {
        emit(SocialLoaded(
          userPosts: posts,
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading user posts: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onLoadPetProfile(
    LoadPetProfile event,
    Emitter<SocialState> emit,
  ) async {
    try {
      emit(SocialLoading());

      final profile = await _repository.getPetProfile(event.petId);
      final posts = await _repository.getPetPosts(event.petId);

      if (state is SocialLoaded) {
        emit((state as SocialLoaded).copyWith(
          currentProfile: profile,
          feed: posts,
        ));
      } else {
        emit(SocialLoaded(
          currentProfile: profile,
          feed: posts,
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading pet profile: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onCreatePetProfile(
    CreatePetProfile event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        emit(const SocialError('User not authenticated'));
        return;
      }

      final profile = await _repository.createPetProfile(
        petId: event.petId,
        ownerId: userId,
        petName: event.petName,
        breed: event.breed,
        category: event.category,
        avatarUrl: event.avatarUrl,
        bio: event.bio,
      );

      emit(const SocialOperationSuccess('Profile created successfully'));
      emit(SocialLoaded(currentProfile: profile));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating pet profile: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onUpdatePetProfile(
    UpdatePetProfile event,
    Emitter<SocialState> emit,
  ) async {
    try {
      await _repository.updatePetProfile(event.petId, event.updates);

      emit(const SocialOperationSuccess('Profile updated successfully'));

      // Reload profile
      add(LoadPetProfile(event.petId));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating pet profile: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  // === Follow Handlers ===

  Future<void> _onFollowPet(
    FollowPet event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        emit(const SocialError('User not authenticated'));
        return;
      }

      await _repository.followPet(userId: userId, petId: event.petId);

      // Reload current user profile to get updated following list
      final currentUserProfile = await _repository.getUserProfile(userId);
      
      // Reload feed with updated following list
      final feed = await _repository.getFeed(userId);
      
      // Reload profile to get updated data
      if (state is SocialLoaded) {
        final currentState = state as SocialLoaded;
        
        // Update following status
        final newStatus = Map<String, bool>.from(currentState.followingStatus);
        newStatus[event.petId] = true;

        // Reload profile from cache or fetch new
        SocialPetProfile? updatedProfile = await _repository.getUserProfile(event.petId);

        final newCache = Map<String, SocialPetProfile>.from(currentState.profileCache);
        if (updatedProfile != null) {
          newCache[event.petId] = updatedProfile;
        }
        if (currentUserProfile != null) {
          newCache[userId] = currentUserProfile;
        }

        emit(currentState.copyWith(
          feed: feed,
          followingStatus: newStatus,
          profileCache: newCache,
          currentProfile: _isCurrentUserProfile(event.petId, userId) 
              ? updatedProfile 
              : currentState.currentProfile,
        ));
      }

      if (kDebugMode) {
        print('✅ Followed successfully: ${event.petId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error following pet: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onUnfollowPet(
    UnfollowPet event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        emit(const SocialError('User not authenticated'));
        return;
      }

      await _repository.unfollowPet(userId: userId, petId: event.petId);

      // Reload current user profile to get updated following list
      final currentUserProfile = await _repository.getUserProfile(userId);
      
      // Reload feed with updated following list
      final feed = await _repository.getFeed(userId);

      // Reload profile to get updated data
      if (state is SocialLoaded) {
        final currentState = state as SocialLoaded;
        
        // Update following status
        final newStatus = Map<String, bool>.from(currentState.followingStatus);
        newStatus[event.petId] = false;

        // Reload profile
        SocialPetProfile? updatedProfile = await _repository.getUserProfile(event.petId);

        final newCache = Map<String, SocialPetProfile>.from(currentState.profileCache);
        if (updatedProfile != null) {
          newCache[event.petId] = updatedProfile;
        }
        if (currentUserProfile != null) {
          newCache[userId] = currentUserProfile;
        }

        emit(currentState.copyWith(
          feed: feed,
          followingStatus: newStatus,
          profileCache: newCache,
          currentProfile: _isCurrentUserProfile(event.petId, userId) 
              ? updatedProfile 
              : currentState.currentProfile,
        ));
      }

      if (kDebugMode) {
        print('✅ Unfollowed successfully: ${event.petId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error unfollowing pet: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onLoadFollowing(
    LoadFollowing event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        emit(const SocialError('User not authenticated'));
        return;
      }

      final following = await _repository.getFollowing(userId);

      if (state is SocialLoaded) {
        emit((state as SocialLoaded).copyWith(following: following));
      } else {
        emit(SocialLoaded(following: following));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading following: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onCheckIsFollowing(
    CheckIsFollowing event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return;

      final isFollowing = await _repository.isFollowing(userId, event.petId);

      if (state is SocialLoaded) {
        final currentState = state as SocialLoaded;
        final newStatus = Map<String, bool>.from(currentState.followingStatus);
        newStatus[event.petId] = isFollowing;

        emit(currentState.copyWith(followingStatus: newStatus));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking following status: $e');
      }
    }
  }

  // === Feed Handlers ===

  Future<void> _onLoadFeed(
    LoadFeed event,
    Emitter<SocialState> emit,
  ) async {
    try {
      if (event.refresh && state is SocialLoaded) {
        emit((state as SocialLoaded).copyWith(isRefreshing: true));
      } else {
        emit(SocialLoading());
      }

      final userId = await _getUserId();
      if (userId == null) {
        emit(const SocialError('User not authenticated'));
        return;
      }

      final feed = await _repository.getFeed(userId);

      // Load profiles for all posts in feed
      final profileCache = <String, SocialPetProfile>{};
      if (state is SocialLoaded) {
        profileCache.addAll((state as SocialLoaded).profileCache);
      }
      
      for (final post in feed) {
        if (!profileCache.containsKey(post.petId)) {
          try {
            final profile = await _repository.getUserProfile(post.petId);
            if (profile != null) {
              profileCache[post.petId] = profile;
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error loading profile for ${post.petId}: $e');
            }
          }
        }
      }

      if (state is SocialLoaded) {
        emit((state as SocialLoaded).copyWith(
          feed: feed,
          isRefreshing: false,
          profileCache: profileCache,
        ));
      } else {
        emit(SocialLoaded(
          feed: feed,
          profileCache: profileCache,
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading feed: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onLoadExploreFeed(
    LoadExploreFeed event,
    Emitter<SocialState> emit,
  ) async {
    try {
      // Use refresh indicator instead of loading state to preserve other tab's data
      if (event.refresh && state is SocialLoaded) {
        emit((state as SocialLoaded).copyWith(isRefreshing: true));
      } else if (state is! SocialLoaded) {
        emit(SocialLoading());
      }

      final userId = await _getUserId();
      final exploreFeed = await _repository.getExplorePosts(excludeUserId: userId);

      if (state is SocialLoaded) {
        emit((state as SocialLoaded).copyWith(
          exploreFeed: exploreFeed,
          isRefreshing: false,
        ));
      } else {
        emit(SocialLoaded(exploreFeed: exploreFeed));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading explore feed: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onLoadPetPosts(
    LoadPetPosts event,
    Emitter<SocialState> emit,
  ) async {
    try {
      emit(SocialLoading());

      final posts = await _repository.getPetPosts(event.petId);

      if (state is SocialLoaded) {
        emit((state as SocialLoaded).copyWith(feed: posts));
      } else {
        emit(SocialLoaded(feed: posts));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading pet posts: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  // === Post Handlers ===

  Future<void> _onCreatePost(
    CreatePost event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        emit(const SocialError('User not authenticated'));
        return;
      }

      await _repository.createPost(
        petId: event.petId,
        authorId: userId,
        imageUrls: event.imageUrls,
        videoUrl: event.videoUrl,
        caption: event.caption,
        tags: event.tags,
        location: event.location,
      );

      emit(const SocialOperationSuccess('Post created successfully'));

      // Reload feed
      add(const LoadFeed(refresh: true));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating post: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onDeletePost(
    DeletePost event,
    Emitter<SocialState> emit,
  ) async {
    try {
      await _repository.deletePost(event.postId);

      emit(const SocialOperationSuccess('Post deleted successfully'));

      // Reload feed
      add(const LoadFeed(refresh: true));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting post: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  // === Like Handlers ===

  Future<void> _onLikePost(
    LikePost event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        emit(const SocialError('User not authenticated'));
        return;
      }

      await _repository.likePost(event.postId, userId);

      // Update post in state optimistically
      if (state is SocialLoaded) {
        final currentState = state as SocialLoaded;
        final updatedFeed = currentState.feed.map((post) {
          if (post.id == event.postId) {
            return post.copyWith(
              likes: [...post.likes, userId],
            );
          }
          return post;
        }).toList();

        emit(currentState.copyWith(feed: updatedFeed));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error liking post: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onUnlikePost(
    UnlikePost event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        emit(const SocialError('User not authenticated'));
        return;
      }

      await _repository.unlikePost(event.postId, userId);

      // Update post in state optimistically
      if (state is SocialLoaded) {
        final currentState = state as SocialLoaded;
        final updatedFeed = currentState.feed.map((post) {
          if (post.id == event.postId) {
            final newLikes = post.likes.where((id) => id != userId).toList();
            return post.copyWith(likes: newLikes);
          }
          return post;
        }).toList();

        emit(currentState.copyWith(feed: updatedFeed));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error unliking post: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  // === Comment Handlers ===

  Future<void> _onAddComment(
    AddComment event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        emit(const SocialError('User not authenticated'));
        return;
      }

      // Get user info from socialPetProfiles collection
      String userName = 'User';
      String userAvatarUrl = '';

      try {
        // First try socialPetProfiles (synced user data)
        final profileDoc = await FirebaseFirestore.instance
            .collection('socialPetProfiles')
            .doc(userId)
            .get();

        if (profileDoc.exists) {
          final profileData = profileDoc.data();
          userName = profileData?['displayName'] ?? profileData?['petName'] ?? 'User';
          userAvatarUrl = profileData?['avatarUrl'] ?? '';
        } else {
          // Fallback to Users collection
          final userDoc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(userId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            userName = userData?['displayName'] ?? userData?['name'] ?? 'User';
            userAvatarUrl = userData?['imageUrl'] ?? userData?['photoURL'] ?? '';
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Could not fetch user info: $e');
        }
      }

      await _repository.addComment(
        postId: event.postId,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        text: event.text,
        parentId: event.parentId, // Pass parentId for replies
      );

      // Don't emit success that might clear screen, just reload comments
      add(LoadComments(event.postId));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding comment: $e');
      }
      // Don't emit error that would clear posts
      if (kDebugMode) {
        print('Continuing with current state despite error');
      }
    }
  }

  Future<void> _onDeleteComment(
    DeleteComment event,
    Emitter<SocialState> emit,
  ) async {
    try {
      await _repository.deleteComment(event.postId, event.commentId);

      // Don't emit success that might clear screen, just reload comments
      add(LoadComments(event.postId));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting comment: $e');
      }
      // Don't emit error that would clear posts
    }
  }

  Future<void> _onLikeComment(
    LikeComment event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        if (kDebugMode) {
          print('⚠️ User not authenticated for like');
        }
        return;
      }

      await _repository.likeComment(event.postId, event.commentId, userId);

      // Reload comments to reflect the change
      add(LoadComments(event.postId));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error liking comment: $e');
      }
      // Don't emit error that would clear posts
    }
  }

  Future<void> _onLoadComments(
    LoadComments event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final comments = await _repository.getComments(event.postId);

      if (state is SocialLoaded) {
        // CRITICAL: Preserve all existing state, only update comments
        final currentState = state as SocialLoaded;
        emit(currentState.copyWith(
          currentComments: comments,
          // Keep all other fields from current state
        ));
      } else {
        // If not loaded yet, just set comments without affecting anything
        emit(SocialLoaded(
          currentComments: comments,
          feed: const [],
          exploreFeed: const [],
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading comments: $e');
      }
      // Don't emit error that would clear the screen
      if (kDebugMode) {
        print('Continuing with current state despite error');
      }
    }
  }

  // === Search Handlers ===

  Future<void> _onSearchPets(
    SearchPets event,
    Emitter<SocialState> emit,
  ) async {
    try {
      emit(SocialLoading());

      final results = await _repository.searchPets(event.query);

      emit(SocialSearchResults(results, event.query));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error searching pets: $e');
      }
      emit(SocialError(e.toString()));
    }
  }

  Future<void> _onLoadTrendingTags(
    LoadTrendingTags event,
    Emitter<SocialState> emit,
  ) async {
    try {
      final tags = await _repository.getTrendingTags();

      if (state is SocialLoaded) {
        emit((state as SocialLoaded).copyWith(trendingTags: tags));
      } else {
        emit(SocialLoaded(trendingTags: tags));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading trending tags: $e');
      }
    }
  }

  // === Statistics Handlers ===

  Future<void> _onIncrementPostView(
    IncrementPostView event,
    Emitter<SocialState> emit,
  ) async {
    try {
      await _repository.incrementViewCount(event.postId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error incrementing view count: $e');
      }
    }
  }

  // === Helper Methods ===

  bool _isCurrentUserProfile(String petId, String userId) {
    return petId == userId;
  }
}
