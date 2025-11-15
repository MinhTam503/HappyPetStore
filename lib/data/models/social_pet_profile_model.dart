import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/domain/entities/social_pet_profile.dart';

class SocialPetProfileModel extends SocialPetProfile {
  SocialPetProfileModel({
    required super.id,
    required super.ownerId,
    required super.petName,
    required super.breed,
    required super.category,
    required super.avatarUrl,
    required super.bio,
    required super.followers,
    required super.following,
    required super.stats,
    required super.createdAt,
    required super.isPublic,
    super.displayName,
    super.email,
    super.phone,
    super.website,
  });

  /// Convert from Firestore document
  factory SocialPetProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SocialPetProfileModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      petName: data['petName'] ?? '',
      breed: data['breed'] ?? '',
      category: data['category'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      bio: data['bio'] ?? '',
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      stats: SocialStatsModel.fromMap(data['stats'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPublic: data['isPublic'] ?? true,
      displayName: data['displayName'],
      email: data['email'],
      phone: data['phone'],
      website: data['website'],
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'petName': petName,
      'breed': breed,
      'category': category,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'followers': followers,
      'following': following,
      'stats': {
        'posts': stats.posts,
        'followers': stats.followers,
        'following': stats.following,
        'totalLikes': stats.totalLikes,
        'totalComments': stats.totalComments,
      },
      'createdAt': Timestamp.fromDate(createdAt),
      'isPublic': isPublic,
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (website != null) 'website': website,
    };
  }
}

class SocialStatsModel extends SocialStats {
  SocialStatsModel({
    required super.posts,
    required super.followers,
    required super.following,
    required super.totalLikes,
    required super.totalComments,
  });

  factory SocialStatsModel.fromMap(Map<String, dynamic> map) {
    return SocialStatsModel(
      posts: map['posts'] ?? 0,
      followers: map['followers'] ?? 0,
      following: map['following'] ?? 0,
      totalLikes: map['totalLikes'] ?? 0,
      totalComments: map['totalComments'] ?? 0,
    );
  }
}
