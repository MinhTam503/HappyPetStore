import 'package:pet_shop/domain/entities/chat_entities.dart';

/// Repository interface for user-to-user chat features
abstract class UserChatRepository {
  /// Get or create a conversation between users
  Future<ChatConversation> getOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
    required Map<String, dynamic> participantsInfo,
  });
  
  /// Get all conversations for a user
  Future<List<ChatConversation>> getConversations(String userId);
  
  /// Get a specific conversation
  Future<ChatConversation?> getConversation(String conversationId);
  
  /// Send a text message
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? replyToId,
  });
  
  /// Send an image message
  Future<ChatMessage> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String imageUrl,
    String? replyToId,
  });
  
  /// Get messages for a conversation
  Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 50});
  
  /// Stream messages for real-time updates
  Stream<List<ChatMessage>> streamMessages(String conversationId);
  
  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, String userId);
  
  /// Delete a conversation
  Future<void> deleteConversation(String conversationId);
  
  /// Delete a message
  Future<void> deleteMessage(String conversationId, String messageId);
}
