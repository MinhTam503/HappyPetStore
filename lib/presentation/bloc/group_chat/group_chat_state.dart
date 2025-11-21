import 'package:equatable/equatable.dart';
import 'package:pet_shop/domain/entities/group_chat_entities.dart';

abstract class GroupChatState extends Equatable {
  const GroupChatState();

  @override
  List<Object?> get props => [];
}

class GroupChatInitial extends GroupChatState {}

class GroupChatLoading extends GroupChatState {}

class GroupChatLoaded extends GroupChatState {
  final List<GroupConversation> groups;
  final List<GroupConversation> publicGroups;
  final List<GroupChatMessage> messages;
  final String? activeGroupId;

  const GroupChatLoaded({
    this.groups = const [],
    this.publicGroups = const [],
    this.messages = const [],
    this.activeGroupId,
  });

  GroupChatLoaded copyWith({
    List<GroupConversation>? groups,
    List<GroupConversation>? publicGroups,
    List<GroupChatMessage>? messages,
    String? activeGroupId,
  }) {
    return GroupChatLoaded(
      groups: groups ?? this.groups,
      publicGroups: publicGroups ?? this.publicGroups,
      messages: messages ?? this.messages,
      activeGroupId: activeGroupId ?? this.activeGroupId,
    );
  }

  @override
  List<Object?> get props => [groups, publicGroups, messages, activeGroupId];
}

class GroupChatError extends GroupChatState {
  final String message;

  const GroupChatError(this.message);

  @override
  List<Object?> get props => [message];
}
