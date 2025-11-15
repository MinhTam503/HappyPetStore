/// Entity representing a social post in the feed
class SocialPost {
  final String id;
  final String petId; // Pet who posted
  final String authorId; // User who posted (owner)
  final List<String> imageUrls;
  final String? videoUrl;
  final String caption;
  final List<String> likes; // List of user IDs who liked
  final List<SocialComment> comments;
  final PostLocation? location;
  final List<String> tags;
  final DateTime timestamp;
  final int viewCount;

  SocialPost({
    required this.id,
    required this.petId,
    required this.authorId,
    required this.imageUrls,
    this.videoUrl,
    required this.caption,
    required this.likes,
    required this.comments,
    this.location,
    required this.tags,
    required this.timestamp,
    this.viewCount = 0,
  });

  bool isLikedBy(String userId) => likes.contains(userId);
  
  int get likeCount => likes.length;
  int get commentCount => comments.length;

  SocialPost copyWith({
    String? id,
    String? petId,
    String? authorId,
    List<String>? imageUrls,
    String? videoUrl,
    String? caption,
    List<String>? likes,
    List<SocialComment>? comments,
    PostLocation? location,
    List<String>? tags,
    DateTime? timestamp,
    int? viewCount,
  }) {
    return SocialPost(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      authorId: authorId ?? this.authorId,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      caption: caption ?? this.caption,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      timestamp: timestamp ?? this.timestamp,
      viewCount: viewCount ?? this.viewCount,
    );
  }
}

/// Comment on a social post
class SocialComment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String text;
  final List<String> likes;
  final DateTime timestamp;
  final String? parentId; // Parent comment ID for replies (null for top-level)
  final List<SocialComment> replies; // Nested replies (only 1 level deep)

  SocialComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.text,
    required this.likes,
    required this.timestamp,
    this.parentId,
    this.replies = const [],
  });

  bool isLikedBy(String userId) => likes.contains(userId);
  int get likeCount => likes.length;

  SocialComment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? text,
    List<String>? likes,
    DateTime? timestamp,
    String? parentId,
    List<SocialComment>? replies,
  }) {
    return SocialComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      text: text ?? this.text,
      likes: likes ?? this.likes,
      timestamp: timestamp ?? this.timestamp,
      parentId: parentId ?? this.parentId,
      replies: replies ?? this.replies,
    );
  }
}

/// Location information for a post
class PostLocation {
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;

  PostLocation({
    required this.city,
    required this.country,
    this.latitude,
    this.longitude,
  });

  @override
  String toString() => '$city, $country';
}
