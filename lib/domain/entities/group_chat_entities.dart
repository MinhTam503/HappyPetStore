/// Group conversation entity
class GroupConversation {
  final String id;
  final String name;
  final String? avatarUrl;
  final List<String> participants; // List of user IDs
  final String createdBy; // Creator's user ID
  final bool isPublic; // Public community group or private friend group
  final String? lastMessage;
  final DateTime lastMessageTime;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCount; // userId -> unread count
  final DateTime createdAt;
  final Map<String, dynamic> participantsInfo; // userId -> {name, avatar}
  final List<String> admins; // Admin user IDs

  GroupConversation({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.participants,
    required this.createdBy,
    required this.isPublic,
    this.lastMessage,
    required this.lastMessageTime,
    this.lastMessageSenderId,
    required this.unreadCount,
    required this.createdAt,
    required this.participantsInfo,
    required this.admins,
  });

  GroupConversation copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    List<String>? participants,
    String? createdBy,
    bool? isPublic,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    Map<String, int>? unreadCount,
    DateTime? createdAt,
    Map<String, dynamic>? participantsInfo,
    List<String>? admins,
  }) {
    return GroupConversation(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      participants: participants ?? this.participants,
      createdBy: createdBy ?? this.createdBy,
      isPublic: isPublic ?? this.isPublic,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      participantsInfo: participantsInfo ?? this.participantsInfo,
      admins: admins ?? this.admins,
    );
  }
}

/// Group chat message entity
class GroupChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final DateTime timestamp;
  final Map<String, bool> readBy; // userId -> read status
  final String? replyToId;
  final Map<String, String> reactions; // userId -> emoji
  final bool isSystemMessage; // For join/leave notifications

  GroupChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    this.text,
    this.imageUrl,
    required this.timestamp,
    required this.readBy,
    this.replyToId,
    this.reactions = const {},
    this.isSystemMessage = false,
  });

  GroupChatMessage copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? text,
    String? imageUrl,
    DateTime? timestamp,
    Map<String, bool>? readBy,
    String? replyToId,
    Map<String, String>? reactions,
    bool? isSystemMessage,
  }) {
    return GroupChatMessage(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      isSystemMessage: isSystemMessage ?? this.isSystemMessage,
    );
  }
}
