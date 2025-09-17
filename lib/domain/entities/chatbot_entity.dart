import 'package:equatable/equatable.dart';

class ChatBotMessage extends Equatable {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String userId;
  final List<ChatBotPet>? pets;
  final List<ChatBotQuickReply>? quickReplies;
  final List<ChatBotAction>? actions;

  const ChatBotMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.userId,
    this.pets,
    this.quickReplies,
    this.actions,
  });

  @override
  List<Object?> get props => [id, text, isUser, timestamp, userId, pets, quickReplies, actions];

  ChatBotMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? userId,
    List<ChatBotPet>? pets,
    List<ChatBotQuickReply>? quickReplies,
    List<ChatBotAction>? actions,
  }) {
    return ChatBotMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      pets: pets ?? this.pets,
      quickReplies: quickReplies ?? this.quickReplies,
      actions: actions ?? this.actions,
    );
  }
}

class ChatBotPet extends Equatable {
  final String id;
  final String name;
  final String breed;
  final String category;
  final String age;
  final String sex;
  final String weight;
  final num price;
  final String imageUrl;
  final String about;
  final String? healthStatus;
  final String? vaccination;
  final String? location;
  final ChatBotSeller? seller;
  final ChatBotDisplay? display;

  const ChatBotPet({
    required this.id,
    required this.name,
    required this.breed,
    required this.category,
    required this.age,
    required this.sex,
    required this.weight,
    required this.price,
    required this.imageUrl,
    required this.about,
    this.healthStatus,
    this.vaccination,
    this.location,
    this.seller,
    this.display,
  });

  @override
  List<Object?> get props => [
    id, name, breed, category, age, sex, weight, price, imageUrl, about,
    healthStatus, vaccination, location, seller, display
  ];
}

class ChatBotSeller extends Equatable {
  final String name;
  final String phone;
  final double? rating;

  const ChatBotSeller({
    required this.name,
    required this.phone,
    this.rating,
  });

  @override
  List<Object?> get props => [name, phone, rating];
}

class ChatBotDisplay extends Equatable {
  final String priceFormatted;
  final String ageFormatted;
  final String weightFormatted;
  final String shortDescription;

  const ChatBotDisplay({
    required this.priceFormatted,
    required this.ageFormatted,
    required this.weightFormatted,
    required this.shortDescription,
  });

  @override
  List<Object> get props => [priceFormatted, ageFormatted, weightFormatted, shortDescription];
}

class ChatBotQuickReply extends Equatable {
  final String text;
  final String action;
  final String payload;

  const ChatBotQuickReply({
    required this.text,
    required this.action,
    required this.payload,
  });

  @override
  List<Object> get props => [text, action, payload];
}

class ChatBotAction extends Equatable {
  final String type;
  final String text;
  final String? url;
  final String? phone;

  const ChatBotAction({
    required this.type,
    required this.text,
    this.url,
    this.phone,
  });

  @override
  List<Object?> get props => [type, text, url, phone];
}

class ChatBotResponse extends Equatable {
  final bool success;
  final String status;
  final String? timestamp;
  final String? requestId;
  final String message;
  final String messageType;
  final List<ChatBotPet> pets;
  final int totalFound;
  final Map<String, dynamic>? filtersApplied;
  final ChatBotPagination? pagination;
  final List<ChatBotQuickReply> quickReplies;
  final List<ChatBotAction> actions;

  const ChatBotResponse({
    required this.success,
    required this.status,
    this.timestamp,
    this.requestId,
    required this.message,
    required this.messageType,
    required this.pets,
    required this.totalFound,
    this.filtersApplied,
    this.pagination,
    required this.quickReplies,
    required this.actions,
  });

  @override
  List<Object?> get props => [
    success, status, timestamp, requestId, message, messageType, pets, totalFound,
    filtersApplied, pagination, quickReplies, actions
  ];

  // Legacy compatibility
  String get reply => message;
}

class ChatBotPagination extends Equatable {
  final int currentPage;
  final int perPage;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  const ChatBotPagination({
    required this.currentPage,
    required this.perPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  @override
  List<Object> get props => [currentPage, perPage, totalPages, hasNext, hasPrevious];
}