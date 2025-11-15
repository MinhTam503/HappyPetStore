import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
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
}
