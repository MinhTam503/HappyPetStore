import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String userId;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.userId,
  });

  @override
  List<Object> get props => [id, text, isUser, timestamp, userId];

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? userId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }
}

class ChatResponse extends Equatable {
  final String reply;
  final List<String> actions;

  const ChatResponse({
    required this.reply,
    required this.actions,
  });

  @override
  List<Object> get props => [reply, actions];

  ChatResponse copyWith({
    String? reply,
    List<String>? actions,
  }) {
    return ChatResponse(
      reply: reply ?? this.reply,
      actions: actions ?? this.actions,
    );
  }
}