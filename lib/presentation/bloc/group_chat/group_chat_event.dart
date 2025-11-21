import 'package:equatable/equatable.dart';

abstract class GroupChatEvent extends Equatable {
  const GroupChatEvent();

  @override
  List<Object?> get props => [];
}

/// Load user's group conversations
class LoadGroupConversations extends GroupChatEvent {
  final String userId;

  const LoadGroupConversations(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Load public community groups
class LoadPublicGroups extends GroupChatEvent {
  const LoadPublicGroups();
}

/// Create new group
class CreateGroup extends GroupChatEvent {
  final String name;
  final String createdBy;
  final List<String> participants;
  final Map<String, dynamic> participantsInfo;
  final String? avatarUrl;
  final bool isPublic;

  const CreateGroup({
    required this.name,
    required this.createdBy,
    required this.participants,
    required this.participantsInfo,
    this.avatarUrl,
    this.isPublic = false,
  });

  @override
  List<Object?> get props => [name, createdBy, participants, participantsInfo, avatarUrl, isPublic];
}

/// Load messages for a group
class LoadGroupMessages extends GroupChatEvent {
  final String groupId;

  const LoadGroupMessages(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

/// Send group message
class SendGroupMessage extends GroupChatEvent {
  final String groupId;
  final String senderId;
  final String text;
  final String? replyToId;

  const SendGroupMessage({
    required this.groupId,
    required this.senderId,
    required this.text,
    this.replyToId,
  });

  @override
  List<Object?> get props => [groupId, senderId, text, replyToId];
}

/// Send group image
class SendGroupImage extends GroupChatEvent {
  final String groupId;
  final String senderId;
  final String imageUrl;
  final String? replyToId;

  const SendGroupImage({
    required this.groupId,
    required this.senderId,
    required this.imageUrl,
    this.replyToId,
  });

  @override
  List<Object?> get props => [groupId, senderId, imageUrl, replyToId];
}

/// Join public group
class JoinGroup extends GroupChatEvent {
  final String groupId;
  final String userId;
  final Map<String, dynamic> userInfo;

  const JoinGroup({
    required this.groupId,
    required this.userId,
    required this.userInfo,
  });

  @override
  List<Object?> get props => [groupId, userId, userInfo];
}

/// Leave group
class LeaveGroup extends GroupChatEvent {
  final String groupId;
  final String userId;

  const LeaveGroup({
    required this.groupId,
    required this.userId,
  });

  @override
  List<Object?> get props => [groupId, userId];
}

/// Mark group messages as read
class MarkGroupMessagesAsRead extends GroupChatEvent {
  final String groupId;
  final String userId;

  const MarkGroupMessagesAsRead({
    required this.groupId,
    required this.userId,
  });

  @override
  List<Object?> get props => [groupId, userId];
}
