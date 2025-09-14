import 'package:pet_shop/domain/entities/chat_entity.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.text,
    required super.isUser,
    required super.timestamp,
    required super.userId,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  factory ChatMessageModel.fromEntity(ChatMessage entity) {
    return ChatMessageModel(
      id: entity.id,
      text: entity.text,
      isUser: entity.isUser,
      timestamp: entity.timestamp,
      userId: entity.userId,
    );
  }

  ChatMessage toEntity() {
    return ChatMessage(
      id: id,
      text: text,
      isUser: isUser,
      timestamp: timestamp,
      userId: userId,
    );
  }
}

class ChatResponseModel extends ChatResponse {
  const ChatResponseModel({
    required super.reply,
    required super.actions,
  });

  factory ChatResponseModel.fromJson(Map<String, dynamic> json) {
    return ChatResponseModel(
      reply: json['reply'] as String,
      actions: (json['actions'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reply': reply,
      'actions': actions,
    };
  }

  factory ChatResponseModel.fromEntity(ChatResponse entity) {
    return ChatResponseModel(
      reply: entity.reply,
      actions: entity.actions,
    );
  }

  ChatResponse toEntity() {
    return ChatResponse(
      reply: reply,
      actions: actions,
    );
  }
}

class ChatRequestModel {
  final String userId;
  final String message;

  const ChatRequestModel({
    required this.userId,
    required this.message,
  });

  factory ChatRequestModel.fromJson(Map<String, dynamic> json) {
    return ChatRequestModel(
      userId: json['userId'] as String,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'message': message,
    };
  }
}