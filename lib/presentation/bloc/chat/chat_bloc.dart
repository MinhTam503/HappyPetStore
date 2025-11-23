import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/repositories/user_chat_repository.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../domain/entities/chat_entities.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final UserChatRepository _chatRepository;
  final SocialRepository _socialRepository;
  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _messagesSubscription;

  ChatBloc({
    required UserChatRepository chatRepository,
    required SocialRepository socialRepository,
  })  : _chatRepository = chatRepository,
        _socialRepository = socialRepository,
        super(ChatInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<CreateConversation>(_onCreateConversation);
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<SendImageMessage>(_onSendImageMessage);
    on<AddReaction>(_onAddReaction);
    on<DeleteMessage>(_onDeleteMessage);
    on<MarkMessagesAsRead>(_onMarkMessagesAsRead);
    on<DeleteConversation>(_onDeleteConversation);
  }

  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(ChatLoading());

      // Load conversations once (not streaming)
      final conversations = await _chatRepository.getConversations(event.userId);

      emit(ChatLoaded(
        conversations: conversations,
        messages: [],
        activeConversationId: null,
      ));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onCreateConversation(
    CreateConversation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Block check before creating conversation
      final isBlocked = await _isBlockedBetween(event.currentUserId, event.otherUserId);
      if (isBlocked) {
        emit(ChatError('Cannot start conversation: user blocked.'));
        return;
      }
      // Get current user info from social repository
      final currentUserProfile = await _socialRepository.getUserProfile(event.currentUserId);
      
      final participantsInfo = {
        event.currentUserId: {
          'name': currentUserProfile?.displayName ?? currentUserProfile?.petName ?? '',
          'avatarUrl': currentUserProfile?.avatarUrl ?? '',
        },
        event.otherUserId: {
          'name': event.otherUserName,
          'avatarUrl': event.otherUserAvatar,
        },
      };

      final conversation = await _chatRepository.getOrCreateConversation(
        currentUserId: event.currentUserId,
        otherUserId: event.otherUserId,
        participantsInfo: participantsInfo,
      );

      // Load messages for new/existing conversation
      add(LoadMessages(conversation.id));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Cancel previous messages subscription
      await _messagesSubscription?.cancel();

      // Emit loading state if not already loaded
      if (state is! ChatLoaded) {
        emit(ChatLoading());
      }

      // Get current conversations list
      final currentConversations = state is ChatLoaded 
          ? (state as ChatLoaded).conversations 
          : <ChatConversation>[];

      // Use emit.forEach to properly handle stream emissions
      await emit.forEach<List<ChatMessage>>(
        _chatRepository.streamMessages(event.conversationId),
        onData: (messages) {
          return ChatLoaded(
            conversations: currentConversations,
            messages: messages,
            activeConversationId: event.conversationId,
          );
        },
        onError: (error, stackTrace) {
          return ChatError(error.toString());
        },
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Prevent sending if blocked relationship established
      final conversation = state is ChatLoaded
          ? (state as ChatLoaded).conversations.firstWhere(
              (c) => c.id == event.conversationId,
              orElse: () => ChatConversation(
                id: event.conversationId,
                participants: [],
                lastMessage: null,
                lastMessageTime: DateTime.now(),
                lastMessageSenderId: null,
                unreadCount: {},
                createdAt: DateTime.now(),
                participantsInfo: {},
              ),
            )
          : null;
      if (conversation != null && conversation.participants.length == 2) {
        final a = conversation.participants[0];
        final b = conversation.participants[1];
        if (await _isBlockedBetween(a, b)) {
          emit(ChatError('Cannot send message: users blocked.'));
          return;
        }
      }
      await _chatRepository.sendMessage(
        conversationId: event.conversationId,
        senderId: event.senderId,
        text: event.text,
      );
      // Messages will update via stream automatically
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendImageMessage(
    SendImageMessage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final conversation = state is ChatLoaded
          ? (state as ChatLoaded).conversations.firstWhere(
              (c) => c.id == event.conversationId,
              orElse: () => ChatConversation(
                id: event.conversationId,
                participants: [],
                lastMessage: null,
                lastMessageTime: DateTime.now(),
                lastMessageSenderId: null,
                unreadCount: {},
                createdAt: DateTime.now(),
                participantsInfo: {},
              ),
            )
          : null;
      if (conversation != null && conversation.participants.length == 2) {
        final a = conversation.participants[0];
        final b = conversation.participants[1];
        if (await _isBlockedBetween(a, b)) {
          emit(ChatError('Cannot send message: users blocked.'));
          return;
        }
      }
      await _chatRepository.sendImageMessage(
        conversationId: event.conversationId,
        senderId: event.senderId,
        imageUrl: event.imageUrl,
      );
      // Messages will update via stream automatically
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onMarkMessagesAsRead(
    MarkMessagesAsRead event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chatRepository.markMessagesAsRead(
        event.conversationId,
        event.userId,
      );
      // Reload conversations to update unread count
      if (state is ChatLoaded) {
        final currentState = state as ChatLoaded;
        final conversations = await _chatRepository.getConversations(event.userId);
        emit(currentState.copyWith(conversations: conversations));
      }
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onAddReaction(
    AddReaction event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final messageRef = FirebaseFirestore.instance
          .collection('chatConversations')
          .doc(event.conversationId)
          .collection('messages')
          .doc(event.messageId);

      // Get current message to check existing reaction
      final messageDoc = await messageRef.get();
      final data = messageDoc.data();
      final reactions = data?['reactions'] as Map<String, dynamic>? ?? {};

      // Toggle: if user already reacted with same emoji, remove it
      if (reactions[event.userId] == event.emoji) {
        await messageRef.set({
          'reactions': {event.userId: FieldValue.delete()},
        }, SetOptions(merge: true));
      } else {
        // Add or update reaction
        await messageRef.set({
          'reactions': {event.userId: event.emoji},
        }, SetOptions(merge: true));
      }

      // Messages will auto-update via stream
    } catch (e) {
      if (kDebugMode) print('❌ Error adding reaction: $e');
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onDeleteMessage(
    DeleteMessage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Delete message from Firestore
      await FirebaseFirestore.instance
          .collection('chatConversations')
          .doc(event.conversationId)
          .collection('messages')
          .doc(event.messageId)
          .delete();

      // Messages will auto-update via stream
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onDeleteConversation(
    DeleteConversation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chatRepository.deleteConversation(event.conversationId);
      
      // If deleting active conversation, clear messages
      if (state is ChatLoaded) {
        final currentState = state as ChatLoaded;
        if (currentState.activeConversationId == event.conversationId) {
          emit(currentState.copyWith(
            messages: [],
            activeConversationId: null,
          ));
        }
      }
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    return super.close();
  }

  // Helper: check block relationship between two users
  Future<bool> _isBlockedBetween(String a, String b) async {
    try {
      final aDoc = await FirebaseFirestore.instance.collection('blockedUsers').doc(a).get();
      if (aDoc.exists) {
        final data = aDoc.data() as Map<String, dynamic>;
        final List<dynamic> blocked = data['blocked'] ?? [];
        final List<dynamic> blockedBy = data['blockedBy'] ?? [];
        if (blocked.contains(b) || blockedBy.contains(b)) return true;
      }
      final bDoc = await FirebaseFirestore.instance.collection('blockedUsers').doc(b).get();
      if (bDoc.exists) {
        final data = bDoc.data() as Map<String, dynamic>;
        final List<dynamic> blocked = data['blocked'] ?? [];
        final List<dynamic> blockedBy = data['blockedBy'] ?? [];
        if (blocked.contains(a) || blockedBy.contains(a)) return true;
      }
      return false;
    } catch (_) {
      return false; // Fail-safe: allow if error (could log)
    }
  }
}
