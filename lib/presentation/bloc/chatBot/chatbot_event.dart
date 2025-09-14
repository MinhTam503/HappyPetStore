import 'package:equatable/equatable.dart';
import 'package:pet_shop/domain/entities/chatbot_entity.dart';

abstract class ChatBotEvent extends Equatable {
  const ChatBotEvent();

  @override
  List<Object?> get props => [];
}

class LoadChatBotHistory extends ChatBotEvent {
  final String userId;

  const LoadChatBotHistory(this.userId);

  @override
  List<Object?> get props => [userId];
}

class SendChatBotMessage extends ChatBotEvent {
  final String userId;
  final String message;

  const SendChatBotMessage({
    required this.userId,
    required this.message,
  });

  @override
  List<Object?> get props => [userId, message];
}

class ClearChatBotHistory extends ChatBotEvent {
  final String userId;

  const ClearChatBotHistory(this.userId);

  @override
  List<Object?> get props => [userId];
}

class AddChatBotMessage extends ChatBotEvent {
  final ChatBotMessage message;

  const AddChatBotMessage(this.message);

  @override
  List<Object?> get props => [message];
}