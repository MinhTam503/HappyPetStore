import 'package:pet_shop/domain/entities/chat_entity.dart';
import 'package:pet_shop/domain/repositories/chat_repository.dart';

class SendMessageUseCase {
  final ChatRepository repository;

  SendMessageUseCase(this.repository);

  Future<ChatResponse> call({
    required String userId,
    required String message,
  }) async {
    return await repository.sendMessage(
      userId: userId,
      message: message,
    );
  }
}