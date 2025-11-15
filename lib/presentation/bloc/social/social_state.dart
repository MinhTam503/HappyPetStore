import 'package:equatable/equatable.dart';
import 'package:pet_shop/domain/entities/social_pet_profile.dart';
import 'package:pet_shop/domain/entities/social_post.dart';

/// Base class for all Social states
abstract class SocialState extends Equatable {
  const SocialState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class SocialInitial extends SocialState {}

/// Loading state
class SocialLoading extends SocialState {}

/// Success state with all social data
class SocialLoaded extends SocialState {
  final SocialPetProfile? currentProfile;
  final List<SocialPost> feed;
  final List<SocialPost> exploreFeed;
  final List<SocialPost> userPosts; // Posts of viewed user profile
  final List<SocialPetProfile> following;
  final List<SocialPetProfile> followers; // Followers list
  final List<SocialComment> currentComments;
  final List<String> trendingTags;
  final Map<String, bool> followingStatus; // petId -> isFollowing
  final Map<String, SocialPetProfile> profileCache; // userId -> profile
  final bool isRefreshing;

  const SocialLoaded({
    this.currentProfile,
    this.feed = const [],
    this.exploreFeed = const [],
    this.userPosts = const [],
    this.following = const [],
    this.followers = const [],
    this.currentComments = const [],
    this.trendingTags = const [],
    this.followingStatus = const {},
    this.profileCache = const {},
    this.isRefreshing = false,
  });

  SocialLoaded copyWith({
    SocialPetProfile? currentProfile,
    List<SocialPost>? feed,
    List<SocialPost>? exploreFeed,
    List<SocialPost>? userPosts,
    List<SocialPetProfile>? following,
    List<SocialPetProfile>? followers,
    List<SocialComment>? currentComments,
    List<String>? trendingTags,
    Map<String, bool>? followingStatus,
    Map<String, SocialPetProfile>? profileCache,
    bool? isRefreshing,
  }) {
    return SocialLoaded(
      currentProfile: currentProfile ?? this.currentProfile,
      feed: feed ?? this.feed,
      exploreFeed: exploreFeed ?? this.exploreFeed,
      userPosts: userPosts ?? this.userPosts,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      currentComments: currentComments ?? this.currentComments,
      trendingTags: trendingTags ?? this.trendingTags,
      followingStatus: followingStatus ?? this.followingStatus,
      profileCache: profileCache ?? this.profileCache,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
        currentProfile,
        feed,
        exploreFeed,
        userPosts,
        following,
        followers,
        currentComments,
        trendingTags,
        followingStatus,
        profileCache,
        isRefreshing,
      ];
}

/// Error state
class SocialError extends SocialState {
  final String message;

  const SocialError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Success state for specific operations
class SocialOperationSuccess extends SocialState {
  final String message;

  const SocialOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

/// Search results state
class SocialSearchResults extends SocialState {
  final List<SocialPetProfile> results;
  final String query;

  const SocialSearchResults(this.results, this.query);

  @override
  List<Object?> get props => [results, query];
}
