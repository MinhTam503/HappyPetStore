import 'package:equatable/equatable.dart';
import 'package:pet_shop/domain/entities/chat_entities.dart';

abstract class CustomerChatState extends Equatable {
  const CustomerChatState();

  @override
  List<Object?> get props => [];
}

class CustomerChatInitial extends CustomerChatState {}

class CustomerChatLoading extends CustomerChatState {}

class CustomerChatLoaded extends CustomerChatState {
  final List<ChatMessage> messages;

  const CustomerChatLoaded(this.messages);

  @override
  List<Object?> get props => [messages];
}

class CustomerChatError extends CustomerChatState {
  final String message;

  const CustomerChatError(this.message);

  @override
  List<Object?> get props => [message];
}
