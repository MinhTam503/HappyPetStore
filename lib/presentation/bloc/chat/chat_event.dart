import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Load all conversations for current user
class LoadConversations extends ChatEvent {
  final String userId;

  const LoadConversations(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Create or get existing conversation
class CreateConversation extends ChatEvent {
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;

  const CreateConversation({
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
  });

  @override
  List<Object?> get props => [currentUserId, otherUserId, otherUserName, otherUserAvatar];
}

/// Load messages for a conversation
class LoadMessages extends ChatEvent {
  final String conversationId;

  const LoadMessages(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}

/// Send text message
class SendMessage extends ChatEvent {
  final String conversationId;
  final String senderId;
  final String text;
  final String? replyToId;

  const SendMessage({
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.replyToId,
  });

  @override
  List<Object?> get props => [conversationId, senderId, text, replyToId];
}

/// Send image message
class SendImageMessage extends ChatEvent {
  final String conversationId;
  final String senderId;
  final String imageUrl;
  final String? replyToId;

  const SendImageMessage({
    required this.conversationId,
    required this.senderId,
    required this.imageUrl,
    this.replyToId,
  });

  @override
  List<Object?> get props => [conversationId, senderId, imageUrl, replyToId];
}

/// Add reaction to message
class AddReaction extends ChatEvent {
  final String conversationId;
  final String messageId;
  final String userId;
  final String emoji;

  const AddReaction({
    required this.conversationId,
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  @override
  List<Object?> get props => [conversationId, messageId, userId, emoji];
}

/// Delete message
class DeleteMessage extends ChatEvent {
  final String conversationId;
  final String messageId;

  const DeleteMessage({
    required this.conversationId,
    required this.messageId,
  });

  @override
  List<Object?> get props => [conversationId, messageId];
}

/// Mark messages as read
class MarkMessagesAsRead extends ChatEvent {
  final String conversationId;
  final String userId;

  const MarkMessagesAsRead({
    required this.conversationId,
    required this.userId,
  });

  @override
  List<Object?> get props => [conversationId, userId];
}

/// Delete conversation
class DeleteConversation extends ChatEvent {
  final String conversationId;

  const DeleteConversation(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}
