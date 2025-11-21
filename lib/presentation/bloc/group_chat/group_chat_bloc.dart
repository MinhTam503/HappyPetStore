import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/repositories/group_chat_repository.dart';
import '../../../domain/entities/group_chat_entities.dart';
import 'group_chat_event.dart';
import 'group_chat_state.dart';

class GroupChatBloc extends Bloc<GroupChatEvent, GroupChatState> {
  final GroupChatRepository _repository;
  StreamSubscription? _messagesSubscription;

  GroupChatBloc({required GroupChatRepository repository})
      : _repository = repository,
        super(GroupChatInitial()) {
    on<LoadGroupConversations>(_onLoadGroupConversations);
    on<LoadPublicGroups>(_onLoadPublicGroups);
    on<CreateGroup>(_onCreateGroup);
    on<LoadGroupMessages>(_onLoadGroupMessages);
    on<SendGroupMessage>(_onSendGroupMessage);
    on<SendGroupImage>(_onSendGroupImage);
    on<JoinGroup>(_onJoinGroup);
    on<LeaveGroup>(_onLeaveGroup);
    on<MarkGroupMessagesAsRead>(_onMarkGroupMessagesAsRead);
  }

  Future<void> _onLoadGroupConversations(
    LoadGroupConversations event,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      emit(GroupChatLoading());

      final groups = await _repository.getUserGroups(event.userId);

      emit(GroupChatLoaded(groups: groups));
    } catch (e) {
      if (kDebugMode) print('❌ Error loading group conversations: $e');
      emit(GroupChatError(e.toString()));
    }
  }

  Future<void> _onLoadPublicGroups(
    LoadPublicGroups event,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      emit(GroupChatLoading());
      
      final publicGroups = await _repository.getPublicGroups();
      
      if (kDebugMode) print('📋 Loaded ${publicGroups.length} public groups');
      
      emit(GroupChatLoaded(
        groups: const [],
        publicGroups: publicGroups,
      ));
    } catch (e) {
      if (kDebugMode) print('❌ Error loading public groups: $e');
      emit(GroupChatError(e.toString()));
    }
  }

  Future<void> _onCreateGroup(
    CreateGroup event,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      final group = await _repository.createGroup(
        name: event.name,
        createdBy: event.createdBy,
        participants: event.participants,
        participantsInfo: event.participantsInfo,
        avatarUrl: event.avatarUrl,
        isPublic: event.isPublic,
      );

      // Reload groups
      add(LoadGroupConversations(event.createdBy));
      
      if (kDebugMode) print('✅ Group created: ${group.id}');
    } catch (e) {
      if (kDebugMode) print('❌ Error creating group: $e');
      emit(GroupChatError(e.toString()));
    }
  }

  Future<void> _onLoadGroupMessages(
    LoadGroupMessages event,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      await _messagesSubscription?.cancel();

      if (state is! GroupChatLoaded) {
        emit(GroupChatLoading());
      }

      final currentGroups = state is GroupChatLoaded 
          ? (state as GroupChatLoaded).groups 
          : const <GroupConversation>[];

      await emit.forEach(
        _repository.streamGroupMessages(event.groupId),
        onData: (messages) {
          return GroupChatLoaded(
            groups: currentGroups,
            messages: messages,
            activeGroupId: event.groupId,
          );
        },
        onError: (error, stackTrace) {
          return GroupChatError(error.toString());
        },
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error loading group messages: $e');
      emit(GroupChatError(e.toString()));
    }
  }

  Future<void> _onSendGroupMessage(
    SendGroupMessage event,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      // Check if user is blocked by any group member
      final group = await _repository.getGroup(event.groupId);
      if (group != null) {
        final isBlocked = await _isBlockedInGroup(event.senderId, group.participants);
        if (isBlocked) {
          emit(const GroupChatError('Cannot send message: blocked by a member.'));
          return;
        }
      }

      await _repository.sendGroupMessage(
        groupId: event.groupId,
        senderId: event.senderId,
        text: event.text,
        replyToId: event.replyToId,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error sending group message: $e');
      emit(GroupChatError(e.toString()));
    }
  }

  Future<void> _onSendGroupImage(
    SendGroupImage event,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      final group = await _repository.getGroup(event.groupId);
      if (group != null) {
        final isBlocked = await _isBlockedInGroup(event.senderId, group.participants);
        if (isBlocked) {
          emit(const GroupChatError('Cannot send message: blocked by a member.'));
          return;
        }
      }

      await _repository.sendGroupImage(
        groupId: event.groupId,
        senderId: event.senderId,
        imageUrl: event.imageUrl,
        replyToId: event.replyToId,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error sending group image: $e');
      emit(GroupChatError(e.toString()));
    }
  }

  Future<void> _onJoinGroup(
    JoinGroup event,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      await _repository.joinGroup(
        groupId: event.groupId,
        userId: event.userId,
        userInfo: event.userInfo,
      );

      // Reload groups
      add(LoadGroupConversations(event.userId));
    } catch (e) {
      if (kDebugMode) print('❌ Error joining group: $e');
      emit(GroupChatError(e.toString()));
    }
  }

  Future<void> _onLeaveGroup(
    LeaveGroup event,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      await _repository.leaveGroup(
        groupId: event.groupId,
        userId: event.userId,
      );

      // Reload groups
      add(LoadGroupConversations(event.userId));
    } catch (e) {
      if (kDebugMode) print('❌ Error leaving group: $e');
      emit(GroupChatError(e.toString()));
    }
  }

  Future<void> _onMarkGroupMessagesAsRead(
    MarkGroupMessagesAsRead event,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      await _repository.markGroupMessagesAsRead(event.groupId, event.userId);

      // Reload groups to update unread count
      if (state is GroupChatLoaded) {
        final groups = await _repository.getUserGroups(event.userId);
        emit((state as GroupChatLoaded).copyWith(groups: groups));
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error marking messages as read: $e');
    }
  }

  // Helper: Check if user is blocked by any participant in group
  Future<bool> _isBlockedInGroup(String userId, List<String> participants) async {
    try {
      for (var participantId in participants) {
        if (participantId == userId) continue;
        
        final isBlocked = await _isBlockedBetween(userId, participantId);
        if (isBlocked) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isBlockedBetween(String a, String b) async {
    try {
      final aDoc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(a)
          .get();
      if (aDoc.exists) {
        final data = aDoc.data() as Map<String, dynamic>;
        final List<dynamic> blocked = data['blocked'] ?? [];
        final List<dynamic> blockedBy = data['blockedBy'] ?? [];
        if (blocked.contains(b) || blockedBy.contains(b)) return true;
      }
      
      final bDoc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(b)
          .get();
      if (bDoc.exists) {
        final data = bDoc.data() as Map<String, dynamic>;
        final List<dynamic> blocked = data['blocked'] ?? [];
        final List<dynamic> blockedBy = data['blockedBy'] ?? [];
        if (blocked.contains(a) || blockedBy.contains(a)) return true;
      }
      
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }
}
