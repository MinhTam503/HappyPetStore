import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_shop/data/datasources/chatbot_remote_datasource.dart';
import 'package:pet_shop/data/models/chatbot_model.dart';
import 'package:pet_shop/domain/entities/chatbot_entity.dart';
import 'package:pet_shop/domain/repositories/chatbot_repository.dart';

class ChatBotRepositoryImpl implements ChatBotRepository {
  final ChatBotRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;
  
  static const String _chatBotHistoryPrefix = 'chatbot_history_';

  ChatBotRepositoryImpl({
    required this.remoteDataSource,
    required this.sharedPreferences,
  });

  @override
  Future<ChatBotResponse> sendMessage(String userId, String message) async {
    try {
      // Send message to remote chatbot service
      final response = await remoteDataSource.sendMessage(userId, message);
      
      // Save user message to local storage
      final userMessage = ChatBotMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
        userId: userId,
      );
      await saveChatBotMessage(userMessage);
      
      // Save bot response to local storage
      final botMessage = ChatBotMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_bot',
        text: response.reply,
        isUser: false,
        timestamp: DateTime.now(),
        userId: userId,
      );
      await saveChatBotMessage(botMessage);
      
      return response.toEntity();
    } catch (e) {
      print('ChatBot Repository Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveChatBotMessage(ChatBotMessage message) async {
    try {
      final historyKey = _chatBotHistoryPrefix + message.userId;
      final existingHistory = await getChatBotHistory(message.userId);
      
      final updatedHistory = [...existingHistory, message];
      final historyJson = updatedHistory
          .map((msg) => ChatBotMessageModel.fromEntity(msg).toJson())
          .toList();
      
      await sharedPreferences.setString(historyKey, json.encode(historyJson));
    } catch (e) {
      print('Save ChatBot Message Error: $e');
      rethrow;
    }
  }

  @override
  Future<List<ChatBotMessage>> getChatBotHistory(String userId) async {
    try {
      final historyKey = _chatBotHistoryPrefix + userId;
      final historyString = sharedPreferences.getString(historyKey);
      
      if (historyString == null || historyString.isEmpty) {
        return [];
      }
      
      final historyJson = json.decode(historyString) as List<dynamic>;
      return historyJson
          .map((json) => ChatBotMessageModel.fromJson(json).toEntity())
          .toList();
    } catch (e) {
      print('Get ChatBot History Error: $e');
      return [];
    }
  }

  @override
  Future<void> clearChatBotHistory(String userId) async {
    try {
      final historyKey = _chatBotHistoryPrefix + userId;
      await sharedPreferences.remove(historyKey);
    } catch (e) {
      print('Clear ChatBot History Error: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      return await remoteDataSource.checkServiceAvailability();
    } catch (e) {
      print('ChatBot Service Availability Check Error: $e');
      return false;
    }
  }
}