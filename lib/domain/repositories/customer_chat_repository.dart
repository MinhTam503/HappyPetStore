import 'package:pet_shop/domain/entities/chat_entities.dart';

/// Repository interface for customer-to-shop chat features
abstract class CustomerChatRepository {
  /// Get or create a conversation between customer and shop
  Future<ChatConversation> getOrCreateConversation({
    required String customerId,
    required Map<String, dynamic> participantsInfo,
  });
  
  /// Send a text message
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  });
  
  /// Send an image message
  Future<ChatMessage> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String imageUrl,
  });
  
  /// Stream messages for real-time updates
  Stream<List<ChatMessage>> streamMessages(String conversationId);
  
  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, String userId);
}
