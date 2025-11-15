import 'package:equatable/equatable.dart';
import 'package:pet_shop/domain/entities/social_post.dart';

/// Base class for all Social events
abstract class SocialEvent extends Equatable {
  const SocialEvent();

  @override
  List<Object?> get props => [];
}

// === Profile Events ===

class EnsureUserProfile extends SocialEvent {
  final String userId;

  const EnsureUserProfile(this.userId);

  @override
  List<Object?> get props => [userId];
}

class LoadUserProfile extends SocialEvent {
  final String userId;

  const LoadUserProfile(this.userId);

  @override
  List<Object?> get props => [userId];
}

class UpdateUserProfile extends SocialEvent {
  final String userId;
  final Map<String, dynamic> updates;

  const UpdateUserProfile(this.userId, this.updates);

  @override
  List<Object?> get props => [userId, updates];
}

class LoadUserPosts extends SocialEvent {
  final String userId;

  const LoadUserPosts(this.userId);

  @override
  List<Object?> get props => [userId];
}

class LoadPetProfile extends SocialEvent {
  final String petId;

  const LoadPetProfile(this.petId);

  @override
  List<Object?> get props => [petId];
}

class CreatePetProfile extends SocialEvent {
  final String petId;
  final String petName;
  final String breed;
  final String category;
  final String avatarUrl;
  final String bio;

  const CreatePetProfile({
    required this.petId,
    required this.petName,
    required this.breed,
    required this.category,
    required this.avatarUrl,
    required this.bio,
  });

  @override
  List<Object?> get props => [petId, petName, breed, category, avatarUrl, bio];
}

class UpdatePetProfile extends SocialEvent {
  final String petId;
  final Map<String, dynamic> updates;

  const UpdatePetProfile(this.petId, this.updates);

  @override
  List<Object?> get props => [petId, updates];
}

// === Follow Events ===

class FollowPet extends SocialEvent {
  final String petId;

  const FollowPet(this.petId);

  @override
  List<Object?> get props => [petId];
}

class UnfollowPet extends SocialEvent {
  final String petId;

  const UnfollowPet(this.petId);

  @override
  List<Object?> get props => [petId];
}

class LoadFollowing extends SocialEvent {
  const LoadFollowing();
}

class CheckIsFollowing extends SocialEvent {
  final String petId;

  const CheckIsFollowing(this.petId);

  @override
  List<Object?> get props => [petId];
}

// === Feed Events ===

class LoadFeed extends SocialEvent {
  final bool refresh;

  const LoadFeed({this.refresh = false});

  @override
  List<Object?> get props => [refresh];
}

class LoadExploreFeed extends SocialEvent {
  final bool refresh;

  const LoadExploreFeed({this.refresh = false});

  @override
  List<Object?> get props => [refresh];
}

class LoadPetPosts extends SocialEvent {
  final String petId;

  const LoadPetPosts(this.petId);

  @override
  List<Object?> get props => [petId];
}

// === Post Events ===

class CreatePost extends SocialEvent {
  final String petId;
  final List<String> imageUrls;
  final String? videoUrl;
  final String caption;
  final List<String> tags;
  final PostLocation? location;

  const CreatePost({
    required this.petId,
    required this.imageUrls,
    this.videoUrl,
    required this.caption,
    this.tags = const [],
    this.location,
  });

  @override
  List<Object?> get props => [petId, imageUrls, videoUrl, caption, tags, location];
}

class DeletePost extends SocialEvent {
  final String postId;

  const DeletePost(this.postId);

  @override
  List<Object?> get props => [postId];
}

// === Like Events ===

class LikePost extends SocialEvent {
  final String postId;

  const LikePost(this.postId);

  @override
  List<Object?> get props => [postId];
}

class UnlikePost extends SocialEvent {
  final String postId;

  const UnlikePost(this.postId);

  @override
  List<Object?> get props => [postId];
}

// === Comment Events ===

class AddComment extends SocialEvent {
  final String postId;
  final String text;
  final String? parentId; // For replies

  const AddComment(this.postId, this.text, {this.parentId});

  @override
  List<Object?> get props => [postId, text, parentId];
}

class DeleteComment extends SocialEvent {
  final String postId;
  final String commentId;

  const DeleteComment(this.postId, this.commentId);

  @override
  List<Object?> get props => [postId, commentId];
}

class LikeComment extends SocialEvent {
  final String postId;
  final String commentId;

  const LikeComment(this.postId, this.commentId);

  @override
  List<Object?> get props => [postId, commentId];
}

class LoadComments extends SocialEvent {
  final String postId;

  const LoadComments(this.postId);

  @override
  List<Object?> get props => [postId];
}

// === Search Events ===

class SearchPets extends SocialEvent {
  final String query;

  const SearchPets(this.query);

  @override
  List<Object?> get props => [query];
}

class LoadTrendingTags extends SocialEvent {
  const LoadTrendingTags();
}

// === Statistics Events ===

class IncrementPostView extends SocialEvent {
  final String postId;

  const IncrementPostView(this.postId);

  @override
  List<Object?> get props => [postId];
}
