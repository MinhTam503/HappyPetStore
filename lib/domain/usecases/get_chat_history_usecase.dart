import 'package:pet_shop/domain/entities/chat_entity.dart';
import 'package:pet_shop/domain/repositories/chat_repository.dart';

class GetChatHistoryUseCase {
  final ChatRepository repository;

  GetChatHistoryUseCase(this.repository);

  Future<List<ChatMessage>> call({
    required String userId,
  }) async {
    return await repository.getChatHistory(userId: userId);
  }
}