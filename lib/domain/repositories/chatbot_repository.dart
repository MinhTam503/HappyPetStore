import 'package:pet_shop/domain/entities/chatbot_entity.dart';

abstract class ChatBotRepository {
  /// Send a message to the chatbot and get response
  Future<ChatBotResponse> sendMessage(String userId, String message);

  /// Save chat message to local storage
  Future<void> saveChatBotMessage(ChatBotMessage message);

  /// Get chat history for a specific user
  Future<List<ChatBotMessage>> getChatBotHistory(String userId);

  /// Clear chat history for a specific user
  Future<void> clearChatBotHistory(String userId);

  /// Check if chatbot service is available
  Future<bool> isServiceAvailable();
}