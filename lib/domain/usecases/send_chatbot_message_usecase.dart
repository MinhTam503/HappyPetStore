import 'package:pet_shop/domain/entities/chatbot_entity.dart';
import 'package:pet_shop/domain/repositories/chatbot_repository.dart';

class SendChatBotMessageUseCase {
  final ChatBotRepository repository;

  SendChatBotMessageUseCase(this.repository);

  Future<ChatBotResponse> call(String userId, String message) async {
    return await repository.sendMessage(userId, message);
  }
}