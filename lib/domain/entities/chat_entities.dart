/// Chat conversation entity
class ChatConversation {
  final String id;
  final List<String> participants; // List of user IDs
  final String? lastMessage;
  final DateTime lastMessageTime;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCount; // userId -> unread count
  final DateTime createdAt;
  final Map<String, dynamic> participantsInfo; // userId -> {name, avatar}

  ChatConversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.lastMessageTime,
    this.lastMessageSenderId,
    required this.unreadCount,
    required this.createdAt,
    required this.participantsInfo,
  });

  ChatConversation copyWith({
    String? id,
    List<String>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    Map<String, int>? unreadCount,
    DateTime? createdAt,
    Map<String, dynamic>? participantsInfo,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      participantsInfo: participantsInfo ?? this.participantsInfo,
    );
  }
}

/// Chat message entity
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;
  final String? replyToId; // For replying to messages
  final Map<String, String> reactions; // userId -> emoji

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.text,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
    this.replyToId,
    this.reactions = const {},
  });

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? text,
    String? imageUrl,
    DateTime? timestamp,
    bool? isRead,
    String? replyToId,
    Map<String, String>? reactions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
    );
  }
}
