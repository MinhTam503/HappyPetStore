/// Entity representing a social pet profile in the social network
class SocialPetProfile {
  final String id; // User ID (changed from Pet ID to support user profiles)
  final String ownerId; // User ID who owns this pet (same as id for user profiles)
  final String petName; // Display name (can be user name or pet name)
  final String breed;
  final String category;
  final String avatarUrl; // Profile image URL
  final String bio;
  final List<String> followers; // List of user IDs following this profile
  final List<String> following; // List of user IDs this profile follows
  final SocialStats stats;
  final DateTime createdAt;
  final bool isPublic;
  
  // User-specific fields (synced from Users collection)
  final String? displayName; // User's display name from Users
  final String? email; // User email
  final String? phone; // User phone number
  final String? website; // User website URL

  SocialPetProfile({
    required this.id,
    required this.ownerId,
    required this.petName,
    required this.breed,
    required this.category,
    required this.avatarUrl,
    required this.bio,
    required this.followers,
    required this.following,
    required this.stats,
    required this.createdAt,
    this.isPublic = true,
    this.displayName,
    this.email,
    this.phone,
    this.website,
  });

  bool isFollowedBy(String userId) => followers.contains(userId);
  
  int get followerCount => followers.length;
  int get followingCount => following.length;
  
  SocialPetProfile copyWith({
    String? id,
    String? ownerId,
    String? petName,
    String? breed,
    String? category,
    String? avatarUrl,
    String? bio,
    List<String>? followers,
    List<String>? following,
    SocialStats? stats,
    DateTime? createdAt,
    bool? isPublic,
    String? displayName,
    String? email,
    String? phone,
    String? website,
  }) {
    return SocialPetProfile(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      petName: petName ?? this.petName,
      breed: breed ?? this.breed,
      category: category ?? this.category,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      stats: stats ?? this.stats,
      createdAt: createdAt ?? this.createdAt,
      isPublic: isPublic ?? this.isPublic,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
    );
  }
}

/// Statistics for a social pet profile
class SocialStats {
  final int posts;
  final int followers;
  final int following;
  final int totalLikes;
  final int totalComments;

  SocialStats({
    this.posts = 0,
    this.followers = 0,
    this.following = 0,
    this.totalLikes = 0,
    this.totalComments = 0,
  });

  SocialStats copyWith({
    int? posts,
    int? followers,
    int? following,
    int? totalLikes,
    int? totalComments,
  }) {
    return SocialStats(
      posts: posts ?? this.posts,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      totalLikes: totalLikes ?? this.totalLikes,
      totalComments: totalComments ?? this.totalComments,
    );
  }
}
