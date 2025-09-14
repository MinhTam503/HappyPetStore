import 'package:pet_shop/domain/repositories/chatbot_repository.dart';

class ClearChatBotHistoryUseCase {
  final ChatBotRepository repository;

  ClearChatBotHistoryUseCase(this.repository);

  Future<void> call(String userId) async {
    return await repository.clearChatBotHistory(userId);
  }
}