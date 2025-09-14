import 'package:pet_shop/domain/entities/chatbot_entity.dart';

class ChatBotMessageModel extends ChatBotMessage {
  const ChatBotMessageModel({
    required super.id,
    required super.text,
    required super.isUser,
    required super.timestamp,
    required super.userId,
  });

  factory ChatBotMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatBotMessageModel(
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

  factory ChatBotMessageModel.fromEntity(ChatBotMessage entity) {
    return ChatBotMessageModel(
      id: entity.id,
      text: entity.text,
      isUser: entity.isUser,
      timestamp: entity.timestamp,
      userId: entity.userId,
    );
  }

  ChatBotMessage toEntity() {
    return ChatBotMessage(
      id: id,
      text: text,
      isUser: isUser,
      timestamp: timestamp,
      userId: userId,
    );
  }
}

class ChatBotResponseModel extends ChatBotResponse {
  const ChatBotResponseModel({
    required super.reply,
    required super.actions,
  });

  factory ChatBotResponseModel.fromJson(Map<String, dynamic> json) {
    return ChatBotResponseModel(
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

  factory ChatBotResponseModel.fromEntity(ChatBotResponse entity) {
    return ChatBotResponseModel(
      reply: entity.reply,
      actions: entity.actions,
    );
  }

  ChatBotResponse toEntity() {
    return ChatBotResponse(
      reply: reply,
      actions: actions,
    );
  }
}

class ChatBotRequestModel {
  final String userId;
  final String message;

  const ChatBotRequestModel({
    required this.userId,
    required this.message,
  });

  factory ChatBotRequestModel.fromJson(Map<String, dynamic> json) {
    return ChatBotRequestModel(
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