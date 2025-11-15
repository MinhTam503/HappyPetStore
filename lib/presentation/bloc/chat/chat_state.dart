import 'package:equatable/equatable.dart';
import '../../../domain/entities/chat_entities.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatConversation> conversations;
  final List<ChatMessage> messages;
  final String? activeConversationId;

  const ChatLoaded({
    required this.conversations,
    required this.messages,
    this.activeConversationId,
  });

  ChatLoaded copyWith({
    List<ChatConversation>? conversations,
    List<ChatMessage>? messages,
    String? activeConversationId,
  }) {
    return ChatLoaded(
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      activeConversationId: activeConversationId ?? this.activeConversationId,
    );
  }

  @override
  List<Object?> get props => [conversations, messages, activeConversationId];
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}
