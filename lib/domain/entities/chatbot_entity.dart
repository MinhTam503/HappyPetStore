import 'package:equatable/equatable.dart';

class ChatBotMessage extends Equatable {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String userId;

  const ChatBotMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.userId,
  });

  @override
  List<Object> get props => [id, text, isUser, timestamp, userId];

  ChatBotMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? userId,
  }) {
    return ChatBotMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }
}

class ChatBotResponse extends Equatable {
  final String reply;
  final List<String> actions;

  const ChatBotResponse({
    required this.reply,
    required this.actions,
  });

  @override
  List<Object> get props => [reply, actions];

  ChatBotResponse copyWith({
    String? reply,
    List<String>? actions,
  }) {
    return ChatBotResponse(
      reply: reply ?? this.reply,
      actions: actions ?? this.actions,
    );
  }
}