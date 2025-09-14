import 'package:pet_shop/domain/entities/chatbot_entity.dart';
import 'package:pet_shop/domain/repositories/chatbot_repository.dart';

class GetChatBotHistoryUseCase {
  final ChatBotRepository repository;

  GetChatBotHistoryUseCase(this.repository);

  Future<List<ChatBotMessage>> call(String userId) async {
    return await repository.getChatBotHistory(userId);
  }
}