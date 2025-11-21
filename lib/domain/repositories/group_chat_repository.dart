import 'package:pet_shop/domain/entities/group_chat_entities.dart';

/// Repository interface for group chat features
abstract class GroupChatRepository {
  /// Create a new group conversation
  Future<GroupConversation> createGroup({
    required String name,
    required String createdBy,
    required List<String> participants,
    required Map<String, dynamic> participantsInfo,
    String? avatarUrl,
    bool isPublic = false,
  });
  
  /// Get all group conversations for a user
  Future<List<GroupConversation>> getUserGroups(String userId);
  
  /// Get public community groups
  Future<List<GroupConversation>> getPublicGroups({int limit = 20});
  
  /// Get a specific group
  Future<GroupConversation?> getGroup(String groupId);
  
  /// Join a public group
  Future<void> joinGroup({
    required String groupId,
    required String userId,
    required Map<String, dynamic> userInfo,
  });
  
  /// Leave a group
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  });
  
  /// Add members to group (admin only)
  Future<void> addMembers({
    required String groupId,
    required List<String> userIds,
    required Map<String, dynamic> usersInfo,
  });
  
  /// Remove member from group (admin only)
  Future<void> removeMember({
    required String groupId,
    required String userId,
  });
  
  /// Send a text message to group
  Future<GroupChatMessage> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String text,
    String? replyToId,
  });
  
  /// Send an image message to group
  Future<GroupChatMessage> sendGroupImage({
    required String groupId,
    required String senderId,
    required String imageUrl,
    String? replyToId,
  });
  
  /// Get messages for a group
  Future<List<GroupChatMessage>> getGroupMessages(String groupId, {int limit = 50});
  
  /// Stream messages for real-time updates
  Stream<List<GroupChatMessage>> streamGroupMessages(String groupId);
  
  /// Mark messages as read by user
  Future<void> markGroupMessagesAsRead(String groupId, String userId);
  
  /// Delete a group (admin only)
  Future<void> deleteGroup(String groupId);
  
  /// Update group info (admin only)
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? avatarUrl,
  });
}
