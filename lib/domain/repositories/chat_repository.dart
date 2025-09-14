import 'package:pet_shop/domain/entities/chat_entity.dart';

abstract class ChatRepository {
  Future<ChatResponse> sendMessage({
    required String userId,
    required String message,
  });

  Future<List<ChatMessage>> getChatHistory({
    required String userId,
  });

  Future<void> saveChatMessage({
    required ChatMessage message,
  });

  Future<void> clearChatHistory({
    required String userId,
  });
}