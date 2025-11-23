import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_shop/domain/repositories/customer_chat_repository.dart';
import 'package:pet_shop/domain/entities/chat_entities.dart';
import 'customer_chat_event.dart';
import 'customer_chat_state.dart';

class CustomerChatBloc extends Bloc<CustomerChatEvent, CustomerChatState> {
  final CustomerChatRepository repository;
  StreamSubscription? _messagesSubscription;

  CustomerChatBloc(this.repository) : super(CustomerChatInitial()) {
    on<LoadCustomerMessages>(_onLoadCustomerMessages);
    on<SendCustomerMessage>(_onSendCustomerMessage);
    on<SendCustomerImageMessage>(_onSendCustomerImageMessage);
    on<MarkCustomerMessagesAsRead>(_onMarkCustomerMessagesAsRead);
  }

  Future<void> _onLoadCustomerMessages(
    LoadCustomerMessages event,
    Emitter<CustomerChatState> emit,
  ) async {
    try {
      emit(CustomerChatLoading());
      
      // Cancel previous subscription
      await _messagesSubscription?.cancel();
      
      // Use emit.forEach to properly handle stream emissions
      await emit.forEach<List<ChatMessage>>(
        repository.streamMessages(event.conversationId),
        onData: (messages) {
          return CustomerChatLoaded(messages);
        },
        onError: (error, stackTrace) {
          if (kDebugMode) print('❌ Stream error: $error');
          return CustomerChatError(error.toString());
        },
      );
    } catch (e) {
      if (kDebugMode) print('❌ Load messages error: $e');
      emit(CustomerChatError(e.toString()));
    }
  }

  Future<void> _onSendCustomerMessage(
    SendCustomerMessage event,
    Emitter<CustomerChatState> emit,
  ) async {
    try {
      await repository.sendMessage(
        conversationId: event.conversationId,
        senderId: event.senderId,
        text: event.text,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Send message error: $e');
      emit(CustomerChatError(e.toString()));
    }
  }

  Future<void> _onSendCustomerImageMessage(
    SendCustomerImageMessage event,
    Emitter<CustomerChatState> emit,
  ) async {
    try {
      await repository.sendImageMessage(
        conversationId: event.conversationId,
        senderId: event.senderId,
        imageUrl: event.imageUrl,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Send image error: $e');
      emit(CustomerChatError(e.toString()));
    }
  }

  Future<void> _onMarkCustomerMessagesAsRead(
    MarkCustomerMessagesAsRead event,
    Emitter<CustomerChatState> emit,
  ) async {
    try {
      await repository.markMessagesAsRead(
        event.conversationId,
        event.userId,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Mark as read error: $e');
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }
}
