import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/domain/entities/chatbot_entity.dart';
import 'package:pet_shop/domain/usecases/send_chatbot_message_usecase.dart';
import 'package:pet_shop/domain/usecases/get_chatbot_history_usecase.dart';
import 'package:pet_shop/domain/usecases/save_chatbot_message_usecase.dart';
import 'package:pet_shop/domain/usecases/clear_chatbot_history_usecase.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_event.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_state.dart';

class ChatBotBloc extends Bloc<ChatBotEvent, ChatBotState> {
  final SendChatBotMessageUseCase sendMessageUseCase;
  final GetChatBotHistoryUseCase getHistoryUseCase;
  final SaveChatBotMessageUseCase saveMessageUseCase;
  final ClearChatBotHistoryUseCase clearHistoryUseCase;

  ChatBotBloc({
    required this.sendMessageUseCase,
    required this.getHistoryUseCase,
    required this.saveMessageUseCase,
    required this.clearHistoryUseCase,
  }) : super(ChatBotInitial()) {
    on<LoadChatBotHistory>(_onLoadChatBotHistory);
    on<SendChatBotMessage>(_onSendChatBotMessage);
    on<ClearChatBotHistory>(_onClearChatBotHistory);
    on<AddChatBotMessage>(_onAddChatBotMessage);
  }

  Future<void> _onLoadChatBotHistory(
    LoadChatBotHistory event,
    Emitter<ChatBotState> emit,
  ) async {
    try {
      emit(ChatBotLoading());
      
      final messages = await getHistoryUseCase(event.userId);
      
      emit(ChatBotLoaded(messages: messages));
    } catch (e) {
      emit(ChatBotError(
        message: 'Failed to load chat history: ${e.toString()}',
        messages: [],
      ));
    }
  }

  Future<void> _onSendChatBotMessage(
    SendChatBotMessage event,
    Emitter<ChatBotState> emit,
  ) async {
    try {
      // Get current messages
      List<ChatBotMessage> currentMessages = [];
      if (state is ChatBotLoaded) {
        currentMessages = (state as ChatBotLoaded).messages;
      }

      // Add user message immediately
      final userMessage = ChatBotMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: event.message,
        isUser: true,
        timestamp: DateTime.now(),
        userId: event.userId,
      );
      
      final updatedMessages = [...currentMessages, userMessage];
      emit(ChatBotLoaded(messages: updatedMessages, isTyping: true));

      // Send message to chatbot
      final response = await sendMessageUseCase(event.userId, event.message);

      // Add bot response with all data from API
      final botMessage = ChatBotMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_bot',
        text: response.reply,
        isUser: false,
        timestamp: DateTime.now(),
        userId: event.userId,
        pets: response.pets,
        quickReplies: response.quickReplies,
        actions: response.actions,
      );

      final finalMessages = [...updatedMessages, botMessage];
      emit(ChatBotLoaded(messages: finalMessages, isTyping: false));

    } catch (e) {
      List<ChatBotMessage> currentMessages = [];
      if (state is ChatBotLoaded) {
        currentMessages = (state as ChatBotLoaded).messages;
      }
      
      // Handle specific error messages
      String errorMessage = 'Failed to send message';
      if (e.toString().contains('Đã có lỗi xảy ra, vui lòng thử lại sau')) {
        errorMessage = 'Đã có lỗi xảy ra, vui lòng thử lại sau';
      } else if (e.toString().contains('Network error')) {
        errorMessage = 'Lỗi kết nối mạng, vui lòng kiểm tra và thử lại';
      }
      
      // Add error message as bot response
      final errorBotMessage = ChatBotMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_error',
        text: errorMessage,
        isUser: false,
        timestamp: DateTime.now(),
        userId: event.userId,
      );
      
      final errorMessages = [...currentMessages, errorBotMessage];
      emit(ChatBotLoaded(messages: errorMessages, isTyping: false));
    }
  }

  Future<void> _onClearChatBotHistory(
    ClearChatBotHistory event,
    Emitter<ChatBotState> emit,
  ) async {
    try {
      await clearHistoryUseCase(event.userId);
      emit(ChatBotLoaded(messages: []));
    } catch (e) {
      emit(ChatBotError(
        message: 'Failed to clear chat history: ${e.toString()}',
        messages: [],
      ));
    }
  }

  Future<void> _onAddChatBotMessage(
    AddChatBotMessage event,
    Emitter<ChatBotState> emit,
  ) async {
    try {
      List<ChatBotMessage> currentMessages = [];
      if (state is ChatBotLoaded) {
        currentMessages = (state as ChatBotLoaded).messages;
      }

      await saveMessageUseCase(event.message);
      
      final updatedMessages = [...currentMessages, event.message];
      emit(ChatBotLoaded(messages: updatedMessages));
    } catch (e) {
      emit(ChatBotError(
        message: 'Failed to add message: ${e.toString()}',
        messages: [],
      ));
    }
  }
}