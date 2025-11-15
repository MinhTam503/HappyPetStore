import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/domain/entities/social_post.dart';

class SocialPostModel extends SocialPost {
  SocialPostModel({
    required super.id,
    required super.petId,
    required super.authorId,
    required super.imageUrls,
    super.videoUrl,
    required super.caption,
    required super.likes,
    required super.comments,
    super.location,
    required super.tags,
    required super.timestamp,
    required super.viewCount,
  });

  /// Convert from Firestore document
  factory SocialPostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SocialPostModel(
      id: doc.id,
      petId: data['petId'] ?? '',
      authorId: data['authorId'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrl: data['videoUrl'],
      caption: data['caption'] ?? '',
      likes: List<String>.from(data['likes'] ?? []),
      comments: (data['comments'] as List<dynamic>?)
          ?.map((c) => SocialCommentModel.fromMap(c as Map<String, dynamic>))
          .toList() ?? [],
      location: data['location'] != null 
          ? PostLocationModel.fromMap(data['location'] as Map<String, dynamic>)
          : null,
      tags: List<String>.from(data['tags'] ?? []),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewCount: data['viewCount'] ?? 0,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'petId': petId,
      'authorId': authorId,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'caption': caption,
      'likes': likes,
      'comments': comments.map((c) => {
        'id': c.id,
        'postId': c.postId,
        'userId': c.userId,
        'userName': c.userName,
        'userAvatarUrl': c.userAvatarUrl,
        'text': c.text,
        'likes': c.likes,
        'timestamp': Timestamp.fromDate(c.timestamp),
      }).toList(),
      'location': location != null ? {
        'city': location!.city,
        'country': location!.country,
        'latitude': location!.latitude,
        'longitude': location!.longitude,
      } : null,
      'tags': tags,
      'timestamp': Timestamp.fromDate(timestamp),
      'viewCount': viewCount,
    };
  }
}

class SocialCommentModel extends SocialComment {
  SocialCommentModel({
    required super.id,
    required super.postId,
    required super.userId,
    required super.userName,
    required super.userAvatarUrl,
    required super.text,
    required super.likes,
    required super.timestamp,
    super.parentId,
    super.replies,
  });

  factory SocialCommentModel.fromMap(Map<String, dynamic> map) {
    return SocialCommentModel(
      id: map['id'] ?? '',
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userAvatarUrl: map['userAvatarUrl'] ?? '',
      text: map['text'] ?? '',
      likes: List<String>.from(map['likes'] ?? []),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentId: map['parentId'],
      replies: (map['replies'] as List<dynamic>?)
          ?.map((r) => SocialCommentModel.fromMap(r as Map<String, dynamic>))
          .toList() ?? const [],
    );
  }
}

class PostLocationModel extends PostLocation {
  PostLocationModel({
    required super.city,
    required super.country,
    super.latitude,
    super.longitude,
  });

  factory PostLocationModel.fromMap(Map<String, dynamic> map) {
    return PostLocationModel(
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }
}
