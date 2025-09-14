import 'package:pet_shop/domain/entities/chatbot_entity.dart';
import 'package:pet_shop/domain/repositories/chatbot_repository.dart';

class SaveChatBotMessageUseCase {
  final ChatBotRepository repository;

  SaveChatBotMessageUseCase(this.repository);

  Future<void> call(ChatBotMessage message) async {
    return await repository.saveChatBotMessage(message);
  }
}