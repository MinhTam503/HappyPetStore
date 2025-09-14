import 'package:equatable/equatable.dart';
import 'package:pet_shop/domain/entities/chatbot_entity.dart';

abstract class ChatBotState extends Equatable {
  const ChatBotState();

  @override
  List<Object?> get props => [];
}

class ChatBotInitial extends ChatBotState {}

class ChatBotLoading extends ChatBotState {}

class ChatBotLoaded extends ChatBotState {
  final List<ChatBotMessage> messages;
  final bool isTyping;

  const ChatBotLoaded({
    required this.messages,
    this.isTyping = false,
  });

  @override
  List<Object?> get props => [messages, isTyping];

  ChatBotLoaded copyWith({
    List<ChatBotMessage>? messages,
    bool? isTyping,
  }) {
    return ChatBotLoaded(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class ChatBotError extends ChatBotState {
  final String message;
  final List<ChatBotMessage> messages;

  const ChatBotError({
    required this.message,
    this.messages = const [],
  });

  @override
  List<Object?> get props => [message, messages];
}

class ChatBotMessageSent extends ChatBotState {
  final List<ChatBotMessage> messages;

  const ChatBotMessageSent(this.messages);

  @override
  List<Object?> get props => [messages];
}

class ChatBotHistoryCleared extends ChatBotState {}

class ChatBotTyping extends ChatBotState {
  final List<ChatBotMessage> messages;

  const ChatBotTyping(this.messages);

  @override
  List<Object?> get props => [messages];
}