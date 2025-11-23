import 'package:equatable/equatable.dart';

abstract class CustomerChatEvent extends Equatable {
  const CustomerChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadCustomerMessages extends CustomerChatEvent {
  final String conversationId;

  const LoadCustomerMessages(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}

class SendCustomerMessage extends CustomerChatEvent {
  final String conversationId;
  final String senderId;
  final String text;

  const SendCustomerMessage({
    required this.conversationId,
    required this.senderId,
    required this.text,
  });

  @override
  List<Object?> get props => [conversationId, senderId, text];
}

class SendCustomerImageMessage extends CustomerChatEvent {
  final String conversationId;
  final String senderId;
  final String imageUrl;

  const SendCustomerImageMessage({
    required this.conversationId,
    required this.senderId,
    required this.imageUrl,
  });

  @override
  List<Object?> get props => [conversationId, senderId, imageUrl];
}

class MarkCustomerMessagesAsRead extends CustomerChatEvent {
  final String conversationId;
  final String userId;

  const MarkCustomerMessagesAsRead({
    required this.conversationId,
    required this.userId,
  });

  @override
  List<Object?> get props => [conversationId, userId];
}
